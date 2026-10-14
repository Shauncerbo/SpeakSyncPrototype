import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/practice_session.dart';
import '../state/app_state.dart';
import '../widgets/common_widgets.dart';
import '../widgets/speaking_pace_card.dart';
import '../widgets/filler_frequency_card.dart';
import 'practice_flow.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final sessions = state.sessions;
    final rankedSessions =
        sessions
            .where((session) => session.validatedOverallScore != null)
            .toList()
          ..sort(
            (a, b) =>
                b.validatedOverallScore!.compareTo(a.validatedOverallScore!),
          );
    final chronologicalSessions = [...sessions]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final latestSession = chronologicalSessions.isEmpty
        ? null
        : chronologicalSessions.first;
    final previousSession = chronologicalSessions.length > 1
        ? chronologicalSessions[1]
        : null;
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
                  ResponsiveCardGrid(
                    columns: 3,
                    spacing: 10,
                    children: [
                      MetricCard(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Average score',
                        value: state.averageScore == null
                            ? 'Not scored'
                            : '${state.averageScore}',
                        color: successGreen,
                      ),
                      MetricCard(
                        icon: Icons.replay_rounded,
                        label: 'Total sessions',
                        value: '${sessions.length}',
                      ),
                      MetricCard(
                        icon: Icons.schedule_rounded,
                        label: 'Practice time',
                        value: '${state.totalPracticeTime.inMinutes}m',
                        color: accentTeal,
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
                  const SectionHeader('Rehearsal Ranking'),
                  const SizedBox(height: 6),
                  const Text(
                    'Rankings require a validated scoring policy.',
                    style: TextStyle(color: Color(0xFF617085), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (rankedSessions.isEmpty)
                    const InfoBanner(
                      icon: Icons.emoji_events_outlined,
                      title: 'Rankings unavailable',
                      message:
                          'Overall scoring is not implemented. View measured feedback in Session history.',
                    )
                  else
                    ...rankedSessions.indexed.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RankingCard(
                          rank: entry.$1 + 1,
                          session: entry.$2,
                          isBest: entry.$1 == 0,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SessionDetailsScreen(session: entry.$2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _ImprovementInsightCard(
                    latestSession: latestSession,
                    previousSession: previousSession,
                  ),
                  const SizedBox(height: 12),
                  _WeakestAreaCard(session: latestSession),
                  const SizedBox(height: 26),
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

class _ImprovementInsightCard extends StatelessWidget {
  const _ImprovementInsightCard({
    required this.latestSession,
    required this.previousSession,
  });

  final PracticeSession? latestSession;
  final PracticeSession? previousSession;

  @override
  Widget build(BuildContext context) {
    final latest = latestSession;
    final previous = previousSession;
    final difference =
        latest?.validatedOverallScore != null &&
            previous?.validatedOverallScore != null
        ? latest!.validatedOverallScore! - previous!.validatedOverallScore!
        : null;
    final isImprovement = difference != null && difference > 0;
    final color = difference == null || difference == 0
        ? primaryBlue
        : isImprovement
        ? accentTeal
        : warningOrange;
    final message = switch (difference) {
      null =>
        'Score improvement is unavailable until a validated scoring policy is implemented.',
      > 0 => 'You improved by +$difference points from your last rehearsal.',
      < 0 =>
        'Your score dropped by $difference points. Try reducing filler words next time.',
      _ => 'Your score stayed steady. Keep practicing to move it higher.',
    };

    return _ProgressInsightCard(
      title: 'Improvement Insight',
      message: message,
      icon: isImprovement
          ? Icons.trending_up_rounded
          : difference != null && difference < 0
          ? Icons.trending_down_rounded
          : Icons.insights_rounded,
      color: color,
    );
  }
}

class _WeakestAreaCard extends StatelessWidget {
  const _WeakestAreaCard({required this.session});

  final PracticeSession? session;

  @override
  Widget build(BuildContext context) {
    final latest = session;
    if (latest == null) {
      return const _ProgressInsightCard(
        title: 'Practice focus',
        message: 'Complete a rehearsal to receive a coaching focus.',
        icon: Icons.track_changes_rounded,
        color: accentTeal,
      );
    }

    return _ProgressInsightCard(
      title: 'Practice focus',
      message: latest.measuredCoachingTips.first,
      icon: Icons.track_changes_rounded,
      color: accentTeal,
    );
  }
}

class _ProgressInsightCard extends StatelessWidget {
  const _ProgressInsightCard({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF526277),
                      fontSize: 13,
                      height: 1.4,
                    ),
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

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.rank,
    required this.session,
    required this.isBest,
    required this.onTap,
  });

  final int rank;
  final PracticeSession session;
  final bool isBest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = isBest ? warningOrange : primaryBlue;
    return Card(
      margin: EdgeInsets.zero,
      elevation: isBest ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isBest
              ? warningOrange.withValues(alpha: .55)
              : const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlight.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: highlight,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBest) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: warningOrange.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'BEST REHEARSAL',
                          style: TextStyle(
                            color: Color(0xFF9A5B00),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatDate(session.dateTime)} • ${session.speechType}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF617085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    session.validatedOverallScore?.toString() ?? 'Not scored',
                    style: TextStyle(
                      color: highlight,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'SCORE',
                    style: TextStyle(
                      color: Color(0xFF7A8798),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF8B98AA),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SessionDetailsScreen extends StatelessWidget {
  const SessionDetailsScreen({super.key, required this.session});
  final PracticeSession session;

  @override
  Widget build(BuildContext context) {
    final fillerAnalysis = session.fillerAnalysis;
    final fillers = fillerAnalysis.counts.entries.where(
      (entry) => session.monitorFillers && entry.value > 0,
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
                      ScoreRing(
                        score: session.validatedOverallScore,
                        size: 140,
                      ),
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
                        '${session.speechType} • ${session.languageMode}${session.isDemoSession ? ' • Demo example, not student results' : ''}',
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
                const SectionHeader('Measured feedback'),
                const SizedBox(height: 12),
                SpeakingPaceCard(
                  pace: session.speakingPace,
                  enabled: session.monitorPace,
                ),
                FillerFrequencyCard(
                  analysis: fillerAnalysis,
                  enabled: session.monitorFillers,
                ),
                _DetailScore(
                  label: 'Acceptable posture time (prototype thresholds)',
                  value: session.measuredPosturePercentage,
                ),
                _DetailScore(
                  label: 'Estimated camera-facing time (not eye contact)',
                  value: session.measuredAttentionPercentage,
                ),
                const SizedBox(height: 14),
                const SectionHeader('Scoring availability'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Overall, pace, and filler scores are not validated. Available head-direction percentages use valid face-analysis time, not eye contact. WPM, fillers, posture, and head direction remain separate measurements.',
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const SectionHeader('Filler frequencies'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: fillers.isEmpty
                        ? Text(
                            !session.monitorFillers
                                ? 'Filler monitoring was off for this rehearsal.'
                                : fillerAnalysis.hasTranscript
                                ? 'No listed filler words were found in the transcript.'
                                : 'Filler detection requires a transcript.',
                          )
                        : Column(
                            children: fillers
                                .map(
                                  (entry) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: warningOrange.withValues(
                                        alpha: .1,
                                      ),
                                      foregroundColor: warningOrange,
                                      child: Text('${entry.value}'),
                                    ),
                                    title: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    trailing: Text(
                                      entry.value == 1
                                          ? '1 time'
                                          : '${entry.value} times',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ),
                if (session.textTranscript != null) ...[
                  const SizedBox(height: 26),
                  const SectionHeader('Text transcript'),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        session.textTranscript!,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          height: 1.5,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
                if (session.hasScriptComparison) ...[
                  const SizedBox(height: 26),
                  ScriptComparisonSummary(
                    documentName: session.referenceDocumentName,
                    result: session.scriptComparison!,
                  ),
                ],
                const SizedBox(height: 26),
                const SectionHeader('Upper-body feedback'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      session.postureCoachingRecommendation,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        height: 1.5,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const SectionHeader('Coaching tips'),
                const SizedBox(height: 12),
                ...session.measuredCoachingTips.map(
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
  const _DetailScore({required this.label, required this.value});
  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final color = value == null ? const Color(0xFF617085) : accentTeal;
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
                value == null ? 'Unavailable' : '$value%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: value == null ? 0 : value! / 100,
              minHeight: 8,
              color: color,
              backgroundColor: const Color(0xFFE4EAF2),
            ),
          ),
        ],
      ),
    );
  }
}
