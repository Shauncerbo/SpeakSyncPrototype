import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/speaking_pace.dart';
import 'package:speaksync_prototype/widgets/speaking_pace_card.dart';

void main() {
  String words(int count) => List.filled(count, 'word').join(' ');

  test('Uses recognized words and actual duration in minutes', () {
    final pace = SpeakingPace.fromTranscript(
      words(210),
      const Duration(seconds: 90),
    );
    expect(pace.totalWords, 210);
    expect(pace.wordsPerMinute, 140);
    expect(pace.classification, 'Target / Effective');
  });

  test('Classifies the exact 120 and 160 WPM boundaries', () {
    for (final entry in {
      119: 'Slow',
      120: 'Target / Effective',
      160: 'Target / Effective',
      161: 'Fast',
    }.entries) {
      expect(
        SpeakingPace.fromTranscript(
          words(entry.key),
          const Duration(minutes: 1),
        ).classification,
        entry.value,
      );
    }
    expect(
      SpeakingPace.fromTranscript(
        words(160),
        const Duration(milliseconds: 59999),
      ).classification,
      'Fast',
    );
  });

  test('Counts multilingual words without counting punctuation', () {
    final pace = SpeakingPace.fromTranscript(
      "Hello,\n  mundo! — … Kuan, don't mura’g pag-ibig café 2026.",
      const Duration(minutes: 1),
    );
    expect(pace.totalWords, 8);
  });

  test('Missing transcript and nonpositive duration are unavailable', () {
    for (final transcript in [null, '', ' \n\t ', '... — !!!']) {
      final pace = SpeakingPace.fromTranscript(
        transcript,
        const Duration(minutes: 1),
      );
      expect(pace.totalWords, 0);
      expect(pace.wordsPerMinute, isNull);
      expect(pace.classification, 'Not available');
    }
    for (final duration in [Duration.zero, const Duration(seconds: -1)]) {
      final pace = SpeakingPace.fromTranscript('Hello world', duration);
      expect(pace.totalWords, 2);
      expect(pace.wordsPerMinute, isNull);
      expect(pace.classification, 'Not available');
    }
  });

  testWidgets('Report displays WPM and classification, without a pace score', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeakingPaceCard(
            pace: SpeakingPace.fromTranscript(
              words(210),
              const Duration(seconds: 90),
            ),
          ),
        ),
      ),
    );
    expect(find.text('140.0'), findsOneWidget);
    expect(find.text('WPM'), findsOneWidget);
    expect(find.text('Target / Effective'), findsOneWidget);
    expect(find.text('210 recognized words'), findsOneWidget);
    expect(find.textContaining('/100'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeakingPaceCard(
            pace: SpeakingPace.fromTranscript(null, Duration.zero),
          ),
        ),
      ),
    );
    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('Slow'), findsNothing);
  });
}
