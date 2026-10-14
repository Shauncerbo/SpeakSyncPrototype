import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:speaksync_prototype/data/dummy_data.dart';
import 'package:speaksync_prototype/models/performance_report.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/models/practice_settings.dart';
import 'package:speaksync_prototype/storage/hive_box_names.dart';
import 'package:speaksync_prototype/storage/hive_repository.dart';

PracticeSession _session({
  String id = 'nullable-session',
  String? transcript = "Ku'an we practice speaking today",
  Duration duration = const Duration(minutes: 1),
  int? posture = 0,
  int? goodSeconds = 0,
  int? validSeconds = 50,
  int? faceMilliseconds,
  int? facingSeconds,
  int? attention = 82,
}) => PracticeSession(
  id: id,
  title: 'Nullable measurements',
  speechType: 'Impromptu',
  languageMode: 'Mixed Language',
  dateTime: DateTime(2026, 10, 10),
  duration: duration,
  // Deliberately pass legacy values: new saves must not persist them as scores.
  overallScore: 100,
  paceScore: 94,
  fillerScore: 100,
  attentionScore: attention,
  cameraFacingSeconds: facingSeconds,
  validFaceAnalysisMilliseconds: faceMilliseconds,
  postureScore: posture,
  goodPostureSeconds: goodSeconds,
  validPostureSeconds: validSeconds,
  fillerCounts: const {'live-only': 999},
  coachingTips: const ['Perfect eye contact!'],
  textTranscript: transcript,
  isPrototypeData: true,
);

PerformanceReport _report({
  int? paceScore,
  int? fillerScore,
  int? postureScore,
  int? cameraScore,
  int? overallScore,
  int? goodSeconds,
  int? cameraSeconds,
  int? validSeconds,
  double? wpm,
  int? faceMilliseconds,
}) => PerformanceReport(
  reportId: 'report-nullable-session',
  sessionId: 'nullable-session',
  totalWords: 5,
  wordsPerMinute: wpm,
  paceScore: paceScore,
  fillerScore: fillerScore,
  goodPostureSeconds: goodSeconds,
  postureScore: postureScore,
  cameraFacingSeconds: cameraSeconds,
  cameraScore: cameraScore,
  overallScore: overallScore,
  validPostureSeconds: validSeconds,
  validFaceAnalysisMilliseconds: faceMilliseconds,
  coachingTips: const ['Perfect eye contact!'],
  textTranscript: "Ku'an we practice speaking today",
  createdAt: DateTime(2026, 10, 10),
  fillerCounts: const {'kuan': 1},
  recommendedPosture: 'Keep steady',
  isPrototypeData: true,
);

// Write the old 17-field wire format with numeric scores. This creates real
// Hive bytes rather than relying only on a mock BinaryReader or new adapter.
class _LegacyNumericReportAdapter extends TypeAdapter<PerformanceReport> {
  @override
  int get typeId => 5;

  @override
  void write(BinaryWriter writer, PerformanceReport obj) {
    final fields = <dynamic>[
      obj.reportId,
      obj.sessionId,
      obj.totalWords,
      obj.wordsPerMinute!,
      obj.paceScore!,
      obj.fillerScore!,
      obj.goodPostureSeconds!,
      obj.postureScore!,
      obj.cameraFacingSeconds!,
      obj.cameraScore!,
      obj.overallScore!,
      obj.coachingTips,
      obj.textTranscript,
      obj.createdAt,
      obj.fillerCounts,
      obj.recommendedPosture,
      obj.isPrototypeData,
    ];
    writer.writeByte(fields.length);
    for (var i = 0; i < fields.length; i++) {
      writer.writeByte(i);
      writer.write(fields[i]);
    }
  }

