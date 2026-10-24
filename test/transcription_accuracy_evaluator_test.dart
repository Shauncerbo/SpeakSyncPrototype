import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/groq_transcription_service.dart';
import 'package:speaksync_prototype/services/live_filler_feedback_service.dart';
import 'package:speaksync_prototype/services/transcription_accuracy_evaluator.dart';

void main() {
  test('defines the four controlled model and context configurations', () {
    expect(TranscriptionEvaluationConfig.all.map((config) => config.id), [
      'turbo_context_off',
      'turbo_context_on',
      'large_v3_context_off',
      'large_v3_context_on',
    ]);
    expect(TranscriptionEvaluationConfig.all.map((config) => config.model), [
      GroqWhisperModel.turbo,
      GroqWhisperModel.turbo,
      GroqWhisperModel.largeV3,
      GroqWhisperModel.largeV3,
    ]);
  });

  test(
    'normalization preserves fillers and canonicalizes supported variants',
    () {
      expect(
        TranscriptionEvaluationNormalizer.words(
          "KU’AN, kwan; mura'g murag! Ummm, uhhm, ahhh.",
        ),
        ['kuan', 'kuan', 'murag', 'murag', 'um', 'uhm', 'ah'],
      );
      expect(
        TranscriptionEvaluationNormalizer.normalizedText(
          'English-Filipino ug Bisaya.',
        ),
        'english-filipino ug bisaya',
      );
    },
  );

  test(
    'known English edits produce reproducible WER and filler metrics',
    () async {
      final result = TranscriptionAccuracyEvaluator.evaluate(
        referenceTranscript: await _fixture('english_reference.txt'),
        hypothesisTranscript: await _fixture('english_hypothesis.txt'),
        rehearsalDuration: const Duration(seconds: 30),
        latency: const Duration(milliseconds: 1250),
      );

      expect(result.status, TranscriptionEvaluationStatus.available);
      expect(result.referenceWordCount, 10);
      expect(result.hypothesisWordCount, 9);
      expect(result.wordErrorRate, closeTo(0.2, 1e-12));
      expect(result.fillerMetrics?.correct, 0);
      expect(result.fillerMetrics?.missed, 1);
      expect(result.fillerMetrics?.incorrect, 0);
      expect(result.fillerMetrics?.precision, isNull);
      expect(result.fillerMetrics?.recall, 0);
      expect(result.fillerMetrics?.f1, 0);
      expect(result.referenceWpm, 20);
      expect(result.hypothesisWpm, 18);
      expect(result.wpmSignedError, -2);
      expect(result.wpmAbsoluteError, 2);
      expect(result.latency, const Duration(milliseconds: 1250));
    },
  );

  test(
    'legitimate localized spelling variants have zero WER and CER',
    () async {
      final result = TranscriptionAccuracyEvaluator.evaluate(
        referenceTranscript: await _fixture('code_switched_reference.txt'),
        hypothesisTranscript: await _fixture('code_switched_hypothesis.txt'),
        rehearsalDuration: const Duration(seconds: 20),
      );

      expect(result.wordErrorRate, 0);
      expect(result.characterErrorRate, 0);
      expect(result.fillerMetrics?.correct, 4);
      expect(result.fillerMetrics?.missed, 0);
      expect(result.fillerMetrics?.incorrect, 0);
      expect(result.fillerMetrics?.precision, 1);
      expect(result.fillerMetrics?.recall, 1);
      expect(result.fillerMetrics?.f1, 1);
    },
  );

  for (final language in ['filipino', 'cebuano']) {
    test(
      '$language synthetic fixture produces finite comparison metrics',
      () async {
        final result = TranscriptionAccuracyEvaluator.evaluate(
          referenceTranscript: await _fixture('${language}_reference.txt'),
          hypothesisTranscript: await _fixture('${language}_hypothesis.txt'),
          rehearsalDuration: const Duration(seconds: 30),
        );

        expect(result.status, TranscriptionEvaluationStatus.available);
        expect(result.wordErrorRate, isNotNull);
        expect(result.characterErrorRate, isNotNull);
        expect(result.wordErrorRate!.isFinite, isTrue);
        expect(result.characterErrorRate!.isFinite, isTrue);
        expect(result.fillerMetrics, isNotNull);
      },
    );
  }

  test('naturally repeated filler occurrences are counted separately', () {
    final result = TranscriptionAccuracyEvaluator.evaluate(
      referenceTranscript: 'Ano, ano, kuan.',
      hypothesisTranscript: 'Ano, kuan, kuan.',
      rehearsalDuration: const Duration(seconds: 10),
    );

    expect(result.fillerMetrics?.referenceCounts, {'ano': 2, 'kuan': 1});
    expect(result.fillerMetrics?.hypothesisCounts, {'ano': 1, 'kuan': 2});
    expect(result.fillerMetrics?.correct, 2);
    expect(result.fillerMetrics?.missed, 1);
    expect(result.fillerMetrics?.incorrect, 1);
    expect(result.fillerMetrics?.precision, closeTo(2 / 3, 1e-12));
    expect(result.fillerMetrics?.recall, closeTo(2 / 3, 1e-12));
    expect(result.fillerMetrics?.f1, closeTo(2 / 3, 1e-12));
  });

  test('same filler count at the wrong aligned location is not credited', () {
    final result = TranscriptionAccuracyEvaluator.evaluate(
      referenceTranscript: 'ano clear speech',
      hypothesisTranscript: 'clear speech ano',
      rehearsalDuration: const Duration(seconds: 10),
    );

    expect(result.fillerMetrics?.referenceCounts, {'ano': 1});
    expect(result.fillerMetrics?.hypothesisCounts, {'ano': 1});
    expect(result.fillerMetrics?.correct, 0);
    expect(result.fillerMetrics?.missed, 1);
    expect(result.fillerMetrics?.incorrect, 1);
  });

  test('timestamp overlap is removed while a new repeated filler remains', () {
    final novel = LiveFillerFeedbackService.transcriptAfterOverlap(const [
      GroqTranscribedWord(word: 'ano', startSeconds: 0.1, endSeconds: 0.3),
      GroqTranscribedWord(word: 'ano', startSeconds: 0.9, endSeconds: 1.1),
    ], const Duration(milliseconds: 750));
    final result = TranscriptionAccuracyEvaluator.evaluate(
      referenceTranscript: 'ano ano',
      hypothesisTranscript: 'ano $novel',
      rehearsalDuration: const Duration(seconds: 10),
    );

    expect(novel, 'ano');
    expect(result.fillerMetrics?.correct, 2);
    expect(result.fillerMetrics?.missed, 0);
    expect(result.fillerMetrics?.incorrect, 0);
  });

  test('empty hypothesis is scored as complete loss rather than excluded', () {
    final result = TranscriptionAccuracyEvaluator.evaluate(
      referenceTranscript: 'Ano this is spoken',
      hypothesisTranscript: '',
      rehearsalDuration: const Duration(seconds: 30),
    );

    expect(result.status, TranscriptionEvaluationStatus.emptyHypothesis);
    expect(result.wordErrorRate, 1);
    expect(result.characterErrorRate, 1);
    expect(result.fillerMetrics?.missed, 1);
    expect(result.hypothesisWpm, 0);
    expect(result.wpmAbsoluteError, result.referenceWpm);
  });

  test('missing hypothesis and reference are explicitly unavailable', () {
    final missingHypothesis = TranscriptionAccuracyEvaluator.evaluate(
      referenceTranscript: 'Valid reference',
      hypothesisTranscript: null,
      rehearsalDuration: const Duration(seconds: 30),
    );
    expect(
      missingHypothesis.status,
      TranscriptionEvaluationStatus.missingHypothesis,
    );
    expect(missingHypothesis.wordErrorRate, isNull);
    expect(missingHypothesis.fillerMetrics, isNull);

    final missingReference = TranscriptionAccuracyEvaluator.evaluate(
      referenceTranscript: ' ',
      hypothesisTranscript: 'Some generated words',
      rehearsalDuration: const Duration(seconds: 30),
    );
    expect(
      missingReference.status,
      TranscriptionEvaluationStatus.missingReference,
    );
    expect(missingReference.wordErrorRate, isNull);
    expect(missingReference.characterErrorRate, isNull);
  });

  test(
    'zero duration leaves WPM comparison unavailable without hiding WER',
    () {
      final result = TranscriptionAccuracyEvaluator.evaluate(
        referenceTranscript: 'one two three',
        hypothesisTranscript: 'one two',
        rehearsalDuration: Duration.zero,
      );

      expect(result.wordErrorRate, closeTo(1 / 3, 1e-12));
      expect(result.referenceWpm, isNull);
      expect(result.hypothesisWpm, isNull);
      expect(result.wpmSignedError, isNull);
      expect(result.wpmAbsoluteError, isNull);
    },
  );

  test('CSV identifies unavailable values and duration mismatch', () {
    final metrics = TranscriptionAccuracyEvaluator.evaluate(
      referenceTranscript: 'one two',
      hypothesisTranscript: null,
      rehearsalDuration: const Duration(seconds: 10),
    );
    final csv = TranscriptionEvaluationCsv.encode([
      TranscriptionEvaluationRow(
        recordingId: 'anonymous,001',
        configuration: TranscriptionEvaluationConfig.all.first,
        metrics: metrics,
        rehearsalDurationSeconds: 10,
        referenceVerified: true,
        audioDurationSeconds: 8.5,
        languageGroup: 'code_switched',
        interruptionNotes: 'temporary interruption, reviewed',
        statusOverride: 'api_timeout',
      ),
    ]);

    expect(csv, contains('wpm_absolute_error'));
    expect(csv, contains('api_timeout'));
    expect(csv, contains('NA'));
    expect(csv, contains('reference_verified,language_group'));
    expect(csv, contains('true,code_switched'));
    expect(csv, contains('-1.500000'));
    expect(csv, contains('"anonymous,001"'));
    expect(csv, contains('"temporary interruption, reviewed"'));
  });
}

Future<String> _fixture(String name) =>
    File('evaluation/fixtures/$name').readAsString();
