import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'filler_analysis.dart';
import 'groq_transcription_service.dart';
import 'rehearsal_audio_recorder.dart';
import 'speaking_pace.dart';
import 'wav_audio.dart';

class LivePaceUpdate {
  const LivePaceUpdate({
    required this.wordsPerMinute,
    required this.classification,
    required this.validChunks,
  });

  final double wordsPerMinute;
  final String classification;
  final int validChunks;
}

/// Processes one non-overlapping chunk at a time; keeps at most one newer chunk.
/// The final report never reads these temporary live results.
class LiveFillerFeedbackService {
  LiveFillerFeedbackService({
    required this.transcriber,
    this.onFiller,
    this.onPace,
    this.chunkDuration = RehearsalAudioRecorder.defaultLiveChunkDuration,
    this.minimumPaceWords = 4,
    this.paceWindowSize = 3,
    Future<Directory> Function()? temporaryDirectory,
  }) : assert(minimumPaceWords > 0),
       assert(paceWindowSize > 0),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final GroqTranscriptionService transcriber;
  final void Function(String word)? onFiller;
  final void Function(LivePaceUpdate update)? onPace;
  final Duration chunkDuration;

  /// Prototype stability threshold: shorter partial transcripts are ignored.
  final int minimumPaceWords;

  /// The displayed pace is the mean of the latest valid chunk WPM values.
  final int paceWindowSize;
  final Future<Directory> Function() _temporaryDirectory;
  final List<double> _recentPaceValues = [];
  Uint8List? _pending;
  Future<void>? _working;
  bool _stopped = false;
  int _nextChunkId = 0;
  String? _lastTranscript;

  bool get isStopped => _stopped;

  void accept(Uint8List pcm) {
    if (_stopped || pcm.isEmpty) return;
    // When the API is slower than capture, retain only the newest complete
    // chunk. Do not build up requests, audio buffers, or temporary files.
    _pending = pcm;
    _working ??= _drain().whenComplete(() => _working = null);
  }

  Future<void> _drain() async {
    while (!_stopped && _pending != null) {
      final pcm = _pending!;
      _pending = null;
      final id = _nextChunkId++;
      await _process(id, pcm);
    }
  }

  Future<void> _process(int id, Uint8List pcm) async {
    String? path;
    try {
      final directory = await _temporaryDirectory();
      path =
          '${directory.path}${Platform.pathSeparator}'
          'speaksync-live-${DateTime.now().microsecondsSinceEpoch}-$id.wav';
      await WavAudio.writeChunk(path, pcm);
      if (_stopped) return;
      final transcript = await transcriber.transcribe(path);
      if (_stopped) return;
      handlePartialTranscript(transcript);
    } on Object {
      // Network, rate-limit, timeout, invalid response, and file errors only
      // affect this live chunk. The full recording and timer keep running.
    } finally {
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (_) {
          // The operating system also clears its temporary cache.
        }
      }
    }
  }

  /// Feeds one Whisper result to both live features without another API call.
  void handlePartialTranscript(String transcript) {
    if (_stopped) return;
    final normalized = FillerAnalysis.normalizeTranscript(transcript).trim();
    if (normalized.isEmpty) return;

    final paceCallback = onPace;
    if (paceCallback != null) {
      final pace = SpeakingPace.fromTranscript(transcript, chunkDuration);
      final wpm = pace.wordsPerMinute;
      if (pace.totalWords >= minimumPaceWords && wpm != null) {
        _recentPaceValues.add(wpm);
        while (_recentPaceValues.length > paceWindowSize) {
          _recentPaceValues.removeAt(0);
        }
        final average =
            _recentPaceValues.reduce((a, b) => a + b) /
            _recentPaceValues.length;
        paceCallback(
          LivePaceUpdate(
            wordsPerMinute: average,
            classification: _classifyPace(average),
            validChunks: _recentPaceValues.length,
          ),
        );
      }
    }

    // Whisper can occasionally repeat the tail of the preceding chunk at the
    // beginning of the next result. Suppress fillers inside that repeated
    // token prefix, while still allowing alerts for new text later in the
    // chunk. Live pace remains based on the complete ten-second result.
    final repeatedPrefixEnd = _repeatedPrefixEnd(_lastTranscript, normalized);
    _lastTranscript = normalized;
    final fillerCallback = onFiller;
    if (fillerCallback == null) return;
    final analysis = FillerAnalysis.fromTranscript(transcript, Duration.zero);
    if (analysis.offsets.isEmpty) return;
    final newFillers = analysis.offsets.entries
        .map(
          (entry) => MapEntry(
            entry.key,
            entry.value.where((offset) => offset >= repeatedPrefixEnd).toList(),
          ),
        )
        .where((entry) => entry.value.isNotEmpty);
    if (newFillers.isEmpty) return;
    final first = newFillers.reduce(
      (a, b) => a.value.first < b.value.first ? a : b,
    );
    fillerCallback(first.key);
  }

  static int _repeatedPrefixEnd(String? previous, String current) {
    if (previous == null || previous.isEmpty || current.isEmpty) return 0;
    final tokenPattern = RegExp(
      r"[\p{L}\p{N}]+(?:'[\p{L}\p{N}]+)*",
      unicode: true,
    );
    final previousTokens = tokenPattern.allMatches(previous).toList();
    final currentTokens = tokenPattern.allMatches(current).toList();
    final maximum = previousTokens.length < currentTokens.length
        ? previousTokens.length
        : currentTokens.length;
    for (var count = maximum; count > 0; count--) {
      var matches = true;
      for (var index = 0; index < count; index++) {
        final previousToken =
            previousTokens[previousTokens.length - count + index].group(0);
        final currentToken = currentTokens[index].group(0);
        if (previousToken != currentToken) {
          matches = false;
          break;
        }
      }
      if (matches) return currentTokens[count - 1].end;
    }
    return 0;
  }

  static String _classifyPace(double wpm) {
    if (wpm < 120) return 'Slow';
    if (wpm <= 160) return 'Target';
    return 'Fast';
  }

  /// Stop alerts and discard a queued chunk. The single in-flight request has
  /// a short timeout configured on its Groq service and is awaited before the
  /// final full-recording request begins.
  Future<void> stop() async {
    _stopped = true;
    _pending = null;
    await _working;
  }
}
