import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/rehearsal_audio_recorder.dart';

void main() {
  test('Silence, quiet noise and invalid samples leave the meter still', () {
    for (final sample in [
      -160.0,
      -70.0,
      -50.0,
      double.negativeInfinity,
      double.infinity,
      double.nan,
    ]) {
      expect(RehearsalAudioRecorder.levelFromDecibels(sample), 0);
    }
  });

  test('Measured volume drives the meter and silence resets it', () {
    final samples = [-60.0, -40.0, -30.0, -10.0, 0.0, -60.0];
    expect(samples.map(RehearsalAudioRecorder.levelFromDecibels), [
      0,
      .25,
      .5,
      1,
      1,
      0,
    ]);
  });
}
