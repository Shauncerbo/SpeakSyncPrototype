import 'package:flutter/material.dart';

import '../core/app_theme.dart';

Future<void> showSpeakSyncTutorial(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('speaksync_tutorial'),
      scrollable: true,
      title: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: primaryBlue),
          SizedBox(width: 10),
          Expanded(child: Text('How to use SpeakSync')),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TutorialPoint(
            icon: Icons.play_circle_outline_rounded,
            title: 'Start a rehearsal',
            message:
                'From Home, tap Start Practice or the microphone button. Complete Practice Setup, Device Check, and the camera preview before pressing I\'m Ready.',
          ),
          _TutorialPoint(
            icon: Icons.description_outlined,
            title: 'Choose a speech type',
            message:
                'Prepared and Persuasive speeches use a typed or uploaded reference script. Impromptu speech does not require a script.',
          ),
          _TutorialPoint(
            icon: Icons.tune_rounded,
            title: 'Select monitoring',
            message:
                'Choose pace, filler words, posture, and estimated head direction. Live speech feedback is optional and requires internet.',
          ),
          _TutorialPoint(
            icon: Icons.assessment_outlined,
            title: 'Review your report',
            message:
                'End the rehearsal to review measured results and coaching. Save the report, then reopen it from Progress.',
          ),
        ],
      ),
      actions: [
        FilledButton(
          key: const Key('dismiss_speaksync_tutorial'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _TutorialPoint extends StatelessWidget {
  const _TutorialPoint({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryBlue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
