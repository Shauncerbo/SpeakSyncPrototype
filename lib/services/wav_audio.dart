import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'speech_audio_config.dart';

/// Mono, 16 kHz, signed 16-bit PCM. One sample source feeds the full rehearsal
/// file and each temporary live-transcription chunk.
class WavAudio {
  static const sampleRate = SpeechAudioConfig.sampleRate;
  static const channels = SpeechAudioConfig.channels;
  static const bitsPerSample = SpeechAudioConfig.bitsPerSample;
  static const bytesPerSample = bitsPerSample ~/ 8;
  static const blockAlign = channels * bytesPerSample;
  static const bytesPerSecond = sampleRate * blockAlign;
  static const maximumPcmBytes = 0xffffffff - 36;

  static Uint8List header(int pcmBytes) {
    validatePcmByteCount(pcmBytes);
    final data = ByteData(44);
    void word(int offset, int value) =>
        data.setUint32(offset, value, Endian.little);
    void half(int offset, int value) =>
        data.setUint16(offset, value, Endian.little);
    for (final entry in <(int, String)>[
      (0, 'RIFF'),
      (8, 'WAVE'),
      (12, 'fmt '),
      (36, 'data'),
    ]) {
      for (var i = 0; i < 4; i++) {
        data.setUint8(entry.$1 + i, entry.$2.codeUnitAt(i));
      }
    }
    word(4, 36 + pcmBytes);
    word(16, 16);
    half(20, 1);
    half(22, channels);
    word(24, sampleRate);
    word(28, bytesPerSecond);
    half(32, blockAlign);
    half(34, bitsPerSample);
    word(40, pcmBytes);
    return data.buffer.asUint8List();
  }

  static Future<void> writeChunk(String path, Uint8List pcm) async {
    validatePcmByteCount(pcm.length);
    final sink = File(path).openWrite();
    try {
      sink.add(header(pcm.length));
      sink.add(pcm);
    } finally {
      await sink.close();
    }
  }

  static Future<void> wrapPcmFile(
    String sourcePath,
    String wavPath,
    int pcmBytes,
  ) async {
    validatePcmByteCount(pcmBytes);
    final source = File(sourcePath);
    final actualBytes = await source.length();
    if (actualBytes != pcmBytes) {
      throw const FormatException(
        'PCM source length does not match the WAV data length.',
      );
    }
    final sink = File(wavPath).openWrite();
    try {
      sink.add(header(pcmBytes));
      await sink.addStream(source.openRead());
    } finally {
      await sink.close();
    }
  }

  static void validatePcmByteCount(int pcmBytes) {
    if (pcmBytes < 0 || pcmBytes > maximumPcmBytes) {
      throw RangeError.range(pcmBytes, 0, maximumPcmBytes, 'pcmBytes');
    }
    if (pcmBytes % blockAlign != 0) {
      throw const FormatException(
        'PCM data must contain complete 16-bit mono sample frames.',
      );
    }
  }
}

/// Aggregate signal diagnostics only; no samples or speech are retained.
/// Full-scale counts indicate possible digital clipping, but interpretation
/// still requires physical-device testing and does not alter recorded audio.
class Pcm16SignalAnalyzer {
  double _squaredSum = 0;
  int _peakMagnitude = 0;
  int _fullScaleSamples = 0;
  int _sampleCount = 0;

  void addBytes(Uint8List bytes) {
    WavAudio.validatePcmByteCount(bytes.length);
    final data = ByteData.sublistView(bytes);
    for (var offset = 0; offset < bytes.length; offset += 2) {
      final sample = data.getInt16(offset, Endian.little);
      final magnitude = sample == -32768 ? 32768 : sample.abs();
      _peakMagnitude = math.max(_peakMagnitude, magnitude);
      if (sample == -32768 || sample == 32767) _fullScaleSamples++;
      final normalized = sample / 32768;
      _squaredSum += normalized * normalized;
      _sampleCount++;
    }
  }

  Pcm16SignalSummary? get summary => _sampleCount == 0
      ? null
      : Pcm16SignalSummary(
          sampleCount: _sampleCount,
          rms: math.sqrt(_squaredSum / _sampleCount),
          peak: _peakMagnitude / 32768,
          fullScaleSampleCount: _fullScaleSamples,
        );
}

class Pcm16SignalSummary {
  const Pcm16SignalSummary({
    required this.sampleCount,
    required this.rms,
    required this.peak,
    required this.fullScaleSampleCount,
  });

  final int sampleCount;
  final double rms;
  final double peak;

  /// Counts exact PCM limits only. This detects possible digital clipping,
  /// not microphone or analog-stage distortion below full scale.
  final int fullScaleSampleCount;
}
