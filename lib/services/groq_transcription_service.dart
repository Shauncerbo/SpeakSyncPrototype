import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

enum GroqWhisperModel {
  turbo('whisper-large-v3-turbo'),
  largeV3('whisper-large-v3');

  const GroqWhisperModel(this.apiName);

  final String apiName;

  /// Unknown build configuration conservatively falls back to existing Turbo.
  static GroqWhisperModel fromApiName(String value) => switch (value.trim()) {
    'whisper-large-v3' => largeV3,
    _ => turbo,
  };
}

enum TranscriptionFailureType {
  missingApiKey,
  missingAudio,
  noInternet,
  timeout,
  apiFailure,
  invalidResponse,
  emptyTranscript,
}

class TranscriptionException implements Exception {
  const TranscriptionException(this.type, this.message);

  final TranscriptionFailureType type;
  final String message;

  @override
  String toString() => message;
}

class GroqTranscribedWord {
  const GroqTranscribedWord({
    required this.word,
    required this.startSeconds,
    required this.endSeconds,
  });

  final String word;
  final double startSeconds;
  final double endSeconds;
}

class GroqTranscriptionResult {
  const GroqTranscriptionResult({required this.text, this.words = const []});

  final String text;
  final List<GroqTranscribedWord> words;
}

class GroqTranscriptionService {
  GroqTranscriptionService({
    required String apiKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
    this.transcriptionModel = GroqWhisperModel.turbo,
    String? prompt,
  }) : _apiKey = apiKey.trim(),
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _prompt = prompt?.trim();

  /// Live requests stay on Turbo regardless of the final-recording setting.
  factory GroqTranscriptionService.liveFeedback({
    required String apiKey,
    http.Client? client,
    bool enableContextPrompt = true,
  }) => GroqTranscriptionService(
    apiKey: apiKey,
    client: client,
    timeout: const Duration(seconds: 8),
    prompt: enableContextPrompt ? codeSwitchingContextPrompt : null,
  );

  factory GroqTranscriptionService.finalRecording({
    required String apiKey,
    http.Client? client,
    GroqWhisperModel model = GroqWhisperModel.largeV3,
    bool enableContextPrompt = true,
  }) => GroqTranscriptionService(
    apiKey: apiKey,
    client: client,
    transcriptionModel: model,
    prompt: enableContextPrompt ? codeSwitchingContextPrompt : null,
  );

  static final endpoint = Uri.parse(
    'https://api.groq.com/openai/v1/audio/transcriptions',
  );
  static const maximumAudioBytes = 25 * 1024 * 1024;
  // Whisper prompts are contextual spelling hints, not enforceable commands.
  // Never append these examples to the returned text or use them as detections.
  static const codeSwitchingContextPrompt =
      'English, Filipino/Tagalog, and Cebuano/Bisaya code-switched '
      'public-speaking rehearsal. Local spellings (context only, not words '
      "to insert): ano, parang, kasi, kuan, ku'an, kanang, mura'g, bitaw. "
      'Verbatim speech in the original languages, including audible um, uhm, ah.';

  final String _apiKey;
  final http.Client _client;
  final bool _ownsClient;
  final String? _prompt;
  final Duration timeout;
  final GroqWhisperModel transcriptionModel;

  Future<String> transcribe(String audioPath) async =>
      (await _transcribe(audioPath, includeWordTimestamps: false)).text;

  /// Transcribes one live chunk and requests word timestamps in the same HTTP
  /// request. The timestamps let the live analyzer exclude carried-over audio
  /// without making a second Groq request.
  Future<GroqTranscriptionResult> transcribeWithWordTimestamps(
    String audioPath,
  ) => _transcribe(audioPath, includeWordTimestamps: true);

