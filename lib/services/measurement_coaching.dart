import 'filler_analysis.dart';
import 'speaking_pace.dart';

/// Deterministic advice from final measurements, not educational score formulas.
/// The thresholds are the existing prototype methodology, not expert validation.
class MeasurementCoaching {
  static List<String> generate({
    required SpeakingPace pace,
    required FillerAnalysis fillers,
    int? posturePercentage,
    int? validPostureSeconds,
    int? facingPercentage,
    int? validFaceMilliseconds,
    Map<String, int>? framingMilliseconds,
    bool monitorPace = true,
    bool monitorFillers = true,
    bool monitorPosture = true,
    bool monitorFacing = true,
    bool demo = false,
  }) {
    if (demo) {
      return const [
        'Example rehearsal: complete your own session to receive measured coaching.',
      ];
    }
    final tips = <String>[];
    if (monitorPace) {
      final wpm = pace.wordsPerMinute;
      tips.add(
        wpm == null
            ? 'Speaking pace: unavailable. A recognized final transcript and a positive rehearsal duration are needed.'
            : 'Speaking pace: ${wpm.toStringAsFixed(1)} WPM (${pace.classification}). ${wpm < 120
                  ? 'Try a steadier speaking rhythm. Practise one sentence at a time, keeping pauses between ideas.'
                  : wpm > 160
                  ? 'Slow down slightly and pause between key ideas so listeners can follow.'
                  : 'Your pace is in the 120–160 WPM target range. Keep this rhythm and use pauses between ideas.'}',
      );
    }
    if (monitorFillers) {
      if (!fillers.hasTranscript) {
        tips.add(
          'Filler words: unavailable because the final transcript has no recognized words. This does not mean no fillers were spoken.',
        );
      } else {
        final rate = fillers.perMinute;
        final matches = fillers.counts.entries.toList()
          ..sort((a, b) {
            final count = b.value.compareTo(a.value);
            return count == 0 ? a.key.compareTo(b.key) : count;
          });
        final common = matches
            .take(3)
            .map((entry) => '${entry.key} (${entry.value})')
            .join(', ');
        final advice = rate == null
            ? 'Frequency is unavailable without a positive rehearsal duration.'
            : rate < 2
            ? 'Few dictionary matches were found per minute. Keep using intentional pauses.'
            : rate < 6
            ? 'The frequency is low/acceptable under the current criteria. Try a short pause before your next idea.'
            : rate < 12
            ? 'The frequency is elevated. Rehearse short sections and replace unnecessary fillers with a calm pause.'
            : 'The frequency is high. Practise a short section slowly, pause to plan the next idea, then try it again.';
        tips.add(
          'Filler words: ${fillers.total} detected dictionary matches in the final transcript${rate == null ? '' : ', ${rate.toStringAsFixed(1)} per minute (${fillers.classification})'}. $advice${common.isEmpty ? '' : ' Most frequent expressions: $common.'} These words can be meaningful in context; review whether each use was unnecessary before treating it as a hesitation.',
        );
      }
    }
    if (monitorPosture) {
      tips.add(posture(posturePercentage, validPostureSeconds));
      tips.add(framing(framingMilliseconds));
    }
    if (monitorFacing) {
      final available =
          facingPercentage != null &&
          facingPercentage >= 0 &&
          facingPercentage <= 100 &&
          validFaceMilliseconds != null &&
          validFaceMilliseconds >= 3000;
      tips.add(
        !available
            ? 'Camera-facing attention: unavailable because valid face-analysis time is missing or insufficient. Missing faces are not poor performance.'
            : 'Estimated camera-facing attention: $facingPercentage% of ${(validFaceMilliseconds / 1000).toStringAsFixed(1)} valid analysis seconds. ${facingPercentage < 100 ? 'Some valid face samples showed your head turned away. Try facing the camera more consistently while speaking.' : 'Your head generally faced the camera in the valid measured samples. Keep this head position while speaking.'} This estimates head direction, not eye contact or audience engagement.',
      );
    }
    if (tips.isEmpty) {
      tips.add(
        'Monitoring was off for this rehearsal. No measurement-based performance recommendations are available.',
      );
    }
    return List.unmodifiable(tips);
  }

  static String posture(int? percentage, int? validSeconds) {
    if (percentage == null ||
        percentage < 0 ||
        percentage > 100 ||
        validSeconds == null ||
        validSeconds < 3) {
      return 'Upper-body posture: unavailable because valid pose-analysis time is missing or insufficient. Missing landmarks are not poor posture.';
    }
    return 'Upper-body posture: $percentage% acceptable during $validSeconds valid analysis seconds. ${percentage < 100 ? 'Some valid pose samples needed adjustment. Keep your shoulders level and your upper body upright without leaning to one side.' : 'Available pose samples generally met the current posture criteria. Keep your upper body steady and your shoulders relaxed.'} The posture criteria are provisional and need real-device calibration.';
  }

  static String framing(Map<String, int>? milliseconds) {
    if (milliseconds == null ||
        milliseconds.values.any((value) => value < 0) ||
        milliseconds.keys.any(
          (key) => !const {'tooClose', 'proper', 'tooFar'}.contains(key),
        ) ||
        milliseconds.values.fold(0, (sum, value) => sum + value) <= 0) {
      return 'Camera framing: unavailable. Keep your face and upper body in view; missing landmarks do not establish that you were too close or too far.';
    }
    final close = milliseconds['tooClose'] ?? 0;
    final far = milliseconds['tooFar'] ?? 0;
    final suggestions = <String>[];
    if (close > 0) {
      suggestions.add(
        'Too Close for ${(close / 1000).toStringAsFixed(1)} valid seconds: move farther from the camera',
      );
    }
    if (far > 0) {
      suggestions.add(
        'Too Far for ${(far / 1000).toStringAsFixed(1)} valid seconds: move closer to the camera',
      );
    }
    return suggestions.isEmpty
        ? 'Camera framing: Proper during the valid measured time. Keep this phone position so your face and upper body remain visible.'
        : 'Camera framing: ${suggestions.join('; ')}. Check the preview before your next rehearsal. This is positioning feedback, separate from head direction.';
  }
}
