import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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

class GroqTranscriptionService {
  GroqTranscriptionService({
    required String apiKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  }) : _apiKey = apiKey.trim(),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  static final endpoint = Uri.parse(
    'https://api.groq.com/openai/v1/audio/transcriptions',
  );
  static const model = 'whisper-large-v3-turbo';
  static const maximumAudioBytes = 25 * 1024 * 1024;

  final String _apiKey;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Future<String> transcribe(String audioPath) async {
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
        ..fields['model'] = model
        ..fields['response_format'] = 'json'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            filename: 'rehearsal.m4a',
          ),
        );

      final streamedResponse = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw TranscriptionException(
          TranscriptionFailureType.apiFailure,
          _apiFailureMessage(response.statusCode, response.body),
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
      return cleaned;
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

  String _apiFailureMessage(int statusCode, String responseBody) {
    String? detail;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic> && error['message'] is String) {
          detail = (error['message'] as String).trim();
        }
      }
    } on FormatException {
      // Use a safe status-only message when the API body is not JSON.
    }
    if (detail != null && detail.isNotEmpty && detail.length <= 160) {
      return 'Groq transcription failed: $detail';
    }
    return 'Groq transcription failed with status $statusCode.';
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
