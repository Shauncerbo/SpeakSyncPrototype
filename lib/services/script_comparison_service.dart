class ScriptComparisonResult {
  const ScriptComparisonResult({
    required this.omittedPortions,
    required this.addedPortions,
    required this.differentlyDeliveredPortions,
  });

  final List<String> omittedPortions;
  final List<String> addedPortions;
  final List<String> differentlyDeliveredPortions;

  bool get hasDifferences =>
      omittedPortions.isNotEmpty ||
      addedPortions.isNotEmpty ||
      differentlyDeliveredPortions.isNotEmpty;
}

class ScriptComparisonService {
  const ScriptComparisonService();

  ScriptComparisonResult compare({
    required String referenceScript,
    required String transcript,
  }) {
    final reference = _segments(referenceScript);
    final delivered = _segments(transcript);
    final usedDelivered = <int>{};
    final omitted = <String>[];
    final changed = <String>[];

    for (final expected in reference) {
      var bestIndex = -1;
      var bestScore = 0.0;
      for (var index = 0; index < delivered.length; index++) {
        if (usedDelivered.contains(index)) continue;
        final score = _similarity(expected, delivered[index]);
        if (score > bestScore) {
          bestScore = score;
          bestIndex = index;
        }
      }

      if (bestIndex < 0 || bestScore < .38) {
        omitted.add(expected);
        continue;
      }

      usedDelivered.add(bestIndex);
      final actual = delivered[bestIndex];
      if (_normalize(expected) != _normalize(actual) && bestScore < .92) {
        changed.add('Reference: $expected\nDelivered: $actual');
      }
    }

    final added = <String>[
      for (var index = 0; index < delivered.length; index++)
        if (!usedDelivered.contains(index)) delivered[index],
    ];

    return ScriptComparisonResult(
      omittedPortions: List.unmodifiable(omitted),
      addedPortions: List.unmodifiable(added),
      differentlyDeliveredPortions: List.unmodifiable(changed),
    );
  }

  List<String> _segments(String value) => value
      .split(RegExp(r'(?<=[.!?])\s+|\n+'))
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();

  double _similarity(String left, String right) {
    final leftWords = _wordSet(left);
    final rightWords = _wordSet(right);
    if (leftWords.isEmpty && rightWords.isEmpty) return 1;
    if (leftWords.isEmpty || rightWords.isEmpty) return 0;
    final intersection = leftWords.intersection(rightWords).length;
    final union = leftWords.union(rightWords).length;
    return intersection / union;
  }

  Set<String> _wordSet(String value) =>
      _normalize(value).split(' ').where((word) => word.isNotEmpty).toSet();

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
