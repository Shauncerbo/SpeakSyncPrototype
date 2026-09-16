import 'dart:async';
import 'dart:io';

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
}