  @override
  PerformanceReport read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    // Same strict casts as the older APK: null is not downgrade compatible.
    return PerformanceReport(
      reportId: fields[0] as String,
      sessionId: fields[1] as String,
      totalWords: fields[2] as int,
      wordsPerMinute: fields[3] as double,
      paceScore: fields[4] as int,
      fillerScore: fields[5] as int,
      goodPostureSeconds: fields[6] as int,
      postureScore: fields[7] as int,
      cameraFacingSeconds: fields[8] as int,
      cameraScore: fields[9] as int,
      overallScore: fields[10] as int,
      coachingTips: (fields[11] as List).cast<String>(),
      textTranscript: fields[12] as String?,
      createdAt: fields[13] as DateTime,
      fillerCounts: (fields[14] as Map).cast<String, int>(),
      recommendedPosture: fields[15] as String,
      isPrototypeData: fields[16] as bool,
    );
  }
}

// Exact nullable 26-field contract before Phase 3; intentionally unaware of 26.
class _Phase2AReportAdapter extends TypeAdapter<PerformanceReport> {
  @override
  int get typeId => 5;

  @override
  void write(BinaryWriter writer, PerformanceReport r) {
    final fields = <dynamic>[
      r.reportId,
      r.sessionId,
      r.totalWords,
      r.wordsPerMinute,
      r.paceScore,
      r.fillerScore,
      r.goodPostureSeconds,
      r.postureScore,
      r.cameraFacingSeconds,
      r.cameraScore,
      r.overallScore,
      r.coachingTips,
      r.textTranscript,
      r.createdAt,
      r.fillerCounts,
      r.recommendedPosture,
      r.isPrototypeData,
      r.referenceScript,
      r.referenceDocumentName,
      r.omittedScriptPortions,
      r.addedTranscriptPortions,
      r.differentlyDeliveredPortions,
      r.totalScriptWords,
      r.matchedScriptWords,
      r.scriptComparisonStatus,
      r.validPostureSeconds,
    ];
    writer.writeByte(26);
    for (var i = 0; i < fields.length; i++) {
      writer.writeByte(i);
      writer.write(fields[i]);
    }
  }

  @override
  PerformanceReport read(BinaryReader reader) {
    final count = reader.readByte();
    final f = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return PerformanceReport(
      reportId: f[0] as String,
      sessionId: f[1] as String,
      totalWords: f[2] as int,
      wordsPerMinute: f[3] as double?,
      paceScore: f[4] as int?,
      fillerScore: f[5] as int?,
      goodPostureSeconds: f[6] as int?,
      postureScore: f[7] as int?,
      cameraFacingSeconds: f[8] as int?,
      cameraScore: f[9] as int?,
      overallScore: f[10] as int?,
      coachingTips: (f[11] as List).cast<String>(),
      textTranscript: f[12] as String?,
      createdAt: f[13] as DateTime,
      fillerCounts: (f[14] as Map).cast<String, int>(),
      recommendedPosture: f[15] as String,
      isPrototypeData: f[16] as bool,
      referenceScript: f[17] as String?,
      referenceDocumentName: f[18] as String?,
      omittedScriptPortions: (f[19] as List?)?.cast<String>() ?? [],
      addedTranscriptPortions: (f[20] as List?)?.cast<String>() ?? [],
      differentlyDeliveredPortions: (f[21] as List?)?.cast<String>() ?? [],
      totalScriptWords: f[22] as int?,
      matchedScriptWords: f[23] as int?,
      scriptComparisonStatus: f[24] as String?,
      validPostureSeconds: f[25] as int?,
    );
  }
}

class _ReportFieldsReader implements BinaryReader {
  _ReportFieldsReader(PerformanceReport report)
    : _indexes = [17, for (var i = 0; i < 17; i++) i].iterator,
      _values = <dynamic>[
        report.reportId,
        report.sessionId,
        report.totalWords,
        report.wordsPerMinute,
        report.paceScore,
        report.fillerScore,
        report.goodPostureSeconds,
        report.postureScore,
        report.cameraFacingSeconds,
        report.cameraScore,
        report.overallScore,
        report.coachingTips,
        report.textTranscript,
        report.createdAt,
        report.fillerCounts,
        report.recommendedPosture,
        report.isPrototypeData,
      ].iterator;

