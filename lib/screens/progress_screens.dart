import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/practice_session.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import 'practice_flow.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final sessions = state.sessions;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SpeakSyncLogo(size: 40),
                  const SizedBox(height: 28),
                  const Text(
                    'Your progress',
                    style: TextStyle(
                      color: navy,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Small improvements become confident habits.',
                    style: TextStyle(color: Color(0xFF617085), fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          icon: Icons.workspace_premium_outlined,
                          label: 'Average score',
                          value: sessions.isEmpty
                              ? '—'
                              : '${state.averageScore}',
                          color: successGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricCard(
                          icon: Icons.replay_rounded,
                          label: 'Total sessions',
                          value: '${sessions.length}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricCard(
                          icon: Icons.schedule_rounded,
                          label: 'Practice time',
                          value: '${state.totalPracticeTime.inMinutes}m',
                          color: accentTeal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const SectionHeader('Performance trend'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                      child: sessions.isEmpty
                          ? const SizedBox(
                              height: 160,
                              child: Center(
                                child: Text(
                                  'Complete a session to build your chart.',
                                ),
                              ),
                            )
                          : ProgressChart(sessions: sessions),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SectionHeader('Session history'),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    const InfoBanner(
                      icon: Icons.mic_none_rounded,
                      title: 'No practice sessions yet',
                      message: 'Your saved rehearsal reports will appear here.',
                    )
                  else
                    ...sessions.map(
                      (session) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SessionCard(
                          session: session,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SessionDetailsScreen(session: session),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SessionDetailsScreen extends StatelessWidget {
  const SessionDetailsScreen({super.key, required this.session});
  final PracticeSession session;

  @override
  Widget build(BuildContext context) {
    final fillers = session.fillerCounts.entries.where(
      (entry) => entry.value > 0,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Session Details')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      ScoreRing(score: session.overallScore, size: 140),
                      const SizedBox(height: 18),
                      Text(
                        session.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatDate(session.dateTime)} • ${formatDuration(session.duration)}',
                        style: const TextStyle(color: Color(0xFF617085)),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        session.speechType,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: accentTeal,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                const SectionHeader('Score breakdown'),
                const SizedBox(height: 12),
                _DetailScore(label: 'Pace', value: session.paceScore),
                _DetailScore(
                  label: 'Filler Control',
                  value: session.fillerScore,
                ),
                _DetailScore(
                  label: 'Posture',
                  value: session.postureScore,
                  extra: StarRating(rating: (session.postureScore / 20).round()),
                ),
                _DetailScore(
                  label: 'Camera Attention',
                  value: session.attentionScore,
                  extra: StarRating(rating: (session.attentionScore / 20).round()),
                ),
                const SizedBox(height: 26),
                const SectionHeader('Speaking pace'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: PaceLineChart(paceHistory: session.paceHistory),
                  ),
                ),
                const SizedBox(height: 26),
                const SectionHeader('Filler frequencies'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: fillers.isEmpty
                        ? const Text('No selected filler words were detected.')
                        : FillerBarChart(fillerCounts: Map.fromEntries(fillers)),
                  ),
                ),
                const SizedBox(height: 26),
                const SectionHeader('Coaching tips'),
                const SizedBox(height: 12),
                ...session.coachingTips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InfoBanner(
                      icon: Icons.lightbulb_outline_rounded,
                      title: 'Focus point',
                      message: tip,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PracticeSetupScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Practice Again'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('Back to Progress'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailScore extends StatelessWidget {
  const _DetailScore({required this.label, required this.value, this.extra});
  final String label;
  final int value;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final color = value >= 80
        ? successGreen
        : value >= 70
        ? warningOrange
        : errorRed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$value/100',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 8,
              color: color,
              backgroundColor: const Color(0xFFE4EAF2),
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 8),
            extra!,
          ],
        ],
      ),
    );
  }
}