  Future<GroqTranscriptionResult> _transcribe(
    String audioPath, {
    required bool includeWordTimestamps,
  }) async {
    try {
      if (_apiKey.isEmpty) {
        throw const TranscriptionException(
          TranscriptionFailureType.missingApiKey,
          'Groq transcription is not configured on this device.',
        );
      }

      final file = File(audioPath);
      if (audioPath.trim().isEmpty || !await file.exists()) {
        throw const TranscriptionException(
          TranscriptionFailureType.missingAudio,
          'The rehearsal audio file is missing.',
        );
      }
      final audioBytes = await file.length();
      if (audioBytes == 0) {
        throw const TranscriptionException(
          TranscriptionFailureType.missingAudio,
          'The rehearsal audio file is empty.',
        );
      }
      if (audioBytes > maximumAudioBytes) {
        throw const TranscriptionException(
          TranscriptionFailureType.apiFailure,
          'The rehearsal audio is too large to transcribe.',
        );
      }

      final request = http.MultipartRequest('POST', endpoint)
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = transcriptionModel.apiName
        ..fields['response_format'] = includeWordTimestamps
            ? 'verbose_json'
            : 'json'
        ..fields['temperature'] = '0';
      if (includeWordTimestamps) {
        request.fields['timestamp_granularities[]'] = 'word';
      }
      // Omit `language` for automatic detection, including mixed-language
      // rehearsals. Use transcriptions, never translations or English-only ASR.
      if (_prompt != null && _prompt.isNotEmpty) {
        request.fields['prompt'] = _prompt;
      }
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: audioPath.toLowerCase().endsWith('.wav')
              ? 'rehearsal.wav'
              : 'rehearsal.m4a',
        ),
      );

      final streamedResponse = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TranscriptionException(
          TranscriptionFailureType.apiFailure,
          _apiFailureMessage(response.statusCode),
        );
      }

      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const TranscriptionException(
          TranscriptionFailureType.invalidResponse,
          'Groq returned an unreadable transcription response.',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const TranscriptionException(
          TranscriptionFailureType.invalidResponse,
          'Groq returned an invalid transcription response.',
        );
      }

      final transcript = decoded['text'];
      if (transcript is! String) {
        throw const TranscriptionException(
          TranscriptionFailureType.invalidResponse,
          'Groq did not return transcript text.',
        );
      }
      final cleaned = transcript.trim();
      if (cleaned.isEmpty) {
        throw const TranscriptionException(
          TranscriptionFailureType.emptyTranscript,
          'No speech was detected in the rehearsal audio.',
        );
      }
      return GroqTranscriptionResult(
        text: cleaned,
        words: includeWordTimestamps
            ? _readWordTimestamps(decoded['words'])
            : const [],
      );
    } on TranscriptionException {
      rethrow;
    } on TimeoutException {
      throw const TranscriptionException(
        TranscriptionFailureType.timeout,
        'Transcription timed out. Check your connection and try again later.',
      );
    } on SocketException {
      throw const TranscriptionException(
        TranscriptionFailureType.noInternet,
        'No internet connection was available for transcription.',
      );
    } on http.ClientException {
      throw const TranscriptionException(
        TranscriptionFailureType.noInternet,
        'SpeakSync could not connect to Groq for transcription.',
      );
    } on FileSystemException {
      throw const TranscriptionException(
        TranscriptionFailureType.missingAudio,
        'SpeakSync could not read the rehearsal audio file.',
      );
    } catch (_) {
      throw const TranscriptionException(
        TranscriptionFailureType.apiFailure,
        'Transcription failed. The rehearsal report can still continue.',
      );
    }
  }

  static List<GroqTranscribedWord> _readWordTimestamps(Object? value) {
    if (value is! List) return const [];
    final words = <GroqTranscribedWord>[];
    for (final item in value) {
      if (item is! Map) continue;
      final word = item['word'];
      final start = item['start'];
      final end = item['end'];
      if (word is! String || start is! num || end is! num) continue;
      final cleaned = word.trim();
      final startSeconds = start.toDouble();
      final endSeconds = end.toDouble();
      if (cleaned.isEmpty ||
          !startSeconds.isFinite ||
          !endSeconds.isFinite ||
          startSeconds < 0 ||
          endSeconds < startSeconds) {
        continue;
      }
      words.add(
        GroqTranscribedWord(
          word: cleaned,
          startSeconds: startSeconds,
          endSeconds: endSeconds,
        ),
      );
    }
    return List.unmodifiable(words);
  }

  String _apiFailureMessage(int statusCode) {
    // Do not surface provider response bodies: they may echo sensitive input.
    return 'Groq transcription failed with status $statusCode.';
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
