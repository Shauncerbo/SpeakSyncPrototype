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
    final rankedSessions = [...sessions]
      ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
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
                  const SectionHeader('Rehearsal Ranking'),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap a rehearsal to view its full score and feedback.',
                    style: TextStyle(color: Color(0xFF617085), fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (rankedSessions.isEmpty)
                    const InfoBanner(
                      icon: Icons.emoji_events_outlined,
                      title: 'No rankings yet',
                      message: 'Complete a rehearsal to enter the ranking.',
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
    final difference = latest != null && previous != null
        ? latest.overallScore - previous.overallScore
        : null;
    final isImprovement = difference != null && difference > 0;
    final color = difference == null || difference == 0
        ? primaryBlue
        : isImprovement
        ? accentTeal
        : warningOrange;
    final message = switch (difference) {
      null => 'Complete two rehearsals to see how your score changes.',
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
        title: 'Weakest Area Summary',
        message: 'Complete a rehearsal to receive a coaching focus.',
        icon: Icons.track_changes_rounded,
        color: accentTeal,
      );
    }

    final areas = <({String label, int score, String coaching})>[
      (
        label: 'Filler words',
        score: latest.fillerScore,
        coaching: 'Replace filler words with a brief, confident pause.',
      ),
      (
        label: 'Posture',
        score: latest.postureScore,
        coaching: 'Keep your shoulders relaxed and your stance steady.',
      ),
      (
        label: 'Speaking pace',
        score: latest.paceScore,
        coaching: 'Slow down slightly and pause between key ideas.',
      ),
      (
        label: 'Camera-facing attention',
        score: latest.attentionScore,
        coaching: 'Try looking toward the camera more often.',
      ),
    ]..sort((a, b) => a.score.compareTo(b.score));
    final weakest = areas.first;

    return _ProgressInsightCard(
      title: 'Weakest Area Summary',
      message:
          'Main area to improve: ${weakest.label} (${weakest.score}). ${weakest.coaching}',
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
                    '${session.overallScore}',
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
      (entry) => entry.value > 0,
    );
    final strengths = <MapEntry<String, int>>[
      MapEntry('Pace', session.paceScore),
      MapEntry('Filler Control', session.fillerScore),
      MapEntry('Posture', session.postureScore),
      MapEntry('Camera Attention', session.attentionScore),
    ]..sort((a, b) => b.value.compareTo(a.value));
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
                        '${session.speechType} • ${session.languageMode}',
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
                SpeakingPaceCard(pace: session.speakingPace),
                FillerFrequencyCard(analysis: fillerAnalysis),
                _DetailScore(label: 'Posture', value: session.postureScore),
                _DetailScore(
                  label: 'Camera Attention',
                  value: session.attentionScore,
                ),
                const SizedBox(height: 14),
                const SectionHeader('What you did well'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: strengths
                          .take(2)
                          .map(
                            (strength) => Padding(
                              padding: EdgeInsets.only(
                                bottom: strength == strengths.first ? 14 : 0,
                              ),
                              child: _StrengthRow(
                                label: strength.key,
                                score: strength.value,
                              ),
                            ),
                          )
                          .toList(),
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
                            fillerAnalysis.hasTranscript
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
                if (session.referenceScript?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 26),
                  ScriptComparisonSummary(
                    documentName: session.referenceDocumentName,
                    omittedPortions: session.omittedScriptPortions,
                    addedPortions: session.addedTranscriptPortions,
                    differentlyDeliveredPortions:
                        session.differentlyDeliveredPortions,
                  ),
                ],
                const SizedBox(height: 26),
                const SectionHeader('Recommended posture'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      session.recommendedPosture,
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

class _StrengthRow extends StatelessWidget {
  const _StrengthRow({required this.label, required this.score});

  final String label;
  final int score;

  String get message => switch (label) {
    'Pace' => 'Your speaking rhythm was clear and easy to follow.',
    'Filler Control' => 'You kept distracting filler words under control.',
    'Posture' => 'You maintained confident and steady body language.',
    _ => 'You stayed engaged with the camera and your audience.',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: successGreen.withValues(alpha: .12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: successGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · $score/100',
                style: const TextStyle(
                  color: navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF526277),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailScore extends StatelessWidget {
  const _DetailScore({required this.label, required this.value});
  final String label;
  final int value;

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
        ],
      ),
    );
  }
}
