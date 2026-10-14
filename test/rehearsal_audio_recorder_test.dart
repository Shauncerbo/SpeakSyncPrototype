import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:speaksync_prototype/services/rehearsal_audio_recorder.dart';

class _FakeRecorder implements AudioRecorder {
  final paths = <String>[];
  Completer<String?>? stopping;
  bool paused = false;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    paths.add(path);
    paused = false;
    await File(path).writeAsString('sample audio');
  }

  @override
  Future<void> pause() async => paused = true;

  @override
  Future<String?> stop() => stopping!.future;

  @override
  Future<void> cancel() async => fail('Restart must await stop, not cancel.');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StreamRecorder extends _FakeRecorder {
  final stream = StreamController<Uint8List>();

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    expect(config.encoder, AudioEncoder.pcm16bits);
    expect(config.sampleRate, 16000);
    return stream.stream;
  }

  @override
  Future<String?> stop() async {
    await stream.close();
    return null;
  }

  @override
  Future<void> dispose() async {}
}

class _StreamFailureRecorder extends _FakeRecorder {
  int stops = 0;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async =>
      throw StateError('PCM stream unavailable');

  @override
  Future<String?> stop() async {
    stops++;
    return paths.isEmpty ? null : paths.single;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  for (final muted in [false, true]) {
    test(
      'discard waits for shutdown before restarting (muted: $muted)',
      () async {
        final directory = await Directory.systemTemp.createTemp('restart_test');
        addTearDown(() => directory.delete(recursive: true));
        final native = _FakeRecorder();
        final recorder = RehearsalAudioRecorder(
          recorder: native,
          temporaryDirectory: () async => directory,
        );
        await recorder.start();
        final original = native.paths.single;
        if (muted) await recorder.pause();
        native.stopping = Completer<String?>();
        final restart = recorder.discard().then((_) => recorder.start());
        await Future<void>.delayed(Duration.zero);
        expect(native.paths, hasLength(1));
        expect(await File(original).exists(), isTrue);
        native.stopping!.complete(original);
        await restart;
        expect(await File(original).exists(), isFalse);
        expect(native.paths, hasLength(2));
        expect(native.paths.last, isNot(original));
        expect(recorder.hasStarted, isTrue);
        expect(native.paused, isFalse);
      },
    );
  }

  test('discard is safe before microphone recording starts', () async {
    final recorder = RehearsalAudioRecorder(recorder: _FakeRecorder());
    await recorder.discard();
    expect(recorder.hasStarted, isFalse);
  });

  test(
    'one capture produces non-overlapping chunks and a complete WAV',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'live-recorder-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final native = _StreamRecorder();
      final recorder = RehearsalAudioRecorder(
        recorder: native,
        temporaryDirectory: () async => directory,
      );
      expect(recorder.chunkDuration, const Duration(seconds: 10));
      final chunks = <Uint8List>[];
      final subscription = recorder.chunks.listen(chunks.add);
      await recorder.start(enableLiveChunks: true);
      final first = Uint8List(320000)..fillRange(0, 320000, 7);
      final tail = Uint8List(32000)..fillRange(0, 32000, 9);
      native.stream.add(first);
      native.stream.add(tail);
      await Future<void>.delayed(Duration.zero);
      expect(chunks, hasLength(1));
      expect(chunks.single, orderedEquals(first));
      final wavPath = await recorder.stop();
      expect(wavPath, endsWith('.wav'));
      final bytes = await File(wavPath!).readAsBytes();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 352000);
      expect(bytes.length, 352044);
      expect(bytes.sublist(44, 44 + first.length), orderedEquals(first));
      expect(bytes.sublist(44 + first.length), orderedEquals(tail));
      expect(
        directory.listSync().where((e) => e.path.endsWith('.pcm')),
        isEmpty,
      );
      await recorder.deleteTemporaryFile(wavPath);
      await subscription.cancel();
      await recorder.dispose();
    },
  );

  test('PCM stream failure keeps the full AAC recording path', () async {
    final directory = await Directory.systemTemp.createTemp('pcm-fallback-');
    addTearDown(() => directory.delete(recursive: true));
    final native = _StreamFailureRecorder();
    final recorder = RehearsalAudioRecorder(
      recorder: native,
      temporaryDirectory: () async => directory,
    );
    await recorder.start(enableLiveChunks: true);
    expect(recorder.hasStarted, isTrue);
    expect(native.paths.single, endsWith('.m4a'));
    expect(await recorder.stop(), native.paths.single);
    await recorder.deleteTemporaryFile(native.paths.single);
    await recorder.dispose();
  });

  test(
    'first live chunk includes samples before the screen subscribes',
    () async {
      final directory = await Directory.systemTemp.createTemp('early-pcm-');
      addTearDown(() => directory.delete(recursive: true));
      final native = _StreamRecorder();
      final recorder = RehearsalAudioRecorder(
        recorder: native,
        temporaryDirectory: () async => directory,
        chunkDuration: const Duration(seconds: 1),
      );
      await recorder.start(enableLiveChunks: true);
      final early = Uint8List(16000)..fillRange(0, 16000, 3);
      native.stream.add(early);
      await Future<void>.delayed(Duration.zero);
      final chunks = <Uint8List>[];
      final subscription = recorder.chunks.listen(chunks.add);
      final later = Uint8List(16000)..fillRange(0, 16000, 4);
      native.stream.add(later);
      await Future<void>.delayed(Duration.zero);
      expect(chunks, hasLength(1));
      expect(chunks.single.sublist(0, 16000), orderedEquals(early));
      expect(chunks.single.sublist(16000), orderedEquals(later));
      await recorder.deleteTemporaryFile(await recorder.stop());
      await subscription.cancel();
      await recorder.dispose();
    },
  );
}
