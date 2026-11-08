import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../core/app_theme.dart';
import '../login.dart';
import '../state/app_state.dart';
import 'email_verification_screen.dart';
import 'main_shell.dart';

class AuthenticatedHome extends StatefulWidget {
  const AuthenticatedHome({super.key});

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  String? _activatingUserId;
  Future<void>? _activation;

  void _prepareActivation(AuthUser user) {
    final state = AppStateScope.of(context, listen: false);
    if (_activatingUserId == user.uid && _activation != null) return;
    if (state.activeUserId == user.uid && !state.isLoading) {
      _activatingUserId = user.uid;
      _activation = Future<void>.value();
      return;
    }
    _activatingUserId = user.uid;
    _activation = Future<void>.microtask(
      () => state.activateAuthenticatedUser(
        userId: user.uid,
        email: user.email,
        displayName: user.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthServiceScope.of(context);
    final user = auth.currentUser;
    if (user == null) {
      return LoginScreen(initialMessage: auth.unavailableMessage);
    }
    if (!user.emailVerified) {
      return const EmailVerificationScreen();
    }
    _prepareActivation(user);
    return FutureBuilder<void>(
      future: _activation,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storage_outlined,
                          size: 54,
                          color: errorRed,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Unable to open your local SpeakSync data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No other student records were loaded. Retry, or sign out and check the device storage.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => setState(() {
                            _activatingUserId = null;
                            _activation = null;
                          }),
                          child: const Text('Retry'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await auth.signOut();
                            } catch (_) {}
                            if (!context.mounted) return;
                            AppStateScope.of(
                              context,
                              listen: false,
                            ).clearAuthenticatedUser();
                            Navigator.of(context).pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          },
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return const MainShell();
      },
    );
  }
}
