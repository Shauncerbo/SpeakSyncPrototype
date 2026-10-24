import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:speaksync_prototype/data/dummy_data.dart';
import 'package:speaksync_prototype/models/performance_report.dart';
import 'package:speaksync_prototype/models/practice_session.dart';
import 'package:speaksync_prototype/models/practice_settings.dart';
import 'package:speaksync_prototype/screens/progress_screens.dart';
import 'package:speaksync_prototype/services/script_comparison_service.dart';
import 'package:speaksync_prototype/storage/hive_repository.dart';
import 'package:speaksync_prototype/widgets/common_widgets.dart';

PracticeSession _session({
  String type = 'Prepared',
  String? transcript = 'We value communication today',
  String? documentName = 'speech.pdf',
  bool legacy = false,
}) {
  const script = 'We value effective clear communication today';
  final r = const ScriptComparisonService().compare(
    referenceScript: script,
    transcript: transcript,
  );
  return PracticeSession(
    id: 'comparison-test',
    title: 'Communication',
    speechType: type,
    languageMode: 'Mixed Language',
    dateTime: DateTime(2026, 9, 16),
    duration: const Duration(minutes: 1),
    overallScore: 82,
    paceScore: 90,
    fillerScore: 90,
    postureScore: 90,
    attentionScore: 82,
    fillerCounts: const {},
    coachingTips: const [],
    isPrototypeData: true,
    textTranscript: transcript,
    referenceScript: script,
    referenceDocumentName: documentName,
    totalScriptWords: legacy ? null : r.totalReferenceWords,
    matchedScriptWords: legacy ? null : r.matchedReferenceWords,
    scriptComparisonStatus: legacy ? null : r.status,
    omittedScriptPortions: r.omittedPortions,
    addedTranscriptPortions: r.addedPortions,
    differentlyDeliveredPortions: r.differentlyDeliveredPortions,
  );
}

class _LegacyReportReader implements BinaryReader {
  final _indexes = [22, for (var i = 0; i < 22; i++) i].iterator;
  final _values = <dynamic>[
    'report-old',
    'old',
    3,
    3.0,
    90,
    90,
    50,
    90,
    50,
    90,
    82,
    <String>[],
    'We speak today',
    DateTime(2026),
    <String, int>{},
    'Steady',
    true,
    'We speak today',
    'old.txt',
    <String>[],
    <String>[],
    <String>[],
  ].iterator;
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
  test('old Hive reports without new fields remain readable', () {
    final report = PerformanceReportAdapter().read(_LegacyReportReader());
    expect(report.scriptComparisonStatus, isNull);
    expect(report.totalScriptWords, isNull);
    expect(report.referenceScript, 'We speak today');
    expect(
      _session(legacy: true).scriptComparison!.coverage,
      closeTo(66.6667, .001),
    );
  });
  test(
    'Persuasive report survives Hive reopen without duplicate records',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'script-report-test',
      );
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      var repository = HiveRepository();
      await repository.initializeStorage(storagePath: directory.path);
      await repository.seedDemoDataOnce(
        sessions: [],
        preferences: initialPreferences,
      );
      final session = _session(type: 'Persuasive', documentName: null);
      const settings = PracticeSettings(
        speechTitle: 'Communication',
        speechContent: 'We value effective clear communication today',
        referenceDocumentName: 'speech.pdf',
        speechType: 'Persuasive',
        languageMode: 'Mixed Language',
        selectedDuration: '1 minute',
        monitorBodyLanguage: true,
        monitorCameraAttention: true,
        monitorFillers: true,
        monitorPace: true,
        enableLiveFeedback: true,
      );
      expect(
        await repository.saveCompletedRehearsal(
          practiceSession: session,
          settings: settings,
        ),
        true,
      );
      expect(
        await repository.saveCompletedRehearsal(
          practiceSession: session,
          settings: settings,
        ),
        false,
      );
      final report = repository.getPerformanceReportBySessionId(session.id)!;
      expect(report.totalScriptWords, 6);
      expect(report.matchedScriptWords, 4);
      expect(
        repository.getSpeechProfiles().single.speechContent,
        session.referenceScript,
      );
      await Hive.close();
      repository = HiveRepository();
      await repository.initializeStorage(storagePath: directory.path);
      final loaded = repository.getPracticeSessions().single;
      expect(loaded.scriptComparison!.coverage, closeTo(66.6667, .001));
      expect(loaded.scriptComparison!.omittedPortions, ['effective clear']);
      expect(loaded.referenceDocumentName, 'speech.pdf');
      expect(loaded.overallScore, isNull);
    },
  );
  testWidgets(
    'coverage and grouped wording appear in reopened Session Details',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SessionDetailsScreen(session: _session())),
      );
      await tester.ensureVisible(find.byKey(const Key('script_coverage')));
      await tester.pump();
      expect(find.text('Script Coverage: 66.7%'), findsOneWidget);
      expect(
        find.text('4 matched words / 6 total script words'),
        findsOneWidget,
      );
      expect(find.text('effective clear'), findsOneWidget);
      expect(find.text('Reference Script Comparison'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('typed script report does not claim a document was uploaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailsScreen(session: _session(documentName: null)),
      ),
    );
    await tester.ensureVisible(find.byType(ScriptComparisonSummary));
    await tester.pump();
    expect(
      find.text('Compared with your typed reference script.'),
      findsOneWidget,
    );
    expect(find.textContaining('uploaded reference script'), findsNothing);
  });
  testWidgets(
    'missing transcript explains unavailable comparison, not full match',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScriptComparisonSummary(
                documentName: 'speech.pdf',
                result: _session(transcript: null).scriptComparison!,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Script comparison unavailable'), findsOneWidget);
      expect(find.text('Script wording matched'), findsNothing);
      expect(find.byKey(const Key('script_coverage')), findsNothing);
    },
  );
  testWidgets('Impromptu suppresses comparison even with stale script data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SessionDetailsScreen(session: _session(type: 'Impromptu')),
      ),
    );
    expect(find.byType(ScriptComparisonSummary), findsNothing);
    expect(_session(type: 'Impromptu').scriptComparison, isNull);
  });
}
