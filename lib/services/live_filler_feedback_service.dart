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

/// Processes one live chunk at a time and keeps at most one newer chunk.
/// Later chunks may begin with a short PCM overlap. Word timestamps from the
/// same Whisper request exclude that overlap from filler and pace feedback.
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
  _QueuedLiveChunk? _pending;
  Future<void>? _working;
  bool _stopped = false;
  int _acceptedChunkCount = 0;
  int _manualTranscriptCount = 0;
  int? _lastProcessedSequence;
  String? _lastTranscript;

  bool get isStopped => _stopped;

  void accept(Uint8List pcm) {
    if (_stopped || pcm.isEmpty) return;
    // When the API is slower than capture, retain only the newest complete
    // chunk. Do not build up requests, audio buffers, or temporary files.
    _pending = _QueuedLiveChunk(
      sequence: _acceptedChunkCount++,
      pcm: pcm,
      overlap: _overlapDuration(pcm.length),
    );
    _scheduleDrain();
  }

  void _scheduleDrain() {
    if (_stopped || _working != null || _pending == null) return;
    final work = _drain();
    _working = work;
    unawaited(
      work.whenComplete(() {
        _working = null;
        // Recheck in case a stream event arrived while the completed Future's
        // callback was queued. This prevents a newest pending chunk from being
        // stranded during a tight completion/accept race.
        _scheduleDrain();
      }),
    );
  }

  Future<void> _drain() async {
    while (!_stopped && _pending != null) {
      final chunk = _pending!;
      _pending = null;
      await _process(chunk);
    }
  }

  Future<void> _process(_QueuedLiveChunk chunk) async {
    String? path;
    try {
      final directory = await _temporaryDirectory();
      path =
          '${directory.path}${Platform.pathSeparator}'
          'speaksync-live-${DateTime.now().microsecondsSinceEpoch}-'
          '${chunk.sequence}.wav';
      await WavAudio.writeChunk(path, chunk.pcm);
      if (_stopped) return;
      final result = await transcriber.transcribeWithWordTimestamps(path);
      if (_stopped) return;
      _handlePartialResult(
        result,
        sequence: chunk.sequence,
        overlap: chunk.overlap,
      );
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
    _handlePartialResult(
      GroqTranscriptionResult(text: transcript),
      sequence: _manualTranscriptCount++,
      overlap: Duration.zero,
    );
  }

  void _handlePartialResult(
    GroqTranscriptionResult result, {
    required int sequence,
    required Duration overlap,
  }) {
    if (_stopped) return;
    final normalized = FillerAnalysis.normalizeTranscript(result.text).trim();
    if (normalized.isEmpty) return;

    final isConsecutive =
        _lastProcessedSequence == null ||
        sequence == _lastProcessedSequence! + 1;
    String novelTranscript;
    String paceTranscript;
    if (result.words.isNotEmpty) {
      novelTranscript = transcriptAfterOverlap(result.words, overlap);
      paceTranscript = novelTranscript;
    } else {
      // Some provider responses or test doubles may omit word timestamps.
      // Exact suffix/prefix removal is a conservative fallback. Only compare
      // consecutive processed chunks so a dropped pending request cannot make
      // unrelated later speech look duplicated.
      final repeatedPrefixEnd = isConsecutive
          ? _repeatedPrefixEnd(_lastTranscript, normalized)
          : 0;
      novelTranscript = normalized.substring(repeatedPrefixEnd).trim();
      // A non-overlapping response (including existing test doubles) has no
      // carried audio to subtract from WPM. Keep exact-text suppression for
      // filler alerts, but use its complete text for pace.
      paceTranscript = overlap > Duration.zero ? novelTranscript : normalized;
    }
    _lastTranscript = normalized;
    _lastProcessedSequence = sequence;
    if (novelTranscript.isEmpty && paceTranscript.isEmpty) return;

    final paceCallback = onPace;
    if (paceCallback != null) {
      // The carried-over audio is context only. Count novel words against the
      // normal ten-second capture cadence, not the longer uploaded WAV.
      final pace = SpeakingPace.fromTranscript(paceTranscript, chunkDuration);
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

    final fillerCallback = onFiller;
    if (fillerCallback == null) return;
    final analysis = FillerAnalysis.fromTranscript(
      novelTranscript,
      Duration.zero,
    );
    if (analysis.offsets.isEmpty) return;
    final detections = <({String word, int offset})>[
      for (final entry in analysis.offsets.entries)
        for (final offset in entry.value) (word: entry.key, offset: offset),
    ]..sort((a, b) => a.offset.compareTo(b.offset));
    for (final detection in detections) {
      fillerCallback(detection.word);
    }
  }

  /// Returns only words whose midpoint belongs to the new portion of a live
  /// chunk. A word crossing the boundary is assigned to the side containing
  /// most of it, which preserves natural repetitions after the boundary.
  static String transcriptAfterOverlap(
    List<GroqTranscribedWord> words,
    Duration overlap,
  ) {
    final boundary = overlap.inMicroseconds / Duration.microsecondsPerSecond;
    return words
        .where((word) => (word.startSeconds + word.endSeconds) / 2 >= boundary)
        .map((word) => word.word.trim())
        .where((word) => word.isNotEmpty)
        .join(' ');
  }

  Duration _overlapDuration(int pcmBytes) {
    final expectedBytes =
        chunkDuration.inMicroseconds *
        WavAudio.bytesPerSecond ~/
        Duration.microsecondsPerSecond;
    final overlapBytes = pcmBytes - expectedBytes;
    if (overlapBytes <= 0) return Duration.zero;
    return Duration(
      microseconds:
          overlapBytes *
          Duration.microsecondsPerSecond ~/
          WavAudio.bytesPerSecond,
    );
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

class _QueuedLiveChunk {
  const _QueuedLiveChunk({
    required this.sequence,
    required this.pcm,
    required this.overlap,
  });

  final int sequence;
  final Uint8List pcm;
  final Duration overlap;
}
