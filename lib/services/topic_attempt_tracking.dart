import '../models/practice_session.dart';

enum TopicMetricTrend { improved, declined, unchanged }

class TopicMetricComparison {
  const TopicMetricComparison({
    required this.label,
    required this.firstValue,
    required this.latestValue,
    required this.summary,
    required this.trend,
  });

  final String label;
  final String firstValue;
  final String latestValue;
  final String summary;
  final TopicMetricTrend trend;
}

class TopicAttemptGroup {
  TopicAttemptGroup._({
    required this.key,
    required this.topic,
    required this.speechType,
    required List<PracticeSession> attempts,
  }) : attempts = List.unmodifiable(attempts);

  final String key;
  final String topic;
  final String speechType;

  /// Oldest to newest. Attempt numbers always use this order and never change
  /// when future performance ranking becomes available.
  final List<PracticeSession> attempts;

  PracticeSession get firstAttempt => attempts.first;
  PracticeSession get latestAttempt => attempts.last;

  int attemptNumberFor(String sessionId) {
    final index = attempts.indexWhere((attempt) => attempt.id == sessionId);
    return index < 0 ? 0 : index + 1;
  }

  /// Only explicitly validated, non-prototype Overall Scores are rankable.
  /// At present SpeakSync does not have a validated Overall Score policy, so
  /// this list correctly remains empty for current and legacy records.
  List<PracticeSession> get rankedAttempts {
    final ranked = attempts
        .where(
          (attempt) =>
              !attempt.isPrototypeData && attempt.validatedOverallScore != null,
        )
        .toList();
    ranked.sort((a, b) {
      final scoreOrder = b.validatedOverallScore!.compareTo(
        a.validatedOverallScore!,
      );
      if (scoreOrder != 0) return scoreOrder;
      // A deterministic tie break does not alter the score or attempt number.
      return b.dateTime.compareTo(a.dateTime);
    });
    return List.unmodifiable(ranked);
  }

  bool get rankingAvailable => rankedAttempts.isNotEmpty;
  PracticeSession? get bestAttempt =>
      rankingAvailable ? rankedAttempts.first : null;

  int? performanceRankFor(String sessionId) {
    final index = rankedAttempts.indexWhere(
      (attempt) => attempt.id == sessionId,
    );
    return index < 0 ? null : index + 1;
  }

  List<TopicMetricComparison> get improvementComparisons {
    if (attempts.length < 2) return const [];
    final first = firstAttempt;
    final latest = latestAttempt;
    final comparisons = <TopicMetricComparison>[];

    final firstWpm = _measuredWpm(first);
    final latestWpm = _measuredWpm(latest);
    if (firstWpm != null && latestWpm != null) {
      final firstDistance = _paceDistanceFromTarget(firstWpm);
      final latestDistance = _paceDistanceFromTarget(latestWpm);
      final distanceChange = firstDistance - latestDistance;
      final trend = _trendFromChange(distanceChange);
      final summary = switch (trend) {
        TopicMetricTrend.improved =>
          'Moved ${_number(distanceChange)} WPM closer to the 120–160 WPM target.',
        TopicMetricTrend.declined =>
          'Moved ${_number(distanceChange.abs())} WPM farther from the 120–160 WPM target.',
        TopicMetricTrend.unchanged
            when firstDistance == 0 && latestDistance == 0 =>
          'Both attempts are within the 120–160 WPM target.',
        TopicMetricTrend.unchanged =>
          'Distance from the 120–160 WPM target stayed the same.',
      };
      comparisons.add(
        TopicMetricComparison(
          label: 'Speaking pace',
          firstValue: '${_number(firstWpm)} WPM',
          latestValue: '${_number(latestWpm)} WPM',
          summary: summary,
          trend: trend,
        ),
      );
    }

    final firstFillers = _measuredFillersPerMinute(first);
    final latestFillers = _measuredFillersPerMinute(latest);
    if (firstFillers != null && latestFillers != null) {
      final improvement = firstFillers - latestFillers;
      final trend = _trendFromChange(improvement);
      comparisons.add(
        TopicMetricComparison(
          label: 'Filler frequency',
          firstValue: '${_number(firstFillers)} per min',
          latestValue: '${_number(latestFillers)} per min',
          summary: switch (trend) {
            TopicMetricTrend.improved =>
              '${_number(improvement)} fewer detected fillers per minute.',
            TopicMetricTrend.declined =>
              '${_number(improvement.abs())} more detected fillers per minute.',
            TopicMetricTrend.unchanged =>
              'Detected fillers per minute stayed the same.',
          },
          trend: trend,
        ),
      );
    }

    final firstPosture = first.measuredPosturePercentage;
    final latestPosture = latest.measuredPosturePercentage;
    if (firstPosture != null && latestPosture != null) {
      comparisons.add(
        _percentageComparison(
          label: 'Acceptable posture time',
          first: firstPosture,
          latest: latestPosture,
        ),
      );
    }

    final firstFacing = first.measuredAttentionPercentage;
    final latestFacing = latest.measuredAttentionPercentage;
    if (firstFacing != null && latestFacing != null) {
      comparisons.add(
        _percentageComparison(
          label: 'Estimated camera-facing time',
          first: firstFacing,
          latest: latestFacing,
        ),
      );
    }

    return List.unmodifiable(comparisons);
  }

