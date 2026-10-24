import 'dart:convert';

import 'filler_analysis.dart';
import 'groq_transcription_service.dart';

class TranscriptionEvaluationConfig {
  const TranscriptionEvaluationConfig({
    required this.id,
    required this.model,
    required this.contextEnabled,
  });

  final String id;
  final GroqWhisperModel model;
  final bool contextEnabled;

  static const all = [
    TranscriptionEvaluationConfig(
      id: 'turbo_context_off',
      model: GroqWhisperModel.turbo,
      contextEnabled: false,
    ),
    TranscriptionEvaluationConfig(
      id: 'turbo_context_on',
      model: GroqWhisperModel.turbo,
      contextEnabled: true,
    ),
    TranscriptionEvaluationConfig(
      id: 'large_v3_context_off',
      model: GroqWhisperModel.largeV3,
      contextEnabled: false,
    ),
    TranscriptionEvaluationConfig(
      id: 'large_v3_context_on',
      model: GroqWhisperModel.largeV3,
      contextEnabled: true,
    ),
  ];
}

/// Evaluation-only normalization. It never changes application transcripts.
/// Case and surrounding punctuation are ignored, whitespace is collapsed, and
/// apostrophes are standardized. Only filler spellings already accepted by
/// SpeakSync are canonicalized; fillers and code-switching remain in the text.
abstract final class TranscriptionEvaluationNormalizer {
  static final _tokenPattern = RegExp(
    r"[\p{L}\p{N}][\p{L}\p{M}\p{N}]*(?:['\-][\p{L}\p{N}][\p{L}\p{M}\p{N}]*)*",
    unicode: true,
  );

  static List<String> words(String? text) {
    final standardized = (text ?? '')
        .toLowerCase()
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u02bc', "'");
    return List.unmodifiable(
      _tokenPattern
          .allMatches(standardized)
          .map((match) => _canonicalize(match.group(0)!)),
    );
  }

  static String normalizedText(String? text) => words(text).join(' ');

  static String _canonicalize(String token) {
    if (token == 'kwan' || token == "ku'an") return 'kuan';
    if (token == "mura'g") return 'murag';
    if (RegExp(r'^um+$').hasMatch(token)) return 'um';
    if (RegExp(r'^uh+m+$').hasMatch(token)) return 'uhm';
    if (RegExp(r'^ah+$').hasMatch(token)) return 'ah';
    return token;
  }
}

enum TranscriptionEvaluationStatus {
  available,
  emptyHypothesis,
  missingHypothesis,
  missingReference,
}

class FillerDetectionMetrics {
  const FillerDetectionMetrics({
    required this.referenceCounts,
    required this.hypothesisCounts,
    required this.correct,
    required this.missed,
    required this.incorrect,
    required this.precision,
    required this.recall,
    required this.f1,
  });

  final Map<String, int> referenceCounts;
  final Map<String, int> hypothesisCounts;
  final int correct;
  final int missed;
  final int incorrect;
  final double? precision;
  final double? recall;
  final double? f1;
}

class TranscriptionEvaluationResult {
  const TranscriptionEvaluationResult({
    required this.status,
    required this.referenceWordCount,
    required this.hypothesisWordCount,
    required this.wordErrorRate,
    required this.characterErrorRate,
    required this.fillerMetrics,
    required this.referenceWpm,
    required this.hypothesisWpm,
    required this.wpmSignedError,
    required this.wpmAbsoluteError,
    required this.latency,
  });

  final TranscriptionEvaluationStatus status;
  final int referenceWordCount;
  final int? hypothesisWordCount;
  final double? wordErrorRate;
  final double? characterErrorRate;
  final FillerDetectionMetrics? fillerMetrics;
  final double? referenceWpm;
  final double? hypothesisWpm;
  final double? wpmSignedError;
  final double? wpmAbsoluteError;
  final Duration? latency;
}

