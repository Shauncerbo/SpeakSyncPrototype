import 'dart:typed_data';

class ScriptComparisonResult {
  const ScriptComparisonResult({
    required this.status,
    required this.totalReferenceWords,
    required this.matchedReferenceWords,
    this.matchedPortions = const [],
    this.omittedPortions = const [],
    this.addedPortions = const [],
    this.differentlyDeliveredPortions = const [],
  });
  final String status;
  final int totalReferenceWords;
  final int matchedReferenceWords;
  final List<String> matchedPortions;
  final List<String> omittedPortions;
  final List<String> addedPortions;
  final List<String> differentlyDeliveredPortions;
  bool get isAvailable => status == 'available';
  double? get coverage => isAvailable && totalReferenceWords > 0
      ? matchedReferenceWords / totalReferenceWords * 100
      : null;
  bool get hasDifferences =>
      omittedPortions.isNotEmpty ||
      addedPortions.isNotEmpty ||
      differentlyDeliveredPortions.isNotEmpty;
  String get unavailableReason => switch (status) {
    'emptyScript' => 'No readable reference script is available.',
    'emptyTranscript' =>
      'A speech transcript is needed to compare your script. The other rehearsal feedback is still available.',
    'tooLong' =>
      'These texts are too long to compare safely on this device. Try rehearsing a shorter section.',
    _ =>
      'Script comparison is unavailable. The other rehearsal feedback is still available.',
  };
}

/// Word-level, order-sensitive LCS. No semantic or content grading.
class ScriptComparisonService {
  const ScriptComparisonService();
  // Bound worst-case CPU and memory rather than silently truncating the script.
  static const maxComparisonCells = 8000000;
  static const maxTextCharacters = 120000;
  static bool supports(String speechType) =>
      speechType == 'Prepared' || speechType == 'Persuasive';
  static ScriptComparisonResult compareInput(Map<String, String?> input) =>
      const ScriptComparisonService().compare(
        referenceScript: input['reference'],
        transcript: input['transcript'],
      );

  ScriptComparisonResult compare({
    String? referenceScript,
    String? transcript,
  }) {
    try {
      return _compare(referenceScript ?? '', transcript ?? '');
    } catch (_) {
      return const ScriptComparisonResult(
        status: 'failed',
        totalReferenceWords: 0,
        matchedReferenceWords: 0,
      );
    }
  }

  ScriptComparisonResult _compare(String referenceText, String spokenText) {
    ScriptComparisonResult unavailable(String status, [int total = 0]) =>
        ScriptComparisonResult(
          status: status,
          totalReferenceWords: total,
          matchedReferenceWords: 0,
        );
    if (referenceText.length > maxTextCharacters ||
        spokenText.length > maxTextCharacters) {
      return unavailable('tooLong');
    }
    final word = RegExp(
      r"[\p{L}\p{N}][\p{L}\p{M}\p{N}]*(?:['’ʼ][\p{L}\p{N}][\p{L}\p{M}\p{N}]*)*",
      unicode: true,
    );
    final reference = word.allMatches(referenceText).toList();
    final spoken = word.allMatches(spokenText).toList();
    if (reference.isEmpty) return unavailable('emptyScript');
    if (spoken.isEmpty) return unavailable('emptyTranscript', reference.length);
    String normalized(RegExpMatch m) =>
        m.group(0)!.toLowerCase().replaceAll(RegExp('[’ʼ]'), "'");
    final a = reference.map(normalized).toList();
    final b = spoken.map(normalized).toList();
    var prefix = 0;
    while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < a.length - prefix &&
        suffix < b.length - prefix &&
        a[a.length - suffix - 1] == b[b.length - suffix - 1]) {
      suffix++;
    }
    final n = a.length - prefix - suffix;
    final m = b.length - prefix - suffix;
    if ((n + 1) * (m + 1) > maxComparisonCells) {
      return unavailable('tooLong', a.length);
    }
    final width = m + 1;
    final lcs = Uint32List((n + 1) * width);
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        final down = lcs[(i + 1) * width + j];
        final right = lcs[i * width + j + 1];
        lcs[i * width + j] = a[prefix + i] == b[prefix + j]
            ? 1 + lcs[(i + 1) * width + j + 1]
            : (down >= right ? down : right);
      }
    }
    final matches = <(int, int)>[for (var k = 0; k < prefix; k++) (k, k)];
    var i = 0;
    var j = 0;
    while (i < n && j < m) {
      if (a[prefix + i] == b[prefix + j]) {
        matches.add((prefix + i++, prefix + j++));
      } else if (lcs[(i + 1) * width + j] >= lcs[i * width + j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    for (var k = suffix; k > 0; k--) {
      matches.add((a.length - k, b.length - k));
    }
    String phrase(String text, List<RegExpMatch> tokens, int start, int end) =>
        start == end
        ? ''
        : text
              .substring(tokens[start].start, tokens[end - 1].end)
              .replaceAll(RegExp(r'\s+'), ' ');
    final omitted = <String>[];
    final added = <String>[];
    final replaced = <String>[];
    final matched = <String>[];
    var ai = 0;
    var bi = 0;
    var runStart = -1;
    for (final pair in [...matches, (a.length, b.length)]) {
      final (ar, br) = pair;
      final gap = ar > ai || br > bi;
      if ((gap || ar == a.length) && runStart >= 0) {
        matched.add(phrase(referenceText, reference, runStart, ai));
        runStart = -1;
      }
      if (gap) {
        final expected = phrase(referenceText, reference, ai, ar);
        final actual = phrase(spokenText, spoken, bi, br);
        if (expected.isNotEmpty && actual.isNotEmpty) {
          replaced.add('Expected: $expected\nSpoken: $actual');
        } else if (expected.isNotEmpty) {
          omitted.add(expected);
        } else if (actual.isNotEmpty) {
          added.add(actual);
        }
      }
      if (ar < a.length && runStart < 0) runStart = ar;
      ai = ar + 1;
      bi = br + 1;
    }
    return ScriptComparisonResult(
      status: 'available',
      totalReferenceWords: a.length,
      matchedReferenceWords: matches.length,
      matchedPortions: List.unmodifiable(matched),
      omittedPortions: List.unmodifiable(omitted),
      addedPortions: List.unmodifiable(added),
      differentlyDeliveredPortions: List.unmodifiable(replaced),
    );
  }
}
