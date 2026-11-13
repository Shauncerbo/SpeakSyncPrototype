import 'package:flutter/material.dart';

import '../core/app_theme.dart';

const _tutorialSteps = <_TutorialStep>[
  _TutorialStep(
    icon: Icons.mic_rounded,
    title: 'Start a rehearsal',
    message:
        'Tap the microphone button on Home to begin. You will complete Practice Setup, Device Check, and the camera preview before recording starts.',
  ),
  _TutorialStep(
    icon: Icons.description_outlined,
    title: 'Choose a speech type',
    message:
        'Prepared and Persuasive speeches can use a typed or uploaded reference script. Impromptu speech lets you rehearse without one.',
  ),
  _TutorialStep(
    icon: Icons.tune_rounded,
    title: 'Select monitoring',
    message:
        'Choose speaking pace, filler words, posture, and estimated camera-facing monitoring. Live speech feedback is optional and requires internet.',
  ),
  _TutorialStep(
    icon: Icons.insights_rounded,
    title: 'Review your progress',
    message:
        'End the rehearsal to review measured results and coaching. Save the report, then open Progress to revisit reports and topic attempts.',
  ),
];

/// Opens the reusable SpeakSync coach-mark tour.
///
/// Returns `true` after the student finishes or deliberately skips the tour.
Future<bool> showSpeakSyncTutorial(BuildContext context) async {
  final completed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'SpeakSync tutorial',
    barrierColor: const Color(0xC9000B1E),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _SpeakSyncTutorial(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: .96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return completed ?? false;
}

class _SpeakSyncTutorial extends StatefulWidget {
  const _SpeakSyncTutorial();

  @override
  State<_SpeakSyncTutorial> createState() => _SpeakSyncTutorialState();
}

class _SpeakSyncTutorialState extends State<_SpeakSyncTutorial> {
  int _stepIndex = 0;

  void _next() {
    if (_stepIndex == _tutorialSteps.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _stepIndex++);
  }

  void _back() {
    if (_stepIndex > 0) setState(() => _stepIndex--);
  }

  @override
  Widget build(BuildContext context) {
    final step = _tutorialSteps[_stepIndex];
    final compact = MediaQuery.sizeOf(context).height < 600;

    return PopScope(
      canPop: false,
      child: Material(
        key: const Key('speaksync_tutorial'),
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: compact ? 12 : 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55000000),
                        blurRadius: 30,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 20 : 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: primaryBlue,
                            ),
                            const SizedBox(width: 9),
                            const Expanded(
                              child: Text(
                                'SpeakSync Guide',
                                style: TextStyle(
                                  color: navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              '${_stepIndex + 1} of ${_tutorialSteps.length}',
                              key: const Key('tutorial_step_counter'),
                              style: const TextStyle(
                                color: Color(0xFF52647A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 18 : 28),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(.08, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Column(
                            key: ValueKey(_stepIndex),
                            children: [
                              TweenAnimationBuilder<double>(
                                key: ValueKey('tutorial_icon_$_stepIndex'),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutBack,
                                tween: Tween(begin: .82, end: 1),
                                builder: (context, scale, child) =>
                                    Transform.scale(scale: scale, child: child),
                                child: Container(
                                  width: compact ? 82 : 98,
                                  height: compact ? 82 : 98,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F5F2),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: primaryBlue.withValues(alpha: .3),
                                      width: 3,
                                    ),
                                  ),
                                  child: Icon(
                                    step.icon,
                                    size: compact ? 40 : 48,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 16 : 24),
                              Text(
                                step.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: navy,
                                  fontSize: compact ? 22 : 25,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                step.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF52647A),
                                  fontSize: 15,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _tutorialSteps.length,
                            (index) => AnimatedContainer(
                              key: Key('tutorial_indicator_$index'),
                              duration: const Duration(milliseconds: 180),
                              width: index == _stepIndex ? 24 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: index == _stepIndex
                                    ? primaryBlue
                                    : const Color(0xFFD4DEE9),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 24),
                        Row(
                          children: [
                            if (_stepIndex == 0)
                              TextButton(
                                key: const Key('dismiss_speaksync_tutorial'),
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Skip'),
                              )
                            else
                              TextButton.icon(
                                key: const Key('tutorial_back'),
                                onPressed: _back,
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Back'),
                              ),
                            const Spacer(),
                            FilledButton.icon(
                              key: const Key('tutorial_next'),
                              onPressed: _next,
                              icon: Icon(
                                _stepIndex == _tutorialSteps.length - 1
                                    ? Icons.check_rounded
                                    : Icons.arrow_forward_rounded,
                              ),
                              label: Text(
                                _stepIndex == _tutorialSteps.length - 1
                                    ? 'Finish'
                                    : 'Next',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _TutorialStep {
  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}