abstract final class TranscriptionAccuracyEvaluator {
  static TranscriptionEvaluationResult evaluate({
    required String? referenceTranscript,
    required String? hypothesisTranscript,
    required Duration rehearsalDuration,
    Duration? latency,
  }) {
    final referenceWords = TranscriptionEvaluationNormalizer.words(
      referenceTranscript,
    );
    if (referenceWords.isEmpty) {
      return TranscriptionEvaluationResult(
        status: TranscriptionEvaluationStatus.missingReference,
        referenceWordCount: 0,
        hypothesisWordCount: hypothesisTranscript == null
            ? null
            : TranscriptionEvaluationNormalizer.words(
                hypothesisTranscript,
              ).length,
        wordErrorRate: null,
        characterErrorRate: null,
        fillerMetrics: null,
        referenceWpm: null,
        hypothesisWpm: null,
        wpmSignedError: null,
        wpmAbsoluteError: null,
        latency: latency,
      );
    }

    if (hypothesisTranscript == null) {
      return TranscriptionEvaluationResult(
        status: TranscriptionEvaluationStatus.missingHypothesis,
        referenceWordCount: referenceWords.length,
        hypothesisWordCount: null,
        wordErrorRate: null,
        characterErrorRate: null,
        fillerMetrics: null,
        referenceWpm: _wpm(referenceWords.length, rehearsalDuration),
        hypothesisWpm: null,
        wpmSignedError: null,
        wpmAbsoluteError: null,
        latency: latency,
      );
    }

    final hypothesisWords = TranscriptionEvaluationNormalizer.words(
      hypothesisTranscript,
    );
    final referenceText = referenceWords.join(' ');
    final hypothesisText = hypothesisWords.join(' ');
    final wordErrorRate =
        _editDistance(referenceWords, hypothesisWords) / referenceWords.length;
    final referenceCharacters = referenceText.runes.toList();
    final hypothesisCharacters = hypothesisText.runes.toList();
    final characterErrorRate =
        _editDistance(referenceCharacters, hypothesisCharacters) /
        referenceCharacters.length;
    final fillerMetrics = _compareFillers(referenceWords, hypothesisWords);
    final referenceWpm = _wpm(referenceWords.length, rehearsalDuration);
    final hypothesisWpm = _wpm(hypothesisWords.length, rehearsalDuration);
    final signedError = referenceWpm == null || hypothesisWpm == null
        ? null
        : hypothesisWpm - referenceWpm;

    return TranscriptionEvaluationResult(
      status: hypothesisWords.isEmpty
          ? TranscriptionEvaluationStatus.emptyHypothesis
          : TranscriptionEvaluationStatus.available,
      referenceWordCount: referenceWords.length,
      hypothesisWordCount: hypothesisWords.length,
      wordErrorRate: wordErrorRate,
      characterErrorRate: characterErrorRate,
      fillerMetrics: fillerMetrics,
      referenceWpm: referenceWpm,
      hypothesisWpm: hypothesisWpm,
      wpmSignedError: signedError,
      wpmAbsoluteError: signedError?.abs(),
      latency: latency,
    );
  }

  static double? _wpm(int words, Duration duration) {
    if (duration.inMicroseconds <= 0) return null;
    return words / (duration.inMicroseconds / Duration.microsecondsPerMinute);
  }

