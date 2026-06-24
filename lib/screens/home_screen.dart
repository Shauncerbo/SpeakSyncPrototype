import 'package:flutter/material.dart';

import '../core/app_theme.dart';
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
    final latest = state.sessions.isEmpty ? null : state.sessions.first;
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
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.18,
                    children: const [
                      MetricCard(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Latest score',
                        value: '82/100',
                        color: successGreen,
                      ),
                      MetricCard(
                        icon: Icons.replay_rounded,
                        label: 'Total sessions',
                        value: '6',
                      ),
                      MetricCard(
                        icon: Icons.schedule_rounded,
                        label: 'Practice time',
                        value: '34 min',
                        color: accentTeal,
                      ),
                      MetricCard(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Most used filler',
                        value: 'Kuan',
                        color: warningOrange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SectionHeader(
                    'Recent session',
                    trailing: TextButton(
                      onPressed: onViewProgress,
                      child: const Text('View Progress'),
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
                  const InfoBanner(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Coaching tip',
                    message:
                        'A calm pause sounds more confident than a filler word. Give your ideas room to land.',
                    color: warningOrange,
                  ),
                  const SizedBox(height: 12),
                  const InfoBanner(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Your privacy matters',
                    message:
                        'This prototype never records or uploads real audio or video.',
                    color: accentTeal,
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
