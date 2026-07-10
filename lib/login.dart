import 'package:flutter/material.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Temporary development shortcut. Set this to false to restore the existing
  // email/password validation and mock account check below.
  bool get _bypassLoginForDevelopment => true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isPasswordHidden = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- TEMPORARY MOCK LOGIN LOGIC ---
  void _submitLogin() async {
    if (_bypassLoginForDevelopment) {
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Simulate a network request taking 2 seconds (makes the UI look realistic!)
    await Future.delayed(const Duration(seconds: 2));
    // HARDCODED CREDENTIALS: Change these to whatever you want to use for testing
    const String scriptedEmail = "student@speaksync.com";
    const String scriptedPassword = "capstone123";

    if (mounted) {
      if (email == scriptedEmail && password == scriptedPassword) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        _showErrorSnackBar('Invalid credentials.');
      }
      setState(() => _isLoading = false);
    }
  }
  // ----------------------------------

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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                  const SizedBox(height: 48),

                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'SHS Email Address',
                      labelStyle: const TextStyle(color: Color(0xFF9EB1C7)),
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9EB1C7)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF294966)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF67E8F9)),
                      ),
                      filled: true,
                      fillColor: const Color(0x33000000),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email address.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isPasswordHidden,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Color(0xFF9EB1C7)),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9EB1C7)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF294966)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF67E8F9)),
                      ),
                      filled: true,
                      fillColor: const Color(0x33000000),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF9EB1C7),
                        ),
                        onPressed: () {
                          setState(() => _isPasswordHidden = !_isPasswordHidden);
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
                  const SizedBox(height: 32),

                  // Login Action Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF67E8F9),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                          )
                        : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : () {
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
    );
  }
}