  final Iterator<int> _indexes;
  final Iterator<dynamic> _values;

  @override
  int readByte() {
    _indexes.moveNext();
    return _indexes.current;
  }

  @override
  dynamic read([int? typeId]) {
    _values.moveNext();
    return _values.current;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late HiveRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('speaksync-nullable-');
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(PerformanceReportAdapter());
    }
    repository = HiveRepository();
    await repository.initializeStorage(storagePath: directory.path);
    await repository.seedDemoDataOnce(
      sessions: [],
      preferences: initialPreferences,
    );
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> reopen() async {
    await Hive.close();
    repository = HiveRepository();
    await repository.initializeStorage(storagePath: directory.path);
  }

  test(
    'Measured head direction round trips using existing nullable camera fields',
    () async {
      await repository.saveCompletedRehearsal(
        practiceSession: _session(
          faceMilliseconds: 5000,
          facingSeconds: 3,
          attention: 60,
        ),
      );
      await reopen();
      final report = repository.getPerformanceReportBySessionId(
        'nullable-session',
      )!;
      expect(report.validFaceAnalysisMilliseconds, 5000);
      expect(report.cameraFacingSeconds, 3);
      expect(report.cameraScore, 60);
      expect(report.overallScore, isNull);
      final loaded = repository.getPracticeSessions().single;
      expect(loaded.measuredAttentionPercentage, 60);
      expect(loaded.speakingPace.wordsPerMinute, 5);
      expect(loaded.fillerAnalysis.counts, {'kuan': 1});
      expect(
        loaded.measuredCoachingTips.join(' '),
        contains('not eye contact or audience engagement'),
      );
    },
  );

  test(
    'Phase 2A nullable bytes remain readable with face coverage absent',
    () async {
      await repository.saveCompletedRehearsal(practiceSession: _session());
      final old = _report(wpm: 5.0);
      Hive.registerAdapter(_Phase2AReportAdapter(), override: true);
      await Hive.box<PerformanceReport>(
        HiveBoxNames.performanceReports,
      ).put(old.reportId, old);
      await Hive.close();
      Hive.registerAdapter(PerformanceReportAdapter(), override: true);
      await reopen();
      final report = repository.getPerformanceReportBySessionId(
        'nullable-session',
      )!;
      expect(report.wordsPerMinute, 5);
      expect(report.overallScore, isNull);
      expect(report.cameraScore, isNull);
      expect(report.validFaceAnalysisMilliseconds, isNull);
      expect(report.cameraFramingMilliseconds, isNull);
      expect(
        repository.getPracticeSessions().single.measuredAttentionPercentage,
        isNull,
      );
    },
  );

  test(
    'Old nullable adapter ignores new coverage field without corrupting it',
    () async {
      await repository.saveCompletedRehearsal(
        practiceSession: _session(
          faceMilliseconds: 5000,
          facingSeconds: 3,
          attention: 60,
        ),
      );
      await Hive.close();
      Hive.registerAdapter(_Phase2AReportAdapter(), override: true);
      final box = await Hive.openBox<PerformanceReport>(
        HiveBoxNames.performanceReports,
      );
      final oldView = box.values.single;
      expect(oldView.cameraScore, 60);
      expect(oldView.overallScore, isNull);
      expect(oldView.validFaceAnalysisMilliseconds, isNull);
      await Hive.close();
      Hive.registerAdapter(PerformanceReportAdapter(), override: true);
      await reopen();
      expect(
        repository
            .getPerformanceReportBySessionId('nullable-session')!
            .validFaceAnalysisMilliseconds,
        5000,
      );
      expect(
        repository.getPracticeSessions().single.measuredAttentionPercentage,
        60,
      );
    },
  );

