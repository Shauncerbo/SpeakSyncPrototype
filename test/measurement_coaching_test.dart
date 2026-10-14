import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:speaksync_prototype/data/dummy_data.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/models/practice_settings.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/screens/progress_screens.dart';
import 'package:speaksync_prototype/services/camera_framing.dart';
import 'package:speaksync_prototype/services/camera_framing_summary.dart';
import 'package:speaksync_prototype/state/app_state.dart';
import 'package:speaksync_prototype/storage/hive_repository.dart';

PracticeSession session({
  String id = 'session-coaching',
  int words = 140,
  String? transcript,
  bool hasTranscript = true,
  Duration duration = const Duration(minutes: 1),
  int? posture,
  int? validPose,
  int? attention,
  int? validFace,
  Map<String, int>? framing,
  bool monitoring = true,
}) => PracticeSession(
  id: id,
  title: 'Measured speech',
  speechType: 'Impromptu',
  languageMode: 'Mixed Language',
  dateTime: DateTime(2026, 10, 15),
  duration: duration,
  overallScore: 99,
  paceScore: 99,
  fillerScore: 99,
  postureScore: posture,
  validPostureSeconds: validPose,
  goodPostureSeconds: posture == null
      ? null
      : ((validPose ?? 0) * posture / 100).floor(),
  attentionScore: attention,
  validFaceAnalysisMilliseconds: validFace,
  cameraFacingSeconds: attention == null
      ? null
      : ((validFace ?? 0) * attention / 100000).floor(),
  cameraFramingMilliseconds: framing,
  monitorPace: monitoring,
  monitorFillers: monitoring,
  monitorBodyLanguage: monitoring,
  monitorCameraAttention: monitoring,
  textTranscript: hasTranscript
      ? transcript ?? List.filled(words, 'word').join(' ')
      : null,
  fillerCounts: const {'simulated': 999},
  coachingTips: const ['Perfect eye contact and a perfect score!'],
  recommendedPosture: 'Fixed legacy recommendation',
  isPrototypeData: true,
);

