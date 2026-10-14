import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:speaksync_prototype/models/filler_word_log.dart';
import 'package:speaksync_prototype/services/filler_analysis.dart';
import 'package:speaksync_prototype/widgets/filler_frequency_card.dart';

class _LegacyLogReader implements BinaryReader {
  final _bytes = [5, 0, 1, 2, 3, 4].iterator;
  final _values = <dynamic>[
    'log-1',
    'session-1',
    'Kuan',
    2,
    [12, 25],
  ].iterator;
  @override
  int readByte() {
    _bytes.moveNext();
    return _bytes.current;
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
  FillerAnalysis analyze(String? text, [int seconds = 60]) =>
      FillerAnalysis.fromTranscript(text, Duration(seconds: seconds));

  test(
    'All requested expressions match separately with case and punctuation',
    () {
      final result = analyze(
        "UM, uhm! Ah; Ano parang kasi kuan kanang bitaw mura'g.",
      );
      expect(result.counts, {
        'um': 1,
        'uhm': 1,
        'ah': 1,
        'ano': 1,
        'parang': 1,
        'kasi': 1,
        'kuan': 1,
        'kanang': 1,
        'bitaw': 1,
        "mura'g": 1,
      });
      expect(result.total, 10);
      expect(result.perMinute, 10);
      expect(result.classification, 'Elevated');
    },
  );

  test('Practical spellings group once under their canonical filler', () {
    final result = analyze("umm uhmm ahhh kwan Kuan murag mura’g mura'g");
    expect(result.counts, {'um': 1, 'uhm': 1, 'ah': 1, 'kuan': 2, "mura'g": 3});
    expect(result.total, 8);
    expect(result.offsets['kuan'], [14, 19]);
  });

  test("Ku'an spellings group under the canonical kuan filler", () {
    final result = analyze("Ku'an, kuan! Ku\u2019an; KU\u2018AN kwan.");
    expect(result.counts, {'kuan': 5});
    expect(result.total, 5);
    expect(result.offsets['kuan'], [0, 7, 13, 20, 26]);
    expect(result.perMinute, 5);
    expect(result.classification, 'Low / Acceptable');
  });

  test("Ku'an matching does not count fragments or unrelated apostrophes", () {
    final result = analyze("ku'anan aku'an ku'ang shouldn't 'ku'an'");
    expect(result.counts, {'kuan': 1});
    expect(result.total, 1);
    expect(result.offsets['kuan'], [33]);
  });

  test('Does not match fragments inside other words', () {
    final result = analyze('human umbrella piano kumusta kasama bitawan');
    expect(result.total, 0);
    expect(result.perMinute, 0);
    expect(result.classification, 'Very Low');
  });

  test('Uses actual minutes and continuous rate boundaries', () {
    for (final entry in {
      0: 'Very Low',
      1: 'Very Low',
      2: 'Low / Acceptable',
      5: 'Low / Acceptable',
      6: 'Elevated',
      11: 'Elevated',
      12: 'High',
    }.entries) {
      final text = 'Hello ${List.filled(entry.key, 'kuan').join(' ')}';
      expect(analyze(text).classification, entry.value);
    }
    expect(analyze('kuan kuan kuan', 120).perMinute, 1.5);
    expect(analyze('kuan kuan kuan', 120).classification, 'Very Low');
    expect(
      analyze(List.filled(11, 'kuan').join(' '), 120).classification,
      'Low / Acceptable',
    );
    expect(
      analyze(List.filled(23, 'kuan').join(' '), 120).classification,
      'Elevated',
    );
  });

  test(
    'Missing text differs from no matches and duration cannot divide by zero',
    () {
      for (final text in [null, '', ' \n ', '...!!!']) {
        expect(analyze(text).counts, isEmpty);
        expect(analyze(text).perMinute, isNull);
        expect(analyze(text).classification, 'Not available');
      }
      expect(analyze('kuan', 0).total, 1);
      expect(analyze('kuan', 0).perMinute, isNull);
      expect(analyze('kuan', -1).perMinute, isNull);
    },
  );

  test('Existing Hive logs without transcript offsets remain readable', () {
    final log = FillerWordLogAdapter().read(_LegacyLogReader());
    expect(log.occurrenceCount, 2);
    expect(log.detectedTimes, [12, 25]);
    expect(log.transcriptOffsets, isEmpty);
  });

  testWidgets(
    'Displays real total, frequency and interpretation without score',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FillerFrequencyCard(
              analysis: analyze('kuan kuan kanang', 120),
            ),
          ),
        ),
      );
      expect(find.text('3 total occurrences'), findsOneWidget);
      expect(find.text('1.5'), findsOneWidget);
      expect(find.text('fillers/min'), findsOneWidget);
      expect(find.text('Very Low'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FillerFrequencyCard(analysis: analyze(null))),
        ),
      );
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Very Low'), findsNothing);
    },
  );
}