  test(
    'Disabled attention monitoring excludes supplied face data and coaching',
    () async {
      const settings = PracticeSettings(
        speechTitle: 'Nullable measurements',
        speechType: 'Impromptu',
        languageMode: 'Mixed Language',
        selectedDuration: '1 minute',
        monitorBodyLanguage: true,
        monitorCameraAttention: false,
        monitorFillers: true,
        monitorPace: true,
        enableLiveFeedback: false,
      );
      await repository.saveCompletedRehearsal(
        practiceSession: _session(
          faceMilliseconds: 5000,
          facingSeconds: 3,
          attention: 60,
        ),
        settings: settings,
      );
      await reopen();
      final report = repository.getPerformanceReportBySessionId(
        'nullable-session',
      )!;
      expect(report.cameraScore, isNull);
      expect(report.cameraFacingSeconds, isNull);
      expect(report.validFaceAnalysisMilliseconds, isNull);
      expect(
        report.coachingTips.join(' '),
        isNot(contains('head turned away')),
      );
      expect(
        repository.getAllRehearsalSessions().single.cameraAttentionEnabled,
        isFalse,
      );
      expect(report.wordsPerMinute, 5);
      expect(report.fillerCounts, {'kuan': 1});
    },
  );

  test(
    'Valid zero facing differs from insufficient or legacy face evidence',
    () async {
      await repository.saveCompletedRehearsal(
        practiceSession: _session(
          faceMilliseconds: 5000,
          facingSeconds: 0,
          attention: 0,
        ),
      );
      await reopen();
      expect(
        repository.getPracticeSessions().single.measuredAttentionPercentage,
        0,
      );
      expect(
        repository
            .getPerformanceReportBySessionId('nullable-session')!
            .cameraFacingSeconds,
        0,
      );
      for (final milliseconds in <int?>[null, 0, 2999]) {
        final id = 'face-unavailable-$milliseconds';
        await repository.saveCompletedRehearsal(
          practiceSession: _session(
            id: id,
            faceMilliseconds: milliseconds,
            facingSeconds: 0,
            attention: 0,
          ),
        );
        final report = repository.getPerformanceReportBySessionId(id)!;
        expect(report.cameraScore, isNull);
        expect(report.cameraFacingSeconds, isNull);
      }
    },
  );

  test(
    'Repository rejects camera measurements without sufficient provenance',
    () async {
      // Keep Face monitoring enabled before testing direct measurement writes.
      await repository.saveCompletedRehearsal(
        practiceSession: _session(faceMilliseconds: 5000, attention: null),
      );
      for (final report in [
        _report(cameraScore: 82, cameraSeconds: 4),
        _report(cameraScore: 0, cameraSeconds: 0, faceMilliseconds: 2999),
        _report(cameraScore: 50, cameraSeconds: 8, faceMilliseconds: 5000),
        _report(cameraScore: 50, faceMilliseconds: 5000),
        _report(cameraSeconds: 1, faceMilliseconds: 5000),
        _report(faceMilliseconds: -1),
      ]) {
        await expectLater(
          repository.savePerformanceReport(report),
          throwsA(isA<StorageException>()),
        );
      }
      await repository.savePerformanceReport(
        _report(cameraScore: 0, cameraSeconds: 0, faceMilliseconds: 5000),
      );
      expect(
        repository.getPracticeSessions().single.measuredAttentionPercentage,
        0,
      );
    },
  );

  test(
    'New null scores round trip while measured zero posture is retained',
    () async {
      final practice = _session();
      await repository.saveCompletedRehearsal(practiceSession: practice);
      await reopen();
      final report = repository.getPerformanceReportBySessionId(practice.id)!;
      expect(report.paceScore, isNull);
      expect(report.fillerScore, isNull);
      expect(report.cameraFacingSeconds, isNull);
      expect(report.cameraScore, isNull);
      expect(report.overallScore, isNull);
      expect(report.postureScore, 0);
      expect(report.goodPostureSeconds, 0);
      expect(report.validPostureSeconds, 50);
      expect(report.totalWords, 5);
      expect(report.wordsPerMinute, 5);
      expect(report.textTranscript, practice.textTranscript);
      expect(report.fillerCounts, {'kuan': 1});
      expect(report.coachingTips.join(' '), isNot(contains('eye contact')));
      final loaded = repository.getPracticeSessions().single;
      expect(loaded.postureAnalysisUnavailable, isFalse);
      expect(loaded.measuredPosturePercentage, 0);
      expect(loaded.validatedOverallScore, isNull);
      expect(loaded.measuredAttentionPercentage, isNull);
    },
  );

