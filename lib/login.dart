import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'core/app_theme.dart';
import 'screens/email_verification_screen.dart';
import 'widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordHidden = true;
  bool _isLoading = false;

  AuthService _auth(BuildContext context) =>
      AuthServiceScope.maybeOf(context) ?? const UnavailableAuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = await _auth(context).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (!user.emailVerified) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const EmailVerificationScreen(),
          ),
          (route) => false,
        );
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } on AuthFailure catch (error) {
      if (mounted) _showErrorSnackBar(error.message);
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar(
          'Unable to sign in right now. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    var resetEmail = _emailController.text;
    String? validationMessage;
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset password'),
          content: TextFormField(
            key: const Key('password_reset_email'),
            initialValue: resetEmail,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            onChanged: (value) => resetEmail = value,
            decoration: InputDecoration(
              labelText: 'Email Address',
              errorText: validationMessage,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('send_password_reset'),
              onPressed: () {
                final value = resetEmail.trim();
                if (!AuthService.isValidEmail(value)) {
                  setDialogState(
                    () => validationMessage =
                        'Please enter a valid email address.',
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(value);
              },
              child: const Text('Send Reset Email'),
            ),
          ],
        ),
      ),
    );
    if (email == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await _auth(context).sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for that email, Firebase sent password-reset instructions.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AuthFailure catch (error) {
      if (mounted) _showErrorSnackBar(error.message);
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar('Unable to request a password reset right now.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: Center(
            child: SingleChildScrollView(
              child: PageFrame(
                maxWidth: 560,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'SpeakSync',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to proceed with your rehearsal',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9EB1C7)),
                      ),
                      if (widget.initialMessage != null ||
                          !_auth(context).isAvailable) ...[
                        const SizedBox(height: 18),
                        Container(
                          key: const Key('authentication_unavailable'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: errorRed.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.initialMessage ??
                                _auth(context).unavailableMessage ??
                                'Firebase Authentication is unavailable.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                      const SizedBox(height: 48),

                      // Email Input
                      TextFormField(
                        key: const Key('login_email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: const TextStyle(color: Color(0xFF9EB1C7)),
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF9EB1C7),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF294966),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF67E8F9),
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0x33000000),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email address.';
                          }
                          if (!AuthService.isValidEmail(value)) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Input
                      TextFormField(
                        key: const Key('login_password'),
                        controller: _passwordController,
                        obscureText: _isPasswordHidden,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Color(0xFF9EB1C7)),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF9EB1C7),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF294966),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF67E8F9),
                            ),
                          ),
                          filled: true,
                          fillColor: const Color(0x33000000),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordHidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF9EB1C7),
                            ),
                            onPressed: () {
                              setState(
                                () => _isPasswordHidden = !_isPasswordHidden,
                              );
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password.';
                          }
                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('forgot_password'),
                          onPressed: _isLoading ? null : _resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login Action Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF67E8F9),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0F172A),
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).pushNamed('/register');
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF67E8F9),
                        ),
                        child: const Text('Create account'),
                      ),
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