void main() {
  for (final entry in {
    119: 'Slow',
    120: 'Target',
    160: 'Target',
    161: 'Fast',
  }.entries) {
    test(
      '${entry.key} final words per minute generates ${entry.value} coaching',
      () {
        final value = session(words: entry.key);
        final tip = value.measuredCoachingTips.first;
        expect(tip, contains('${entry.key}.0 WPM'));
        expect(tip, contains(entry.value));
        expect(tip, isNot(contains('99')));
      },
    );
  }
  test(
    'pace uses final transcript and actual duration, not counters or scores',
    () {
      final value = session(words: 280, duration: const Duration(minutes: 2));
      expect(value.speakingPace.wordsPerMinute, 140);
      expect(value.measuredCoachingTips.first, contains('140.0 WPM'));
      expect(
        value.measuredCoachingTips.join(' '),
        isNot(contains('simulated')),
      );
    },
  );
  for (final entry in {
    0: 'Very Low',
    1: 'Very Low',
    2: 'Low / Acceptable',
    5: 'Low / Acceptable',
    6: 'Elevated',
    11: 'Elevated',
    12: 'High',
  }.entries) {
    test('${entry.key} filler matches per minute uses ${entry.value}', () {
      final value = session(
        transcript: ['hello', ...List.filled(entry.key, "ku'an")].join(' '),
      );
      final tip = value.measuredCoachingTips.firstWhere(
        (tip) => tip.startsWith('Filler words:'),
      );
      expect(tip, contains('${entry.key} detected dictionary matches'));
      expect(tip, contains('${entry.key}.0 per minute (${entry.value})'));
      expect(tip, contains('meaningful in context'));
    });
  }
  test(
    'fractional filler bands remain documented continuous bands, not rounded',
    () {
      final value = session(
        transcript: 'kuan hello',
        duration: const Duration(seconds: 40),
      );
      expect(value.fillerAnalysis.perMinute, 1.5);
      expect(
        value.measuredCoachingTips.join(' '),
        contains('1.5 per minute (Very Low)'),
      );
    },
  );
  test('frequent expressions ranked by actual transcript occurrences', () {
    final value = session(transcript: 'kuan kuan kuan ano ano kasi word');
    expect(
      value.measuredCoachingTips.join(' '),
      contains('kuan (3), ano (2), kasi (1)'),
    );
    expect(value.measuredCoachingTips.join(' '), contains('calm pause'));
  });
  for (final duration in [Duration.zero, const Duration(seconds: -1)]) {
    test('$duration never invents pace or filler frequency', () {
      final value = session(
        transcript: 'kuan we have words',
        duration: duration,
      );
      expect(value.measuredCoachingTips.first, contains('unavailable'));
      final filler = value.measuredCoachingTips[1];
      expect(filler, contains('1 detected dictionary matches'));
      expect(filler, contains('Frequency is unavailable'));
      expect(filler, isNot(contains('Very Low')));
    });
  }
  test('missing transcript is unavailable, not perfect performance', () {
    final value = session(hasTranscript: false);
    expect(value.measuredCoachingTips[0], contains('unavailable'));
    expect(value.measuredCoachingTips[1], contains('unavailable'));
    expect(value.measuredCoachingTips.join(' '), isNot(contains('perfect')));
  });
  test('measured zero posture receives advice, missing landmarks do not', () {
    expect(
      session(posture: 0, validPose: 50).measuredCoachingTips.join(' '),
      contains('Some valid pose samples needed adjustment'),
    );
    for (final seconds in <int?>[null, 0, 2]) {
      final value = session(posture: 0, validPose: seconds);
      expect(
        value.postureCoachingRecommendation,
        contains('Missing landmarks are not poor posture'),
      );
      expect(
        value.postureCoachingRecommendation,
        isNot(contains('needed adjustment')),
      );
    }
  });
  test('genuine acceptable posture and unavailable legacy posture differ', () {
    expect(
      session(posture: 100, validPose: 30).postureCoachingRecommendation,
      contains('met the current posture criteria'),
    );
    expect(
      session(posture: 90).postureCoachingRecommendation,
      contains('unavailable'),
    );
  });
  test('head direction only uses sufficient genuine face coverage', () {
    final measured = session(attention: 60, validFace: 10000);
    expect(
      measured.measuredCoachingTips.join(' '),
      contains('60% of 10.0 valid analysis seconds'),
    );
    expect(
      measured.measuredCoachingTips.join(' '),
      contains('facing the camera more consistently'),
    );
    for (final milliseconds in <int?>[null, 0, 2999]) {
      final value = session(attention: 82, validFace: milliseconds);
      expect(value.measuredCoachingTips.join(' '), isNot(contains('82%')));
      expect(
        value.measuredCoachingTips.join(' '),
        isNot(contains('turned away')),
      );
    }
    expect(
      measured.measuredCoachingTips.join(' '),
      contains('not eye contact or audience engagement'),
    );
  });
  test('framing close/far suggestions are separate from head direction', () {
    final value = session(
      framing: const {'tooClose': 1500, 'tooFar': 2000, 'proper': 1000},
    );
    final tip = value.measuredCoachingTips.firstWhere(
      (tip) => tip.startsWith('Camera framing:'),
    );
    expect(tip, contains('move farther'));
    expect(tip, contains('move closer'));
    expect(tip, contains('separate from head direction'));
    expect(
      session(framing: const {'proper': 1000}).measuredCoachingTips.join(' '),
      contains('Camera framing: Proper'),
    );
    expect(
      session(framing: const {}).measuredCoachingTips.join(' '),
      contains('Camera framing: unavailable'),
    );
  });
  test(
    'disabled monitoring and demo records do not produce performance advice',
    () {
      final value = session(
        monitoring: false,
        posture: 0,
        validPose: 50,
        attention: 0,
        validFace: 10000,
        framing: const {'tooClose': 3000},
      );
      expect(value.measuredCoachingTips.single, contains('Monitoring was off'));
      expect(value.measuredPosturePercentage, isNull);
      expect(value.measuredAttentionPercentage, isNull);
      expect(
        session(
          id: 'initial-1',
          words: 161,
          posture: 0,
          validPose: 50,
        ).measuredCoachingTips.single,
        contains('Example rehearsal'),
      );
    },
  );
  test(
    'framing aggregation excludes missing frames, long gaps and restart',
    () {
      final tracker = CameraFramingSummaryTracker(
        maximumSampleGap: const Duration(milliseconds: 700),
      );
      tracker.addFrame(CameraFramingState.tooClose, Duration.zero);
      tracker.addFrame(
        CameraFramingState.tooFar,
        const Duration(milliseconds: 500),
      );
      tracker.addFrame(CameraFramingState.proper, const Duration(seconds: 1));
      tracker.addFrame(
        CameraFramingState.unavailable,
        const Duration(milliseconds: 1500),
      );
      tracker.addFrame(CameraFramingState.proper, const Duration(seconds: 2));
      tracker.addFrame(CameraFramingState.proper, const Duration(seconds: 5));
      expect(tracker.milliseconds, {
        'tooClose': 500,
        'tooFar': 500,
        'proper': 0,
      });
      tracker.interrupt();
      expect(tracker.milliseconds['tooClose'], 500);
      tracker.reset();
      expect(tracker.milliseconds.values.every((value) => value == 0), isTrue);
    },
  );

  test('each monitoring override suppresses only its own coaching area', () {
    final value = session(
      posture: 50,
      validPose: 50,
      attention: 50,
      validFace: 10000,
      framing: const {'tooClose': 1000},
    );
    expect(
      value
          .measuredCoachingTipsFor(includePace: false)
          .any((tip) => tip.startsWith('Speaking pace:')),
      isFalse,
    );
    expect(
      value
          .measuredCoachingTipsFor(includeFillers: false)
          .any((tip) => tip.startsWith('Filler words:')),
      isFalse,
    );
    expect(
      value
          .measuredCoachingTipsFor(includePosture: false)
          .any(
            (tip) =>
                tip.startsWith('Upper-body posture:') ||
                tip.startsWith('Camera framing:'),
          ),
      isFalse,
    );
    expect(
      value
          .measuredCoachingTipsFor(includeCameraFacing: false)
          .any((tip) => tip.startsWith('Estimated camera-facing')),
      isFalse,
    );
  });

  test(
    'unavailable measurements retain enabled monitoring and coaching after saving',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'speaksync-unavailable-',
      );
      try {
        final repository = HiveRepository();
        await repository.initializeStorage(storagePath: directory.path);
        await repository.seedDemoDataOnce(
          sessions: const [],
          preferences: initialPreferences,
        );
        final value = session(hasTranscript: false);
        await repository.saveCompletedRehearsal(practiceSession: value);
        final loaded = repository.getPracticeSessions().single;
        expect(loaded.monitorCameraAttention, isTrue);
        expect(loaded.measuredCoachingTips, value.measuredCoachingTips);
        expect(loaded.measuredAttentionPercentage, isNull);
        expect(loaded.measuredPosturePercentage, isNull);
      } finally {
        await Hive.close();
        await directory.delete(recursive: true);
      }
    },
  );

  for (final enabled in [true, false]) {
    test(
      'saving/reopening retains consistent coaching with monitoring $enabled',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'speaksync-coaching-',
        );
        try {
          var repository = HiveRepository();
          await repository.initializeStorage(storagePath: directory.path);
          await repository.seedDemoDataOnce(
            sessions: const [],
            preferences: initialPreferences,
          );
          final value = session(
            transcript: 'kuan kuan we practice today',
            posture: 50,
            validPose: 40,
            attention: 60,
            validFace: 10000,
            framing: const {'tooClose': 1500, 'tooFar': 500, 'proper': 1000},
          );
          final setup = PracticeSettings(
            speechTitle: value.title,
            speechType: 'Impromptu',
            languageMode: 'Mixed Language',
            selectedDuration: '1 minute',
            monitorBodyLanguage: enabled,
            monitorCameraAttention: enabled,
            monitorFillers: enabled,
            monitorPace: enabled,
            enableLiveFeedback: false,
          );
          await repository.saveCompletedRehearsal(
            practiceSession: value,
            settings: setup,
          );
          final expected = value.measuredCoachingTipsFor(
            includePace: enabled,
            includeFillers: enabled,
            includePosture: enabled,
            includeCameraFacing: enabled,
          );
          final stored = repository.getPracticeSessions().single;
          expect(stored.coachingTips, expected);
          expect(stored.measuredCoachingTips, expected);
          expect(
            stored.cameraFramingMilliseconds,
            enabled ? value.cameraFramingMilliseconds : null,
          );
          expect(stored.textTranscript, value.textTranscript);
          expect(stored.overallScore, isNull);
          expect(stored.paceScore, isNull);
          expect(stored.fillerScore, isNull);
          await Hive.close();
          repository = HiveRepository();
          await repository.initializeStorage(storagePath: directory.path);
          final reopened = repository.getPracticeSessions().single;
          expect(reopened.measuredCoachingTips, expected);
          expect(reopened.monitorPace, enabled);
          expect(reopened.monitorFillers, enabled);
          expect(reopened.monitorBodyLanguage, enabled);
          expect(reopened.monitorCameraAttention, enabled);
        } finally {
          await Hive.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  for (final details in [false, true]) {
    testWidgets(
      'monitoring OFF report/details never display measured verdicts ($details)',
      (tester) async {
        final value = session(
          monitoring: false,
          posture: 0,
          validPose: 50,
          attention: 0,
          validFace: 10000,
          framing: const {'tooClose': 1000},
        );
        final state = AppState()..setCurrentReport(value);
        await tester.pumpWidget(
          AppStateScope(
            notifier: state,
            child: MaterialApp(
              home: details
                  ? SessionDetailsScreen(session: value)
                  : const ReportScreen(),
            ),
          ),
        );
        expect(
          find.text('Speaking Pace: monitoring off for this rehearsal.'),
          findsOneWidget,
        );
        expect(
          find.text('Filler frequency: monitoring off for this rehearsal.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Fixed legacy recommendation'),
          findsNothing,
        );
        expect(find.textContaining('Perfect eye contact'), findsNothing);
        expect(
          find.textContaining('Some valid pose samples needed adjustment'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
