import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/filler_analysis.dart';

class FillerFrequencyCard extends StatelessWidget {
  const FillerFrequencyCard({super.key, required this.analysis});
  final FillerAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final rate = analysis.perMinute;
    final color = rate == null
        ? const Color(0xFF617085)
        : rate < 6
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
              child: Icon(Icons.chat_bubble_outline, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filler frequency',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    analysis.classification,
                    style: TextStyle(color: color, fontSize: 13),
                  ),
                  Text(
                    !analysis.hasTranscript
                        ? 'Transcript unavailable'
                        : '${analysis.total} total occurrences',
                    style: const TextStyle(
                      color: Color(0xFF617085),
                      fontSize: 12,
                    ),
                  ),
                  if (analysis.hasTranscript && rate == null)
                    const Text(
                      'Session duration unavailable',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  rate?.toStringAsFixed(1) ?? '—',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'fillers/min',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
