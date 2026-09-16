/// Transcript-based delivery rate. This does not calculate a 0–100 score.
class SpeakingPace {
  const SpeakingPace._(this.totalWords, this.wordsPerMinute);

  factory SpeakingPace.fromTranscript(String? transcript, Duration duration) {
    // Keep contractions and hyphenated Filipino/Bisaya words together.
    // Punctuation-only tokens are not recognized words.
    final words = RegExp(
      r"[\p{L}\p{N}][\p{L}\p{M}\p{N}]*(?:['’\-][\p{L}\p{N}][\p{L}\p{M}\p{N}]*)*",
      unicode: true,
    ).allMatches(transcript ?? '').length;
    final minutes = duration.inMicroseconds / Duration.microsecondsPerMinute;
    return SpeakingPace._(
      words,
      words == 0 || minutes <= 0 ? null : words / minutes,
    );
  }

  final int totalWords;
  final double? wordsPerMinute;

  String get classification {
    final wpm = wordsPerMinute;
    if (wpm == null) return 'Not available';
    if (wpm < 120) return 'Slow';
    if (wpm <= 160) return 'Target / Effective';
    return 'Fast';
  }

  String get unavailableReason => totalWords == 0
      ? 'No recognized transcript words.'
      : 'Session duration must be greater than zero.';
}
