import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/wav_audio.dart';

Uint8List _pcm16(List<int> samples) {
  final bytes = ByteData(samples.length * 2);
  for (var index = 0; index < samples.length; index++) {
    bytes.setInt16(index * 2, samples[index], Endian.little);
  }
  return bytes.buffer.asUint8List();
}

void main() {
  test('WAV metadata exactly describes mono 16 kHz PCM16', () {
    final header = ByteData.sublistView(WavAudio.header(64000));

    expect(String.fromCharCodes(header.buffer.asUint8List(0, 4)), 'RIFF');
    expect(header.getUint32(4, Endian.little), 64036);
    expect(String.fromCharCodes(header.buffer.asUint8List(8, 4)), 'WAVE');
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint32(28, Endian.little), 32000);
    expect(header.getUint16(32, Endian.little), 2);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), 64000);
  });

  test('WAV writer preserves signed little-endian samples exactly', () async {
    final directory = await Directory.systemTemp.createTemp('wav-integrity-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}sample.wav';
    final pcm = _pcm16([-32768, -1, 0, 1, 32767]);

    await WavAudio.writeChunk(path, pcm);

    final wav = await File(path).readAsBytes();
    expect(wav.length, 44 + pcm.length);
    expect(wav.sublist(44), pcm);
  });

  test('odd PCM byte counts are rejected before writing a WAV', () async {
    final directory = await Directory.systemTemp.createTemp('wav-odd-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}invalid.wav';

    await expectLater(
      WavAudio.writeChunk(path, Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
    expect(await File(path).exists(), isFalse);
  });

  test('wrapper rejects source and header length mismatch', () async {
    final directory = await Directory.systemTemp.createTemp('wav-length-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}${Platform.pathSeparator}source.pcm');
    final output = '${directory.path}${Platform.pathSeparator}output.wav';
    await source.writeAsBytes(_pcm16([1, 2]));

    await expectLater(
      WavAudio.wrapPcmFile(source.path, output, 2),
      throwsFormatException,
    );
    expect(await File(output).exists(), isFalse);
  });

  test('signal analyzer reports RMS, peak, and exact full-scale samples', () {
    final analyzer = Pcm16SignalAnalyzer()
      ..addBytes(_pcm16([-32768, -16384, 0, 16384, 32767]));
    final summary = analyzer.summary!;

    expect(summary.sampleCount, 5);
    expect(summary.peak, 1);
    expect(summary.fullScaleSampleCount, 2);
    final expected = math.sqrt(
      (1 + 0.25 + 0 + 0.25 + math.pow(32767 / 32768, 2)) / 5,
    );
    expect(summary.rms, closeTo(expected, 1e-12));
  });

  test('signal analyzer rejects incomplete sample data', () {
    expect(
      () => Pcm16SignalAnalyzer().addBytes(Uint8List.fromList([1])),
      throwsFormatException,
    );
  });
}
