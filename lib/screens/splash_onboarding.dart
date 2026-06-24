import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../core/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer ??= Timer(AppTimingScope.of(context).splashDuration, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SpeakSyncLogo(size: 82, showName: false, light: true),
                const SizedBox(height: 24),
                const Text(
                  'SpeakSync',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Practice your speech. Improve your delivery.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .78),
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 44),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.translate_rounded,
      'Localized Speech Feedback',
      'Identify selected Filipino and Bisaya filler words, including “kuan” and “ano,” during your practice.',
      primaryBlue,
    ),
    (
      Icons.accessibility_new_rounded,
      'Body Language Awareness',
      'Build awareness of your posture and camera-facing attention while you rehearse.',
      accentTeal,
    ),
    (
      Icons.shield_outlined,
      'Private Rehearsal',
      'Practice in a focused space, then review a clear performance summary after your session.',
      navy,
    ),
  ];

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SpeakSyncLogo(size: 38),
                  TextButton(
                    key: const Key('onboarding_skip'),
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const Key('onboarding_pages'),
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) {
                  final item = _pages[index];
                  return PageFrame(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            color: item.$4.withValues(alpha: .09),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.$1, color: item.$4, size: 82),
                        ),
                        const SizedBox(height: 42),
                        Text(
                          item.$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: navy,
                                letterSpacing: -.7,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF617085),
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _page
                              ? primaryBlue
                              : const Color(0xFFC8D2DF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_page > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _controller.previousPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOut,
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                      if (_page > 0) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: Key(
                            _page == _pages.length - 1
                                ? 'get_started'
                                : 'onboarding_next',
                          ),
                          onPressed: _next,
                          child: Text(
                            _page == _pages.length - 1 ? 'Get Started' : 'Next',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
