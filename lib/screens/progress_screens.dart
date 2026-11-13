import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/practice_session.dart';
import '../services/topic_attempt_tracking.dart';
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
    final topicGroups = TopicAttemptTracking.groupSessions(sessions);
    final chronologicalSessions = [...sessions]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final latestSession = chronologicalSessions.isEmpty
        ? null
        : chronologicalSessions.first;
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
                  const SectionHeader('Topics & attempts'),
                  const SizedBox(height: 6),
                  const Text(
                    'Repeated rehearsals are grouped by speech type and topic.',
                    style: TextStyle(color: Color(0xFF617085), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (topicGroups.isEmpty)
                    const InfoBanner(
                      icon: Icons.topic_outlined,
                      title: 'No practiced topics yet',
                      message: 'Saved rehearsal attempts will be grouped here.',
                    )
                  else
                    ...topicGroups.map(
                      (group) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TopicGroupCard(
                          group: group,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TopicAttemptsScreen(group: group),
                            ),
                          ),
                        ),
                      ),
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

    final tips = latest.measuredCoachingTips;
    return _ProgressInsightCard(
      title: 'Practice focus',
      message: tips.isEmpty
          ? 'No corrective coaching focus was generated from the available measurements.'
          : tips.first,
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

// Retained for the future validated cross-session scoring view.
// ignore: unused_element
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

class _TopicGroupCard extends StatelessWidget {
  const _TopicGroupCard({required this.group, required this.onTap});

  final TopicAttemptGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
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
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.topic_outlined, color: primaryBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.topic,
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
                      '${group.speechType} • ${group.attempts.length} ${group.attempts.length == 1 ? 'attempt' : 'attempts'}',
                      style: const TextStyle(
                        color: Color(0xFF617085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8B98AA)),
            ],
          ),
        ),
      ),
    );
  }
}

class TopicAttemptsScreen extends StatelessWidget {
  const TopicAttemptsScreen({super.key, required this.group});

  final TopicAttemptGroup group;