  test(
    'Missing pose data never fabricates posture time or zero percent',
    () async {
      await repository.saveCompletedRehearsal(
        practiceSession: _session(
          posture: 89,
          goodSeconds: null,
          validSeconds: null,
        ),
      );
      await reopen();
      final report = repository.getPerformanceReportBySessionId(
        'nullable-session',
      )!;
      expect(report.postureScore, isNull);
      expect(report.goodPostureSeconds, isNull);
      expect(report.validPostureSeconds, isNull);
      expect(
        repository.getPracticeSessions().single.postureAnalysisUnavailable,
        isTrue,
      );
    },
  );

  test(
    'Insufficient pose coverage retains coverage but not a percentage',
    () async {
      await repository.saveCompletedRehearsal(
        practiceSession: _session(posture: 0, goodSeconds: 0, validSeconds: 2),
      );
      await reopen();
      final report = repository.getPerformanceReportBySessionId(
        'nullable-session',
      )!;
      expect(report.validPostureSeconds, 2);
      expect(report.postureScore, isNull);
      expect(report.goodPostureSeconds, isNull);
    },
  );

  for (final transcript in <String?>[null, '', '...']) {
    test(
      'Unavailable transcript $transcript stores null WPM, not zero',
      () async {
        await repository.saveCompletedRehearsal(
          practiceSession: _session(transcript: transcript),
        );
        await reopen();
        final report = repository.getPerformanceReportBySessionId(
          'nullable-session',
        )!;
        expect(report.totalWords, 0);
        expect(report.wordsPerMinute, isNull);
        expect(report.fillerCounts, isEmpty);
      },
    );
  }

  test('Zero duration keeps recognized words but stores null WPM', () async {
    await repository.saveCompletedRehearsal(
      practiceSession: _session(duration: Duration.zero),
    );
    await reopen();
    final report = repository.getPerformanceReportBySessionId(
      'nullable-session',
    )!;
    expect(report.totalWords, 5);
    expect(report.wordsPerMinute, isNull);
    expect(report.fillerCounts, {'kuan': 1});
  });

  test(
    'Older numeric Hive bytes read without rewriting or validating legacy scores',
    () async {
      await repository.saveCompletedRehearsal(practiceSession: _session());
      final legacy = _report(
        wpm: 5.0,
        paceScore: 94,
        fillerScore: 100,
        postureScore: 88,
        goodSeconds: 53,
        cameraSeconds: 49,
        cameraScore: 82,
        overallScore: 100,
      );
      Hive.registerAdapter(_LegacyNumericReportAdapter(), override: true);
      await Hive.box<PerformanceReport>(
        HiveBoxNames.performanceReports,
      ).put(legacy.reportId, legacy);
      await Hive.close();
      final path =
          '${directory.path}${Platform.pathSeparator}${HiveBoxNames.performanceReports}.hive';
      final before = await File(path).readAsBytes();
      Hive.registerAdapter(PerformanceReportAdapter(), override: true);
      repository = HiveRepository();
      await repository.initializeStorage(storagePath: directory.path);
      final stored = repository.getPerformanceReportBySessionId(
        'nullable-session',
      )!;
      expect(stored.paceScore, 94);
      expect(stored.fillerScore, 100);
      expect(stored.postureScore, 88);
      expect(stored.goodPostureSeconds, 53);
      expect(stored.cameraFacingSeconds, 49);
      expect(stored.cameraScore, 82);
      expect(stored.validFaceAnalysisMilliseconds, isNull);
      expect(stored.cameraFramingMilliseconds, isNull);
      expect(stored.overallScore, 100);
      expect(stored.wordsPerMinute, 5.0);
      expect(stored.textTranscript, legacy.textTranscript);
      expect(stored.fillerCounts, {'kuan': 1});
      final loaded = repository.getPracticeSessions().single;
      expect(loaded.validatedOverallScore, isNull);
      expect(loaded.measuredAttentionPercentage, isNull);
      expect(loaded.measuredPosturePercentage, isNull);
      expect(
        loaded.measuredCoachingTips.join(' '),
        isNot(contains('eye contact')),
      );
      expect(loaded.speakingPace.wordsPerMinute, 5);
      expect(loaded.fillerAnalysis.counts, {'kuan': 1});
      expect(
        await repository.saveCompletedRehearsal(practiceSession: _session()),
        isFalse,
      );
      await Hive.close();
      expect(await File(path).readAsBytes(), orderedEquals(before));
    },
  );

