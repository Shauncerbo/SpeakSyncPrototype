import 'dart:io';
import 'dart:typed_data';

/// Mono, 16 kHz, signed 16-bit PCM. One sample source feeds the full rehearsal
/// file and each temporary live-transcription chunk.
class WavAudio {
  static const sampleRate = 16000;
  static const bytesPerSecond = sampleRate * 2;

  static Uint8List header(int pcmBytes) {
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
    half(22, 1);
    word(24, sampleRate);
    word(28, bytesPerSecond);
    half(32, 2);
    half(34, 16);
    word(40, pcmBytes);
    return data.buffer.asUint8List();
  }

  static Future<void> writeChunk(String path, Uint8List pcm) async {
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
    final sink = File(wavPath).openWrite();
    try {
      sink.add(header(pcmBytes));
      await sink.addStream(File(sourcePath).openRead());
    } finally {
      await sink.close();
    }
  }
}
