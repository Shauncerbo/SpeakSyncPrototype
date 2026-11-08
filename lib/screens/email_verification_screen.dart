import 'package:flutter/material.dart';

import '../auth_service.dart';
import '../core/app_theme.dart';
import '../login.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    _messageIsError = widget.initialMessage != null;
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await AuthServiceScope.of(context).sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _message =
            'A new verification email was sent. Check your inbox and spam folder.';
        _messageIsError = false;
      });
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Unable to resend the verification email. Please try again.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkVerification() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final user = await AuthServiceScope.of(context).reloadCurrentUser();
      if (!mounted) return;
      if (user == null) {
        await _returnToLogin(
          'Your sign-in session ended. Please sign in again.',
        );
        return;
      }
      if (!user.emailVerified) {
        setState(() {
          _message =
              'Your email is not verified yet. Open the link in your email, then try again.';
          _messageIsError = true;
        });
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Unable to check verification right now. Please try again.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useAnotherAccount() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AuthServiceScope.of(context).signOut();
      if (!mounted) return;
      AppStateScope.of(context, listen: false).clearAuthenticatedUser();
      await _returnToLogin();
    } on AuthFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnToLogin([String? message]) async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(initialMessage: message),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthServiceScope.of(context).currentUser;
    final email = user?.email.trim();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF174A83)],
          ),
        ),
        child: SafeArea(
          child: ScrollableCenter(
            child: PageFrame(
              maxWidth: 540,
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 58,
                        color: primaryBlue,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Verify your email',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        email == null || email.isEmpty
                            ? 'Open the verification link sent by Firebase.'
                            : 'We sent a verification link to $email. Open it before accessing your rehearsal dashboard.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.45),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          key: const Key('verification_message'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (_messageIsError ? errorRed : successGreen)
                                .withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _messageIsError ? errorRed : successGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('check_email_verification'),
                          onPressed: _busy ? null : _checkVerification,
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text("I've Verified My Email"),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        key: const Key('resend_verification_email'),
                        onPressed: _busy ? null : _resend,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Resend Email'),
                      ),
                      TextButton(
                        key: const Key('verification_sign_out'),
                        onPressed: _busy ? null : _useAnotherAccount,
                        child: const Text('Use another account'),
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 10),
                        const CircularProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
