import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:speaksync_prototype/services/filler_analysis.dart';
import 'package:speaksync_prototype/services/groq_transcription_service.dart';
import 'package:speaksync_prototype/services/live_filler_feedback_service.dart';
import 'package:speaksync_prototype/services/speaking_pace.dart';

class _Transcriber extends GroqTranscriptionService {
  _Transcriber() : super(apiKey: 'test-placeholder');
  final responses = <Future<String> Function()>[];
  final wordResponses = <List<GroqTranscribedWord>>[];
  final paths = <String>[];
  int active = 0;
  int maximumActive = 0;

  @override
  Future<String> transcribe(String audioPath) async {
    paths.add(audioPath);
    active++;
    if (active > maximumActive) maximumActive = active;
    try {
      final bytes = await File(audioPath).readAsBytes();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(bytes.length, greaterThan(44));
      return await responses.removeAt(0)();
    } finally {
      active--;
    }
  }

  @override
  Future<GroqTranscriptionResult> transcribeWithWordTimestamps(
    String audioPath,
  ) async => GroqTranscriptionResult(
    text: await transcribe(audioPath),
    words: wordResponses.isEmpty ? const [] : wordResponses.removeAt(0),
  );
}

void main() {
  late Directory directory;
  late _Transcriber transcriber;
  late List<String> alerts;
  late List<LivePaceUpdate> paceUpdates;
  late LiveFillerFeedbackService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('live-filler-test');
    transcriber = _Transcriber();
    alerts = [];
    paceUpdates = [];
    service = LiveFillerFeedbackService(
      transcriber: transcriber,
      onFiller: alerts.add,
      onPace: paceUpdates.add,
      temporaryDirectory: () async => directory,
    );
  });

  tearDown(() async {
    await service.stop();
    transcriber.dispose();
    expect(directory.listSync(), isEmpty);
    await directory.delete();
  });

  Uint8List audio([int value = 1]) => Uint8List.fromList([value, 0, value, 0]);
  Uint8List overlappedAudio() => Uint8List((10 * 32000) + (750 * 32));
  String words(int count) => List.filled(count, 'word').join(' ');

  test(
    'one Turbo HTTP transcript feeds mixed-language filler and pace',
    () async {
      var requests = 0;
      const mixed =
          'Good morning. Kuan, mahalaga ang practice para sa atong kaugmaon.';
      final httpTranscriber = GroqTranscriptionService.liveFeedback(
        apiKey: 'test-placeholder',
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/openai/v1/audio/transcriptions');
          expect(
            utf8.decode(request.bodyBytes, allowMalformed: true),
            contains('whisper-large-v3-turbo'),
          );
          return http.Response('{"text":"$mixed"}', 200);
        }),
      );
      final feedback = LiveFillerFeedbackService(
        transcriber: httpTranscriber,
        onFiller: alerts.add,
        onPace: paceUpdates.add,
        temporaryDirectory: () async => directory,
      );
      try {
        feedback.accept(audio());
        await _until(() => alerts.isNotEmpty && paceUpdates.isNotEmpty);
        expect(requests, 1);
        expect(alerts, ['kuan']);
        expect(
          paceUpdates.single.wordsPerMinute,
          SpeakingPace.fromTranscript(
            mixed,
            const Duration(seconds: 10),
          ).wordsPerMinute,
        );
      } finally {
        await feedback.stop();
        httpTranscriber.dispose();
      }
    },
  );

  for (final entry in <(int, String)>[
    (19, 'Slow'),
    (20, 'Target'),
    (27, 'Fast'),
  ]) {
    test('${entry.$2} live pace from a ten-second transcript', () async {
      transcriber.responses.add(() async => words(entry.$1));
      service.accept(audio());
      await _until(() => paceUpdates.isNotEmpty);
      expect(paceUpdates.single.classification, entry.$2);
      expect(service.chunkDuration, const Duration(seconds: 10));
      expect(paceUpdates.single.wordsPerMinute, entry.$1 * 6);
    });
  }

  test('partial filler alert uses normalized lexicon', () async {
    transcriber.responses.add(() async => 'I think, KWAN, we can begin.');
    service.accept(audio());
    await _until(() => alerts.isNotEmpty);
    expect(alerts, ['kuan']);
  });

  test(
    "Ku'an partial transcript produces a canonical live filler alert",
    () async {
      transcriber.responses.add(() async => 'Ku\u2019an, let us begin today.');
      service.accept(audio());
      await _until(() => alerts.isNotEmpty);
      expect(alerts, ['kuan']);
      expect(transcriber.paths, hasLength(1));
      expect(paceUpdates, hasLength(1));
    },
  );

  test('all localized fillers are detected from partial transcripts', () async {
    const transcripts = [
      'um, let us begin',
      'uhm, my next point',
      'ah, I remember',
      'ano, this example',
      'parang this idea',
      'kasi it matters',
      'kuan, the topic',
      'kanang one detail',
      'bitaw, that is all',
      "mura'g this works",
    ];
    transcriber.responses.addAll(
      transcripts.map(
        (transcript) =>
            () async => transcript,
      ),
    );
    for (var index = 0; index < transcripts.length; index++) {
      service.accept(audio(index + 1));
      await _until(() => alerts.length == index + 1);
    }
    expect(alerts, [
      'um',
      'uhm',
      'ah',
      'ano',
      'parang',
      'kasi',
      'kuan',
      'kanang',
      'bitaw',
      "mura'g",
    ]);
  });

  test('ordinary speech and empty transcription produce no alerts', () async {
    transcriber.responses.addAll([
      () async => 'Good morning everyone.',
      () async => '  ',
    ]);
    service.accept(audio());
    await _until(
      () => transcriber.paths.length == 1 && transcriber.active == 0,
    );
    service.accept(audio(2));
    await _until(
      () =>
          transcriber.paths.length == 2 &&
          transcriber.active == 0 &&
          directory.listSync().isEmpty,
    );
    expect(alerts, isEmpty);
    expect(paceUpdates, isEmpty);
  });

  test('empty and fewer-than-four-word chunks do not update pace', () async {
    transcriber.responses.addAll([() async => '', () async => words(3)]);
    service.accept(audio());
    await _until(
      () => transcriber.paths.length == 1 && transcriber.active == 0,
    );
    service.accept(audio(2));
    await _until(
      () => transcriber.paths.length == 2 && transcriber.active == 0,
    );
    expect(paceUpdates, isEmpty);
  });

  test('rolling average smooths the latest three valid chunks', () async {
    transcriber.responses.addAll([
      () async => words(10), // 60 WPM
      () async => words(30), // 180 WPM; average 120
      () async => words(30), // average 140
      () async => words(30), // latest three average 180
    ]);
    for (var index = 0; index < 4; index++) {
      service.accept(audio(index + 1));
      await _until(() => paceUpdates.length == index + 1);
    }
    expect(paceUpdates.map((update) => update.classification), [
      'Slow',
      'Target',
      'Target',
      'Fast',
    ]);
    expect(paceUpdates.last.validChunks, 3);
  });

  test('failed chunk keeps the previous valid live pace', () async {
    transcriber.responses.addAll([
      () async => words(20),
      () async => throw const TranscriptionException(
        TranscriptionFailureType.apiFailure,
        'Rate limit',
      ),
    ]);
    service.accept(audio());
    await _until(() => paceUpdates.length == 1);
    service.accept(audio(2));
    await _until(
      () =>
          transcriber.paths.length == 2 &&
          transcriber.active == 0 &&
          directory.listSync().isEmpty,
    );
    expect(paceUpdates, hasLength(1));
    expect(paceUpdates.single.classification, 'Target');
  });

  test('adjacent identical transcripts are not alerted twice', () async {
    transcriber.responses.addAll([() async => 'Ano!', () async => 'ANO!']);
    service.accept(audio());
    await _until(
      () => transcriber.paths.length == 1 && transcriber.active == 0,
    );
    service.accept(audio(2));
    await _until(
      () => transcriber.paths.length == 2 && transcriber.active == 0,
    );
    expect(alerts, ['ano']);
  });

  test(
    'fillers repeated only in overlapping transcript text alert once',
    () async {
      transcriber.responses.addAll([
        () async => 'Today we say ano',
        () async => 'say ano before starting',
        () async => 'before starting, kuan, continue',
      ]);
      for (var index = 0; index < 3; index++) {
        service.accept(audio(index + 1));
        await _until(
          () =>
              transcriber.paths.length == index + 1 && transcriber.active == 0,
        );
      }
      expect(alerts, ['ano', 'kuan']);
    },
  );

  test(
    'timestamped overlap is excluded from filler alerts and live WPM',
    () async {
      transcriber.responses.addAll([
        () async => 'Ano ${words(19)}',
        () async => 'ano ${words(20)}',
      ]);
      transcriber.wordResponses.addAll([
        [
          const GroqTranscribedWord(
            word: 'Ano',
            startSeconds: 0,
            endSeconds: 0.2,
          ),
          for (var index = 0; index < 19; index++)
            GroqTranscribedWord(
              word: 'word',
              startSeconds: 0.3 + (index * 0.4),
              endSeconds: 0.5 + (index * 0.4),
            ),
        ],
        [
          const GroqTranscribedWord(
            word: 'ano',
            startSeconds: 0.1,
            endSeconds: 0.3,
          ),
          for (var index = 0; index < 20; index++)
            GroqTranscribedWord(
              word: 'word',
              startSeconds: 0.9 + (index * 0.4),
              endSeconds: 1.1 + (index * 0.4),
            ),
        ],
      ]);

      service.accept(audio());
      await _until(() => paceUpdates.length == 1);
      service.accept(overlappedAudio());
      await _until(() => paceUpdates.length == 2);

      expect(alerts, ['ano']);
      expect(paceUpdates.last.wordsPerMinute, 120);
    },
  );

  test(
    'a natural repeated filler after overlap remains a new detection',
    () async {
      transcriber.responses.addAll([
        () async => 'Ano ${words(4)}',
        () async => 'ano ano ${words(4)}',
      ]);
      transcriber.wordResponses.addAll([
        [
          const GroqTranscribedWord(
            word: 'Ano',
            startSeconds: 9.4,
            endSeconds: 9.7,
          ),
          for (var index = 0; index < 4; index++)
            GroqTranscribedWord(
              word: 'word',
              startSeconds: index.toDouble(),
              endSeconds: index + 0.2,
            ),
        ],
        [
          const GroqTranscribedWord(
            word: 'ano',
            startSeconds: 0.1,
            endSeconds: 0.3,
          ),
          const GroqTranscribedWord(
            word: 'ano',
            startSeconds: 0.9,
            endSeconds: 1.1,
          ),
          for (var index = 0; index < 4; index++)
            GroqTranscribedWord(
              word: 'word',
              startSeconds: 1.3 + index,
              endSeconds: 1.5 + index,
            ),
        ],
      ]);

      service.accept(audio());
      await _until(() => alerts.length == 1);
      service.accept(overlappedAudio());
      await _until(() => alerts.length == 2);

      expect(alerts, ['ano', 'ano']);
    },
  );

  test('a word mostly after the overlap boundary is retained', () {
    final transcript = LiveFillerFeedbackService.transcriptAfterOverlap(const [
      GroqTranscribedWord(word: 'old', startSeconds: 0.1, endSeconds: 0.3),
      GroqTranscribedWord(word: 'kuan', startSeconds: 0.65, endSeconds: 0.95),
    ], const Duration(milliseconds: 750));

    expect(transcript, 'kuan');
  });

  test('a new service clears duplicate and rolling pace state', () async {
    final repeated = 'Ano ${words(11)}';
    transcriber.responses.addAll([
      () async => words(12),
      () async => '${words(12)} extra',
      () async => repeated,
      () async => repeated,
    ]);
    for (var index = 0; index < 3; index++) {
      service.accept(audio(index + 1));
      await _until(() => paceUpdates.length == index + 1);
    }
    expect(paceUpdates.last.validChunks, 3);
    expect(alerts, ['ano']);

    await service.stop();
    service = LiveFillerFeedbackService(
      transcriber: transcriber,
      onFiller: alerts.add,
      onPace: paceUpdates.add,
      temporaryDirectory: () async => directory,
    );
    service.accept(audio(4));
    await _until(() => paceUpdates.length == 4 && alerts.length == 2);
    expect(paceUpdates.last.validChunks, 1);
    expect(alerts, ['ano', 'ano']);
  });

  test(
    '429 rate limit skips chunk and the following chunk still works',
    () async {
      transcriber.responses.addAll([
        () async => throw const TranscriptionException(
          TranscriptionFailureType.apiFailure,
          'Groq request failed (429): rate limit.',
        ),
        () async => 'Ano, let us continue.',
      ]);
      service.accept(audio());
      await _until(
        () => transcriber.paths.length == 1 && transcriber.active == 0,
      );
      service.accept(audio(2));
      await _until(() => alerts.isNotEmpty);
      expect(alerts, ['ano']);
    },
  );

  test('one request at a time with bounded pending audio', () async {
    final gate = Completer<String>();
    transcriber.responses.addAll([() => gate.future, () async => 'Bitaw']);
    service.accept(audio());
    await _until(() => transcriber.active == 1);
    service.accept(audio(2));
    service.accept(audio(3)); // replaces older pending chunk
    expect(transcriber.paths, hasLength(1));
    gate.complete('Kuan');
    await _until(() => alerts.length == 2);
    expect(transcriber.maximumActive, 1);
    expect(alerts, ['kuan', 'bitaw']);
  });

  test('live results never contribute to final transcript analysis', () async {
    transcriber.responses.add(() async => 'Kuan ${words(26)}.');
    service.accept(audio());
    await _until(() => alerts.isNotEmpty && paceUpdates.isNotEmpty);
    final finalAnalysis = FillerAnalysis.fromTranscript(
      'Ano. Ano.',
      const Duration(seconds: 10),
    );
    final finalPace = SpeakingPace.fromTranscript(
      words(8),
      const Duration(minutes: 1),
    );
    expect(alerts, ['kuan']);
    expect(transcriber.paths, hasLength(1));
    expect(finalAnalysis.counts, {'ano': 2});
    expect(paceUpdates.single.classification, 'Fast');
    expect(finalPace.wordsPerMinute, 8);
    expect(finalPace.classification, 'Slow');
  });

  test('stop drops pending chunks and does not emit late alerts', () async {
    final gate = Completer<String>();
    transcriber.responses.add(() => gate.future);
    service.accept(audio());
    await _until(() => transcriber.active == 1);
    service.accept(audio(2));
    final stopped = service.stop();
    gate.complete('Kuan');
    await stopped;
    expect(alerts, isEmpty);
    expect(transcriber.paths, hasLength(1));
    service.accept(audio(3));
    expect(transcriber.paths, hasLength(1));
  });
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Timed out waiting for live transcription result');
}
