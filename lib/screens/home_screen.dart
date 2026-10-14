import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/practice_session.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import 'practice_flow.dart';
import 'progress_screens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onViewProgress});
  final VoidCallback onViewProgress;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final sessions = [...state.sessions]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final latest = sessions.isEmpty ? null : sessions.first;
    final previous = sessions.length > 1 ? sessions[1] : null;
    final improvement =
        latest?.validatedOverallScore != null &&
            previous?.validatedOverallScore != null
        ? latest!.validatedOverallScore! - previous!.validatedOverallScore!
        : null;
    final latestWeekSessions = latest == null
        ? 0
        : sessions
              .where(
                (session) =>
                    latest.dateTime.difference(session.dateTime).inDays <= 6,
              )
              .length
              .clamp(0, 3);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: PageFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: SpeakSyncLogo(size: 42)),
                      IconButton.filledTonal(
                        tooltip: 'Notifications',
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('You’re all caught up.'),
                              ),
                            ),
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Hello, Speaker!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: navy,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ready to make your next delivery stronger?',
                    style: TextStyle(color: Color(0xFF617085), fontSize: 16),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [navy, Color(0xFF174A83)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.graphic_eq_rounded,
                          color: Color(0xFF67E8F9),
                          size: 34,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Your voice gets better\nwith every practice.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          key: const Key('start_practice'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: navy,
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PracticeSetupScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start Practice'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SectionHeader('Your snapshot'),
                  const SizedBox(height: 14),
                  ResponsiveCardGrid(
                    children: [
                      MetricCard(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Latest score',
                        value: 'Not scored',
                        color: successGreen,
                        onTap: latest == null
                            ? onViewProgress
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      SessionDetailsScreen(session: latest),
                                ),
                              ),
                      ),
                      MetricCard(
                        icon: Icons.replay_rounded,
                        label: 'Total sessions',
                        value: '${sessions.length}',
                        onTap: onViewProgress,
                      ),
                      MetricCard(
                        icon: Icons.schedule_rounded,
                        label: 'Practice time',
                        value: '${state.totalPracticeTime.inMinutes} min',
                        color: accentTeal,
                        onTap: onViewProgress,
                      ),
                      MetricCard(
                        icon: improvement == null
                            ? Icons.insights_rounded
                            : improvement >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        label: 'Latest improvement',
                        value: improvement == null
                            ? 'Unavailable'
                            : '${improvement >= 0 ? '+' : ''}$improvement pts',
                        color: improvement != null && improvement < 0
                            ? warningOrange
                            : successGreen,
                        onTap: onViewProgress,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _WeeklyGoalCard(
                    completed: latestWeekSessions,
                    onTap: () => _showWeeklyGoalInfo(context),
                  ),
                  const SizedBox(height: 28),
                  SectionHeader(
                    'Recent session',
                    trailing: TextButton(
                      onPressed: onViewProgress,
                      child: const Text('View Progress →'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (latest != null)
                    SessionCard(
                      session: latest,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SessionDetailsScreen(session: latest),
                        ),
                      ),
                    )
                  else
                    const InfoBanner(
                      icon: Icons.mic_none_rounded,
                      title: 'No sessions yet',
                      message: 'Start a practice session to see results here.',
                    ),
                  const SizedBox(height: 18),
                  InfoBanner(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Coaching tip',
                    message: _coachingTip(latest),
                    color: warningOrange,
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

String _coachingTip(PracticeSession? session) {
  if (session == null) {
    return 'Complete a rehearsal to receive a personalized coaching tip.';
  }
  return session.measuredCoachingTips.first;
}

void _showWeeklyGoalInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.flag_outlined, color: accentTeal),
      title: const Text('Weekly practice goal'),
      content: const Text(
        'Complete three rehearsals within a seven-day practice window. '
        'Each saved rehearsal adds to your progress and helps you build a consistent speaking habit.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({required this.completed, required this.onTap});

  final int completed;
  final VoidCallback onTap;
  static const int target = 3;

  @override
  Widget build(BuildContext context) {
    final progress = completed / target;
    return Material(
      color: accentTeal.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accentTeal.withValues(alpha: .24)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentTeal.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.flag_outlined,
                      color: accentTeal,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Weekly practice goal',
                      style: TextStyle(
                        color: navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '$completed/$target',
                    style: const TextStyle(
                      color: accentTeal,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.info_outline_rounded,
                    color: accentTeal,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  color: accentTeal,
                  backgroundColor: accentTeal.withValues(alpha: .13),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                completed >= target
                    ? 'Goal completed — keep your momentum going!'
                    : '${target - completed} more rehearsal${target - completed == 1 ? '' : 's'} to reach your goal.',
                style: const TextStyle(color: Color(0xFF617085), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
