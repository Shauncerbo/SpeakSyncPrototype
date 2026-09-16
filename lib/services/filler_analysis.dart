/// Dictionary matches in the existing transcript, not contextual speech AI.
class FillerAnalysis {
  FillerAnalysis._(this.hasTranscript, this.offsets, this.duration);

  factory FillerAnalysis.fromTranscript(String? transcript, Duration duration) {
    final normalized = (transcript ?? '')
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll('‘', "'");
    final tokens = RegExp(
      r"[\p{L}\p{N}]+(?:'[\p{L}\p{N}]+)*",
      unicode: true,
    ).allMatches(normalized).toList();
    final offsets = <String, List<int>>{};
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index].group(0)!;
      String? filler;
      if (RegExp(r'^um+$').hasMatch(token)) {
        filler = 'um';
      } else if (RegExp(r'^uh+m+$').hasMatch(token)) {
        filler = 'uhm';
      } else if (RegExp(r'^ah+$').hasMatch(token)) {
        filler = 'ah';
      } else if (token == 'kwan') {
        filler = 'kuan';
      } else if (token == 'murag' || token == "mura'g") {
        filler = "mura'g";
      } else if (const {
        'ano',
        'parang',
        'kasi',
        'kuan',
        'kanang',
        'bitaw',
      }.contains(token)) {
        filler = token;
      }
      if (filler != null) {
        offsets.putIfAbsent(filler, () => []).add(tokens[index].start);
      }
    }
    return FillerAnalysis._(
      tokens.isNotEmpty,
      Map.unmodifiable(
        offsets.map(
          (key, value) => MapEntry(key, List<int>.unmodifiable(value)),
        ),
      ),
      duration,
    );
  }

  final bool hasTranscript;

  /// Zero-based Dart string offsets in the normalized transcript.
  final Map<String, List<int>> offsets;
  final Duration duration;

  Map<String, int> get counts => Map.unmodifiable(
    offsets.map((word, positions) => MapEntry(word, positions.length)),
  );
  int get total =>
      offsets.values.fold(0, (sum, positions) => sum + positions.length);
  double? get perMinute => !hasTranscript || duration.inMicroseconds <= 0
      ? null
      : total / (duration.inMicroseconds / Duration.microsecondsPerMinute);
  String get classification {
    final rate = perMinute;
    if (rate == null) return 'Not available';
    // Continuous equivalents of the requested integer bands; do not round first.
    if (rate < 2) return 'Very Low';
    if (rate < 6) return 'Low / Acceptable';
    if (rate < 12) return 'Elevated';
    return 'High';
  }
}
