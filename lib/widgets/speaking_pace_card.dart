import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/speaking_pace.dart';

class SpeakingPaceCard extends StatelessWidget {
  const SpeakingPaceCard({super.key, required this.pace});

  final SpeakingPace pace;

  @override
  Widget build(BuildContext context) {
    final wpm = pace.wordsPerMinute;
    final color = wpm == null
        ? const Color(0xFF617085)
        : wpm >= 120 && wpm <= 160
        ? successGreen
        : warningOrange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.speed_rounded, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speaking Pace',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pace.classification,
                    style: TextStyle(color: color, fontSize: 13),
                  ),
                  Text(
                    wpm == null
                        ? pace.unavailableReason
                        : '${pace.totalWords} recognized words',
                    style: const TextStyle(
                      color: Color(0xFF617085),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  wpm?.toStringAsFixed(1) ?? '—',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text('WPM', style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
