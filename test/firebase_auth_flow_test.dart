import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/app.dart';
import 'package:speaksync_prototype/auth_service.dart';
import 'package:speaksync_prototype/login.dart';
import 'package:speaksync_prototype/register.dart';
import 'package:speaksync_prototype/screens/authenticated_home.dart';
import 'package:speaksync_prototype/screens/email_verification_screen.dart';
import 'package:speaksync_prototype/services/internet_connectivity_service.dart';
import 'package:speaksync_prototype/state/app_state.dart';

import 'support/fake_auth_service.dart';

class _Online implements InternetConnectivity {
  @override
  Future<bool> check() async => true;

  @override
  Stream<bool> get statusChanges => const Stream.empty();
}

Widget _authHarness({
  required FakeAuthService auth,
  required AppState state,
  required Widget home,
}) {
  return AuthServiceScope(
    service: auth,
    child: AppStateScope(
      notifier: state,
      child: MaterialApp(
        home: home,
        routes: {
          '/home': (_) => const AuthenticatedHome(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
        },
      ),
    ),
  );
}

void main() {
  testWidgets(
    'registration stores the UID and sends a real verification step',
    (tester) async {
      final auth = FakeAuthService();
      final state = AppState(useDemoData: false);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        _authHarness(auth: auth, state: state, home: const RegisterScreen()),
      );

      await tester.enterText(
        find.byKey(const Key('register_first_name')),
        'Maria',
      );
      await tester.enterText(
        find.byKey(const Key('register_middle_name')),
        'Santos',
      );
      await tester.enterText(
        find.byKey(const Key('register_last_name')),
        'Cruz',
      );
      await tester.enterText(
        find.byKey(const Key('register_email')),
        'maria@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register_password')),
        'safePassword1',
      );
      await tester.enterText(
        find.byKey(const Key('register_confirm_password')),
        'safePassword1',
      );
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.text('Hello, Maria!'), findsNothing);
      expect(auth.registrationCalls, 1);
      expect(auth.verificationEmailCalls, 1);
      expect(state.activeUserId, 'new-user');
      expect(state.currentUserProfile?.firstName, 'Maria');
      expect(state.sessions, isEmpty);
    },
  );

  testWidgets(
    'unverified users cannot open dashboard until reload confirms it',
    (tester) async {
      final auth = FakeAuthService(
        currentUser: const AuthUser(
          uid: 'new-user',
          email: 'new.student@example.com',
          displayName: 'New Student',
          emailVerified: false,
        ),
      );
      final state = AppState(useDemoData: false);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        _authHarness(auth: auth, state: state, home: const AuthenticatedHome()),
      );

      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(find.textContaining('Hello,'), findsNothing);
      await tester.tap(find.byKey(const Key('check_email_verification')));
      await tester.pumpAndSettle();
      expect(find.textContaining('not verified yet'), findsOneWidget);

      auth.markCurrentUserVerified();
      await tester.tap(find.byKey(const Key('check_email_verification')));
      await tester.pumpAndSettle();

      expect(find.text('Hello, New!'), findsOneWidget);
      expect(state.activeUserId, 'new-user');
      expect(auth.reloadCalls, 2);
    },
  );

  testWidgets('verification screen resends email without opening dashboard', (
    tester,
  ) async {
    final auth = FakeAuthService(
      currentUser: const AuthUser(
        uid: 'new-user',
        email: 'new.student@example.com',
        displayName: 'New Student',
        emailVerified: false,
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      _authHarness(
        auth: auth,
        state: AppState(useDemoData: false),
        home: const EmailVerificationScreen(),
      ),
    );

    await tester.tap(find.byKey(const Key('resend_verification_email')));
    await tester.pumpAndSettle();
    expect(auth.verificationEmailCalls, 1);
    expect(
      find.textContaining('new verification email was sent'),
      findsOneWidget,
    );
    expect(find.textContaining('Hello,'), findsNothing);
  });

  testWidgets('password reset sends only the submitted email to Firebase', (
    tester,
  ) async {
    final auth = FakeAuthService();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      _authHarness(
        auth: auth,
        state: AppState(useDemoData: false),
        home: const LoginScreen(),
      ),
    );

    await tester.tap(find.byKey(const Key('forgot_password')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('password_reset_email')),
      'student@example.com',
    );
    await tester.tap(find.byKey(const Key('send_password_reset')));
    await tester.pumpAndSettle();

    expect(auth.passwordResetCalls, 1);
    expect(auth.lastResetEmail, 'student@example.com');
    expect(find.textContaining('password-reset instructions'), findsOneWidget);
  });

  testWidgets('invalid Firebase credentials remain on login with safe error', (
    tester,
  ) async {
    final auth = FakeAuthService(
      failure: const AuthFailure(
        'invalid-credential',
        'The email or password is incorrect.',
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      _authHarness(
        auth: auth,
        state: AppState(useDemoData: false),
        home: const LoginScreen(),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('login_email')),
      'student@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password')),
      'wrong-password',
    );
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
  });

  testWidgets(
    'verified persisted Firebase session skips onboarding and login',
    (tester) async {
      final auth = FakeAuthService(
        currentUser: const AuthUser(
          uid: 'returning-user',
          email: 'returning@example.com',
          displayName: 'Returning Student',
          emailVerified: true,
        ),
      );
      final state = AppState(useDemoData: false);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        SpeakSyncApp(
          appState: state,
          authService: auth,
          splashDuration: Duration.zero,
          internetConnectivity: _Online(),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Hello, Returning!'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Localized Speech Feedback'), findsNothing);
      expect(state.activeUserId, 'returning-user');
    },
  );

  testWidgets('logout clears local account state and returns to login', (
    tester,
  ) async {
    final auth = FakeAuthService(
      currentUser: const AuthUser(
        uid: 'logout-user',
        email: 'logout@example.com',
        displayName: 'Logout Student',
        emailVerified: true,
      ),
    );
    final state = AppState(useDemoData: false);
    await state.activateAuthenticatedUser(
      userId: 'logout-user',
      email: 'logout@example.com',
      displayName: 'Logout Student',
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      _authHarness(auth: auth, state: state, home: const AuthenticatedHome()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Log out'));
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(state.activeUserId, isNull);
    expect(state.sessions, isEmpty);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