  test(
    'Existing numeric pose records retain genuine measured zero posture',
    () async {
      await repository.saveCompletedRehearsal(practiceSession: _session());
      final legacy = _report(
        wpm: 5.0,
        paceScore: 94,
        fillerScore: 100,
        postureScore: 0,
        goodSeconds: 0,
        validSeconds: 50,
        cameraSeconds: 49,
        cameraScore: 82,
        overallScore: 100,
      );
      // All 26 indexes match the last non-null schema. No import/save sanitization
      // is used here: this is a historical on-disk fixture, not a new student save.
      await Hive.box<PerformanceReport>(
        HiveBoxNames.performanceReports,
      ).put(legacy.reportId, legacy);
      await reopen();
      final report = repository.getPerformanceReportBySessionId(
        'nullable-session',
      )!;
      expect(report.overallScore, 100);
      expect(report.cameraScore, 82);
      expect(report.postureScore, 0);
      expect(report.validPostureSeconds, 50);
      final loaded = repository.getPracticeSessions().single;
      expect(loaded.validatedOverallScore, isNull);
      expect(loaded.measuredAttentionPercentage, isNull);
      expect(loaded.measuredPosturePercentage, 0);
      expect(loaded.postureAnalysisUnavailable, isFalse);
    },
  );

  test(
    'Older strict adapter cannot read newly persisted nullable fields',
    () async {
      await repository.saveCompletedRehearsal(practiceSession: _session());
      await reopen();
      final report = repository.getPerformanceReportBySessionId(
        'nullable-session',
      )!;
      // Exercise old strict casts directly. Opening a box with a deliberately
      // obsolete adapter can leak an open handle on Hive's failure path.
      expect(
        () => _LegacyNumericReportAdapter().read(_ReportFieldsReader(report)),
        throwsA(isA<TypeError>()),
      );
    },
  );

  test(
    'Repository accepts nulls but rejects invalid non-null measurements',
    () async {
      await repository.saveCompletedRehearsal(practiceSession: _session());
      await repository.savePerformanceReport(_report());
      for (final invalid in <PerformanceReport>[
        _report(paceScore: -1),
        _report(fillerScore: 101),
        _report(postureScore: -1),
        _report(cameraScore: 101),
        _report(overallScore: -1),
        _report(goodSeconds: -1),
        _report(cameraSeconds: -1),
        _report(validSeconds: -1),
        _report(goodSeconds: 10, validSeconds: 5),
        _report(wpm: -1),
        _report(wpm: double.nan),
        _report(wpm: double.infinity),
        _report(paceScore: 94),
        _report(fillerScore: 100),
        _report(cameraScore: 82),
        _report(overallScore: 100),
        _report(cameraSeconds: 49),
        _report(postureScore: 0),
        _report(goodSeconds: 0),
      ]) {
        await expectLater(
          repository.savePerformanceReport(invalid),
          throwsA(isA<StorageException>()),
        );
      }
      expect(
        repository
            .getPerformanceReportBySessionId('nullable-session')!
            .wordsPerMinute,
        isNull,
      );
    },
  );
}