  @override
  Widget build(BuildContext context) {
    final bestAttempt = group.bestAttempt;
    final bestAttemptNumber = bestAttempt == null
        ? null
        : group.attemptNumberFor(bestAttempt.id);
    final comparisons = group.improvementComparisons;
    return Scaffold(
      appBar: AppBar(title: const Text('Topic Attempts')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: PageFrame(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Topic: ${group.topic}',
                  key: const Key('topic_attempts_title'),
                  style: const TextStyle(
                    color: navy,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${group.speechType} • ${group.attempts.length} completed ${group.attempts.length == 1 ? 'attempt' : 'attempts'}',
                  style: const TextStyle(color: Color(0xFF617085)),
                ),
                const SizedBox(height: 20),
                InfoBanner(
                  icon: group.rankingAvailable
                      ? Icons.emoji_events_outlined
                      : Icons.info_outline_rounded,
                  title: group.rankingAvailable
                      ? 'Best Attempt: Attempt $bestAttemptNumber'
                      : 'Ranking unavailable',
                  message: group.rankingAvailable
                      ? 'Highest validated Overall Performance Score: ${bestAttempt!.validatedOverallScore}.'
                      : 'Ranking unavailable until valid scores are available.',
                  color: group.rankingAvailable ? warningOrange : primaryBlue,
                ),
                const SizedBox(height: 26),
                const SectionHeader('Improvement'),
                const SizedBox(height: 10),
                if (group.attempts.length < 2)
                  const InfoBanner(
                    icon: Icons.insights_outlined,
                    title: 'Complete another attempt',
                    message:
                        'Comparable improvement appears after this topic is rehearsed again.',
                  )
                else if (comparisons.isEmpty)
                  const InfoBanner(
                    icon: Icons.insights_outlined,
                    title: 'Comparable measurements unavailable',
                    message:
                        'The first and latest attempts do not share enough measured data. Disabled monitors and unavailable analysis are not treated as zero.',
                  )
                else
                  ...comparisons.map(
                    (comparison) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TopicImprovementCard(comparison: comparison),
                    ),
                  ),
                const SizedBox(height: 18),
                const SectionHeader('Attempt history'),
                const SizedBox(height: 6),
                const Text(
                  'Attempt numbers follow chronological order, not ranking.',
                  style: TextStyle(color: Color(0xFF617085), fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...group.attempts.indexed.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TopicAttemptCard(
                      attemptNumber: entry.$1 + 1,
                      session: entry.$2,
                      isLatest: entry.$1 == group.attempts.length - 1,
                      isBest: bestAttempt?.id == entry.$2.id,
                      performanceRank: group.performanceRankFor(entry.$2.id),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SessionDetailsScreen(session: entry.$2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('practice_topic_again'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PracticeSetupScreen(
                        initialSession: group.latestAttempt,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Practice This Topic Again'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
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

class _TopicImprovementCard extends StatelessWidget {
  const _TopicImprovementCard({required this.comparison});

  final TopicMetricComparison comparison;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (comparison.trend) {
      TopicMetricTrend.improved => (Icons.trending_up_rounded, accentTeal),
      TopicMetricTrend.declined => (Icons.trending_down_rounded, warningOrange),
      TopicMetricTrend.unchanged => (Icons.trending_flat_rounded, primaryBlue),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comparison.label,
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${comparison.firstValue} → ${comparison.latestValue}',
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    comparison.summary,
                    style: const TextStyle(
                      color: Color(0xFF617085),
                      fontSize: 12,
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

class _TopicAttemptCard extends StatelessWidget {
  const _TopicAttemptCard({
    required this.attemptNumber,
    required this.session,
    required this.isLatest,
    required this.isBest,
    required this.performanceRank,
    required this.onTap,
  });

  final int attemptNumber;
  final PracticeSession session;
  final bool isLatest;
  final bool isBest;
  final int? performanceRank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pace = session.monitorPace
        ? session.speakingPace.wordsPerMinute
        : null;
    final fillerAnalysis = session.fillerAnalysis;
    final fillersAvailable =
        session.monitorFillers &&
        fillerAnalysis.hasTranscript &&
        fillerAnalysis.perMinute != null;
    return Card(
      key: Key('topic_attempt_$attemptNumber'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isBest
              ? warningOrange.withValues(alpha: .65)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Attempt $attemptNumber',
                      style: const TextStyle(
                        color: navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (isLatest) const _AttemptBadge(label: 'LATEST'),
                  if (isBest) ...[
                    const SizedBox(width: 6),
                    const _AttemptBadge(label: 'BEST ATTEMPT', best: true),
                  ],
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${formatDate(session.dateTime)} • ${formatDuration(session.duration)}${performanceRank == null ? '' : ' • Rank #$performanceRank'}',
                style: const TextStyle(color: Color(0xFF617085), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AttemptMetric(
                    label: 'Pace',
                    value: !session.monitorPace
                        ? 'Off'
                        : pace == null
                        ? 'Unavailable'
                        : '${pace.round()} WPM',
                  ),
                  _AttemptMetric(
                    label: 'Fillers',
                    value: !session.monitorFillers
                        ? 'Off'
                        : !fillersAvailable
                        ? 'Unavailable'
                        : '${fillerAnalysis.total} (${fillerAnalysis.perMinute!.toStringAsFixed(1)}/min)',
                  ),
                  _AttemptMetric(
                    label: 'Posture',
                    value: !session.monitorBodyLanguage
                        ? 'Off'
                        : session.measuredPosturePercentage == null
                        ? 'Unavailable'
                        : '${session.measuredPosturePercentage}%',
                  ),
                  _AttemptMetric(
                    label: 'Camera-facing',
                    value: !session.monitorCameraAttention
                        ? 'Off'
                        : session.measuredAttentionPercentage == null
                        ? 'Unavailable'
                        : '${session.measuredAttentionPercentage}%',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttemptBadge extends StatelessWidget {
  const _AttemptBadge({required this.label, this.best = false});

  final String label;
  final bool best;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: (best ? warningOrange : accentTeal).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: best ? const Color(0xFF9A5B00) : accentTeal,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _AttemptMetric extends StatelessWidget {
  const _AttemptMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 118),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F6FA),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF617085), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: navy,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
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
                if (session.measuredCoachingTips.isEmpty)
                  const InfoBanner(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'No corrective tips',
                    message:
                        'No corrective coaching tip was generated from the available measurements.',
                  )
                else
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
                  key: const Key('practice_topic_again_details'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PracticeSetupScreen(initialSession: session),
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Practice This Topic Again'),
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
