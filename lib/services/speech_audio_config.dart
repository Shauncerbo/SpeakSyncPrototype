import 'package:record/record.dart';

/// Speech-capture settings shared by rehearsal recording and the readiness
/// noise check. These settings deliberately avoid optional device DSP: OEM
/// implementations vary, and suppressing or gain-shaping quiet speech could
/// remove soft hesitation sounds used by SpeakSync's filler analysis.
abstract final class SpeechAudioConfig {
  static const sampleRate = 16000;
  static const channels = 1;
  static const bitsPerSample = 16;

  static const pcm16 = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: channels,
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
    audioInterruption: AudioInterruptionMode.pauseResume,
    androidConfig: AndroidRecordConfig(
      // Keep the current platform-default microphone routing. Selecting
      // voice-recognition or unprocessed sources without device calibration
      // could change gain/noise behavior and the established RMS readings.
      audioSource: AndroidAudioSource.defaultSource,
    ),
  );

  static const aac = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 128000,
    sampleRate: sampleRate,
    numChannels: channels,
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
    audioInterruption: AudioInterruptionMode.pauseResume,
    androidConfig: AndroidRecordConfig(
      audioSource: AndroidAudioSource.defaultSource,
    ),
  );
}