  static TopicMetricComparison _percentageComparison({
    required String label,
    required int first,
    required int latest,
  }) {
    final change = latest - first;
    final trend = change > 0
        ? TopicMetricTrend.improved
        : change < 0
        ? TopicMetricTrend.declined
        : TopicMetricTrend.unchanged;
    return TopicMetricComparison(
      label: label,
      firstValue: '$first%',
      latestValue: '$latest%',
      summary: switch (trend) {
        TopicMetricTrend.improved => 'Increased by $change percentage points.',
        TopicMetricTrend.declined =>
          'Decreased by ${change.abs()} percentage points.',
        TopicMetricTrend.unchanged =>
          'The measured percentage stayed the same.',
      },
      trend: trend,
    );
  }

  static double? _measuredWpm(PracticeSession session) {
    if (session.isDemoSession ||
        !session.monitorPace ||
        session.textTranscript?.trim().isEmpty != false ||
        session.duration.inMicroseconds <= 0) {
      return null;
    }
    return session.speakingPace.wordsPerMinute;
  }

  static double? _measuredFillersPerMinute(PracticeSession session) {
    if (session.isDemoSession ||
        !session.monitorFillers ||
        session.textTranscript?.trim().isEmpty != false ||
        session.duration.inMicroseconds <= 0) {
      return null;
    }
    return session.fillerAnalysis.perMinute;
  }

  static double _paceDistanceFromTarget(double wpm) {
    if (wpm < 120) return 120 - wpm;
    if (wpm > 160) return wpm - 160;
    return 0;
  }

  static TopicMetricTrend _trendFromChange(double change) {
    if (change > .05) return TopicMetricTrend.improved;
    if (change < -.05) return TopicMetricTrend.declined;
    return TopicMetricTrend.unchanged;
  }

  static String _number(double value) {
    final rounded = value.roundToDouble();
    return value == rounded
        ? rounded.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class TopicAttemptTracking {
  const TopicAttemptTracking._();

  static List<TopicAttemptGroup> groupSessions(
    Iterable<PracticeSession> sessions,
  ) {
    final grouped = <String, List<PracticeSession>>{};
    for (final session in sessions) {
      final key = topicKey(session.title, session.speechType);
      grouped.putIfAbsent(key, () => []).add(session);
    }

    final groups = grouped.entries.map((entry) {
      final attempts = entry.value
        ..sort((a, b) {
          final dateOrder = a.dateTime.compareTo(b.dateTime);
          return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
        });
      final latest = attempts.last;
      return TopicAttemptGroup._(
        key: entry.key,
        topic: latest.title.trim(),
        speechType: latest.speechType,
        attempts: attempts,
      );
    }).toList();
    groups.sort(
      (a, b) => b.latestAttempt.dateTime.compareTo(a.latestAttempt.dateTime),
    );
    return List.unmodifiable(groups);
  }

  static TopicAttemptGroup? groupForSession(
    Iterable<PracticeSession> sessions,
    PracticeSession session,
  ) {
    final key = topicKey(session.title, session.speechType);
    for (final group in groupSessions(sessions)) {
      if (group.key == key) return group;
    }
    return null;
  }

  /// Existing Hive records already contain title and speech type. A normalized
  /// key therefore supports legacy data without a destructive schema change.
  static String topicKey(String topic, String speechType) {
    final normalizedTopic = topic
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'''[.,!?;:'"“”‘’()\[\]{}\-_\\/]+'''), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${speechType.trim().toLowerCase()}::${normalizedTopic.isEmpty ? 'untitled' : normalizedTopic}';
  }
}
