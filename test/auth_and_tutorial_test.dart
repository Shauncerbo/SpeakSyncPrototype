import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/auth_service.dart';
import 'package:speaksync_prototype/register.dart';
import 'package:speaksync_prototype/screens/settings_screens.dart';
import 'package:speaksync_prototype/state/app_state.dart';

void main() {
  test(
    'email validation accepts normal addresses and rejects malformed input',
    () {
      expect(AuthService.isValidEmail('student@example.edu.ph'), isTrue);
      expect(AuthService.isValidEmail('student+speech@example.com'), isTrue);
      expect(AuthService.isValidEmail('student@example'), isFalse);
      expect(AuthService.isValidEmail('student @example.com'), isFalse);
      expect(AuthService.isValidEmail('@example.com'), isFalse);
    },
  );

  testWidgets('registration uses the Email Address label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('SHS Email Address'), findsNothing);
  });

  testWidgets('Help can reopen the dismissible SpeakSync tutorial', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppStateScope(
        notifier: AppState(),
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.ensureVisible(find.text('Help and Instructions'));
    await tester.tap(find.text('Help and Instructions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_speaksync_tutorial')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('speaksync_tutorial')), findsOneWidget);
    expect(find.text('Start a rehearsal'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial_next')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Choose a speech type'), findsOneWidget);
    expect(find.text('2 of 4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial_next')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Select monitoring'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial_next')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Review your progress'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tutorial_next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('speaksync_tutorial')), findsNothing);
  });

  testWidgets('tutorial can be deliberately skipped', (tester) async {
    await tester.pumpWidget(
      AppStateScope(
        notifier: AppState(),
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.ensureVisible(find.text('Help and Instructions'));
    await tester.tap(find.text('Help and Instructions'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_speaksync_tutorial')));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('dismiss_speaksync_tutorial')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('speaksync_tutorial')), findsNothing);
  });
}