  static FillerDetectionMetrics _compareFillers(
    List<String> referenceWords,
    List<String> hypothesisWords,
  ) {
    final reference = FillerAnalysis.fromTranscript(
      referenceWords.join(' '),
      Duration.zero,
    ).counts;
    final hypothesis = FillerAnalysis.fromTranscript(
      hypothesisWords.join(' '),
      Duration.zero,
    ).counts;
    var correct = 0;
    var missed = 0;
    var incorrect = 0;
    final matrix = _editDistanceMatrix(referenceWords, hypothesisWords);
    var referenceIndex = referenceWords.length;
    var hypothesisIndex = hypothesisWords.length;
    while (referenceIndex > 0 || hypothesisIndex > 0) {
      if (referenceIndex > 0 && hypothesisIndex > 0) {
        final referenceWord = referenceWords[referenceIndex - 1];
        final hypothesisWord = hypothesisWords[hypothesisIndex - 1];
        final substitutionCost = referenceWord == hypothesisWord ? 0 : 1;
        if (matrix[referenceIndex][hypothesisIndex] ==
            matrix[referenceIndex - 1][hypothesisIndex - 1] +
                substitutionCost) {
          final referenceFiller = _fillerName(referenceWord);
          final hypothesisFiller = _fillerName(hypothesisWord);
          if (referenceFiller != null &&
              referenceFiller == hypothesisFiller &&
              substitutionCost == 0) {
            correct++;
          } else {
            if (referenceFiller != null) missed++;
            if (hypothesisFiller != null) incorrect++;
          }
          referenceIndex--;
          hypothesisIndex--;
          continue;
        }
      }
      if (referenceIndex > 0 &&
          matrix[referenceIndex][hypothesisIndex] ==
              matrix[referenceIndex - 1][hypothesisIndex] + 1) {
        if (_fillerName(referenceWords[referenceIndex - 1]) != null) missed++;
        referenceIndex--;
        continue;
      }
      if (hypothesisIndex > 0) {
        if (_fillerName(hypothesisWords[hypothesisIndex - 1]) != null) {
          incorrect++;
        }
        hypothesisIndex--;
      }
    }
    final precisionDenominator = correct + incorrect;
    final recallDenominator = correct + missed;
    final f1Denominator = (2 * correct) + incorrect + missed;
    return FillerDetectionMetrics(
      referenceCounts: Map.unmodifiable(reference),
      hypothesisCounts: Map.unmodifiable(hypothesis),
      correct: correct,
      missed: missed,
      incorrect: incorrect,
      precision: precisionDenominator == 0
          ? null
          : correct / precisionDenominator,
      recall: recallDenominator == 0 ? null : correct / recallDenominator,
      f1: f1Denominator == 0 ? null : (2 * correct) / f1Denominator,
    );
  }

  static String? _fillerName(String word) {
    final counts = FillerAnalysis.fromTranscript(word, Duration.zero).counts;
    return counts.length == 1 && counts.values.single == 1
        ? counts.keys.single
        : null;
  }

  static int _editDistance<T>(List<T> reference, List<T> hypothesis) {
    if (reference.isEmpty) return hypothesis.length;
    if (hypothesis.isEmpty) return reference.length;
    var previous = List<int>.generate(hypothesis.length + 1, (index) => index);
    for (
      var referenceIndex = 1;
      referenceIndex <= reference.length;
      referenceIndex++
    ) {
      final current = List<int>.filled(hypothesis.length + 1, 0);
      current[0] = referenceIndex;
      for (
        var hypothesisIndex = 1;
        hypothesisIndex <= hypothesis.length;
        hypothesisIndex++
      ) {
        final substitutionCost =
            reference[referenceIndex - 1] == hypothesis[hypothesisIndex - 1]
            ? 0
            : 1;
        final deletion = previous[hypothesisIndex] + 1;
        final insertion = current[hypothesisIndex - 1] + 1;
        final substitution = previous[hypothesisIndex - 1] + substitutionCost;
        current[hypothesisIndex] = [
          deletion,
          insertion,
          substitution,
        ].reduce((left, right) => left < right ? left : right);
      }
      previous = current;
    }
    return previous.last;
  }

  static List<List<int>> _editDistanceMatrix<T>(
    List<T> reference,
    List<T> hypothesis,
  ) {
    final matrix = List.generate(
      reference.length + 1,
      (_) => List<int>.filled(hypothesis.length + 1, 0),
    );
    for (var index = 0; index <= reference.length; index++) {
      matrix[index][0] = index;
    }
    for (var index = 0; index <= hypothesis.length; index++) {
      matrix[0][index] = index;
    }
    for (
      var referenceIndex = 1;
      referenceIndex <= reference.length;
      referenceIndex++
    ) {
      for (
        var hypothesisIndex = 1;
        hypothesisIndex <= hypothesis.length;
        hypothesisIndex++
      ) {
        final substitutionCost =
            reference[referenceIndex - 1] == hypothesis[hypothesisIndex - 1]
            ? 0
            : 1;
        final deletion = matrix[referenceIndex - 1][hypothesisIndex] + 1;
        final insertion = matrix[referenceIndex][hypothesisIndex - 1] + 1;
        final substitution =
            matrix[referenceIndex - 1][hypothesisIndex - 1] + substitutionCost;
        matrix[referenceIndex][hypothesisIndex] = [
          deletion,
          insertion,
          substitution,
        ].reduce((left, right) => left < right ? left : right);
      }
    }
    return matrix;
  }
}

class TranscriptionEvaluationRow {
  const TranscriptionEvaluationRow({
    required this.recordingId,
    required this.configuration,
    required this.metrics,
    required this.rehearsalDurationSeconds,
    required this.referenceVerified,
    this.audioDurationSeconds,
    this.languageGroup,
    this.environment,
    this.speakingVolume,
    this.microphone,
    this.boundaryCase,
    this.interruptionNotes,
    this.statusOverride,
  });

  final String recordingId;
  final TranscriptionEvaluationConfig configuration;
  final TranscriptionEvaluationResult metrics;
  final double rehearsalDurationSeconds;
  final bool referenceVerified;
  final double? audioDurationSeconds;
  final String? languageGroup;
  final String? environment;
  final String? speakingVolume;
  final String? microphone;
  final String? boundaryCase;
  final String? interruptionNotes;
  final String? statusOverride;

  double? get audioRehearsalDifferenceSeconds => audioDurationSeconds == null
      ? null
      : audioDurationSeconds! - rehearsalDurationSeconds;
}

abstract final class TranscriptionEvaluationCsv {
  static const headers = [
    'recording_id',
    'configuration',
    'model',
    'context_enabled',
    'status',
    'reference_verified',
    'language_group',
    'reference_words',
    'hypothesis_words',
    'wer',
    'cer',
    'filler_correct',
    'filler_missed',
    'filler_incorrect',
    'filler_precision',
    'filler_recall',
    'filler_f1',
    'reference_filler_counts',
    'hypothesis_filler_counts',
    'reference_wpm',
    'hypothesis_wpm',
    'wpm_signed_error',
    'wpm_absolute_error',
    'latency_ms',
    'rehearsal_duration_seconds',
    'audio_duration_seconds',
    'audio_minus_rehearsal_seconds',
    'environment',
    'speaking_volume',
    'microphone',
    'boundary_case',
    'interruption_notes',
  ];

  static String encode(Iterable<TranscriptionEvaluationRow> rows) {
    final output = StringBuffer()..writeln(headers.map(_escape).join(','));
    for (final row in rows) {
      final metrics = row.metrics;
      final fillers = metrics.fillerMetrics;
      final values = <Object?>[
        row.recordingId,
        row.configuration.id,
        row.configuration.model.apiName,
        row.configuration.contextEnabled,
        row.statusOverride ?? metrics.status.name,
        row.referenceVerified,
        row.languageGroup,
        metrics.referenceWordCount,
        metrics.hypothesisWordCount,
        metrics.wordErrorRate,
        metrics.characterErrorRate,
        fillers?.correct,
        fillers?.missed,
        fillers?.incorrect,
        fillers?.precision,
        fillers?.recall,
        fillers?.f1,
        fillers == null ? null : jsonEncode(fillers.referenceCounts),
        fillers == null ? null : jsonEncode(fillers.hypothesisCounts),
        metrics.referenceWpm,
        metrics.hypothesisWpm,
        metrics.wpmSignedError,
        metrics.wpmAbsoluteError,
        metrics.latency?.inMicroseconds == null
            ? null
            : metrics.latency!.inMicroseconds / 1000,
        row.rehearsalDurationSeconds,
        row.audioDurationSeconds,
        row.audioRehearsalDifferenceSeconds,
        row.environment,
        row.speakingVolume,
        row.microphone,
        row.boundaryCase,
        row.interruptionNotes,
      ];
      output.writeln(values.map(_format).map(_escape).join(','));
    }
    return output.toString();
  }

  static String _format(Object? value) {
    if (value == null) return 'NA';
    if (value is double) {
      if (!value.isFinite) return 'NA';
      return value.toStringAsFixed(6);
    }
    return value.toString();
  }

  static String _escape(Object? value) {
    final text = value?.toString() ?? 'NA';
    if (!text.contains(RegExp('[,"\r\n]'))) return text;
    return '"${text.replaceAll('"', '""')}"';
  }
}
