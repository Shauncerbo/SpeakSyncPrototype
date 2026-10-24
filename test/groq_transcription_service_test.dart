import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:speaksync_prototype/services/filler_analysis.dart';
import 'package:speaksync_prototype/services/groq_transcription_service.dart';

void main() {
  late Directory temporaryDirectory;
  late File audioFile;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'speaksync-groq-test-',
    );
    audioFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}a.m4a',
    );
    await audioFile.writeAsBytes(const [1, 2, 3, 4]);
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('sends multipart audio and returns cleaned transcript text', () async {
    late http.BaseRequest sentRequest;
    final client = MockClient((request) async {
      sentRequest = request;
      return http.Response('{"text":"  Good morning everyone.  "}', 200);
    });
    final service = GroqTranscriptionService(
      apiKey: 'test-key',
      client: client,
    );

    final transcript = await service.transcribe(audioFile.path);

    expect(transcript, 'Good morning everyone.');
    expect(sentRequest.method, 'POST');
    expect(sentRequest.url, GroqTranscriptionService.endpoint);
    expect(sentRequest.headers['authorization'], 'Bearer test-key');
    expect(
      sentRequest.headers['content-type'],
      startsWith('multipart/form-data'),
    );
    final requestBody = utf8.decode((sentRequest as http.Request).bodyBytes);
    expect(requestBody, contains('name="model"'));
    expect(requestBody, contains(GroqWhisperModel.turbo.apiName));
    expect(requestBody, contains('name="file"'));
    expect(requestBody, contains('filename="rehearsal.m4a"'));
    expect(requestBody, isNot(contains('name="prompt"')));
  });

  test(
    'sends optional code-switching context for final transcription',
    () async {
      late http.BaseRequest sentRequest;
      final service = GroqTranscriptionService.finalRecording(
        apiKey: 'test-key',
        client: MockClient((request) async {
          sentRequest = request;
          return http.Response(
            '{"text":"Good morning. Um, kuan, ano, let us begin."}',
            200,
          );
        }),
      );

      final transcript = await service.transcribe(audioFile.path);
      final requestBody = utf8.decode((sentRequest as http.Request).bodyBytes);

      expect(transcript, contains('Um, kuan, ano'));
      expect(requestBody, contains('name="prompt"'));
      expect(requestBody, contains('Cebuano/Bisaya code-switched'));
      expect(requestBody, contains('not words to insert'));
      expect(requestBody, contains('kuan'));
      expect(requestBody, contains("mura'g"));
    },
  );

  for (final model in GroqWhisperModel.values) {
    for (final contextEnabled in [true, false]) {
      test(
        'final ${model.name}, context $contextEnabled: one transcription '
        'request at temperature zero with automatic language detection',
        () async {
          var requests = 0;
          late http.Request sent;
          final service = GroqTranscriptionService.finalRecording(
            apiKey: 'test-key',
            model: model,
            enableContextPrompt: contextEnabled,
            client: MockClient((request) async {
              requests++;
              sent = request;
              return http.Response('{"text":"Good morning."}', 200);
            }),
          );
          addTearDown(service.dispose);

          expect(await service.transcribe(audioFile.path), 'Good morning.');
          expect(requests, 1);
          expect(sent.url.path, '/openai/v1/audio/transcriptions');
          expect(_field(sent, 'model'), model.apiName);
          expect(_field(sent, 'temperature'), '0');
          expect(_field(sent, 'response_format'), 'json');
          expect(_field(sent, 'language'), isNull);
          expect(_field(sent, 'task'), isNull);
          expect(
            _field(sent, 'prompt'),
            contextEnabled
                ? GroqTranscriptionService.codeSwitchingContextPrompt
                : isNull,
          );
        },
      );
    }
  }

  test('live factory stays on Turbo with its existing short timeout', () async {
    late http.Request sent;
    final service = GroqTranscriptionService.liveFeedback(
      apiKey: 'test-key',
      client: MockClient((request) async {
        sent = request;
        return http.Response('{"text":"Good morning."}', 200);
      }),
    );
    addTearDown(service.dispose);
    expect(service.timeout, const Duration(seconds: 8));
    await service.transcribe(audioFile.path);
    expect(_field(sent, 'model'), 'whisper-large-v3-turbo');
    expect(_field(sent, 'temperature'), '0');
    expect(_field(sent, 'language'), isNull);
    expect(_field(sent, 'prompt'), isNotNull);
  });

  test('live timestamp mode uses one verbose response request', () async {
    var requests = 0;
    late http.Request sent;
    final service = GroqTranscriptionService.liveFeedback(
      apiKey: 'test-key',
      client: MockClient((request) async {
        requests++;
        sent = request;
        return http.Response(
          jsonEncode({
            'text': 'Ano, padayon ta.',
            'words': [
              {'word': 'Ano', 'start': 0.12, 'end': 0.42},
              {'word': 'padayon', 'start': 0.5, 'end': 0.9},
              {'word': 'ta', 'start': 0.92, 'end': 1.1},
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);

    final result = await service.transcribeWithWordTimestamps(audioFile.path);

    expect(requests, 1);
    expect(result.text, 'Ano, padayon ta.');
    expect(result.words.map((word) => word.word), ['Ano', 'padayon', 'ta']);
    expect(result.words.first.startSeconds, 0.12);
    expect(result.words.last.endSeconds, 1.1);
    expect(_field(sent, 'model'), 'whisper-large-v3-turbo');
    expect(_field(sent, 'response_format'), 'verbose_json');
    expect(_field(sent, 'timestamp_granularities[]'), 'word');
  });

  test('live context can be disabled without changing Turbo', () async {
    late http.Request sent;
    final service = GroqTranscriptionService.liveFeedback(
      apiKey: 'test-key',
      enableContextPrompt: false,
      client: MockClient((request) async {
        sent = request;
        return http.Response('{"text":"Good morning."}', 200);
      }),
    );
    addTearDown(service.dispose);
    await service.transcribe(audioFile.path);
    expect(_field(sent, 'prompt'), isNull);
    expect(_field(sent, 'model'), 'whisper-large-v3-turbo');
  });

  for (final model in GroqWhisperModel.values) {
    test(
      '${model.name} preserves returned mixed-language text verbatim',
      () async {
        const mixed =
            "Good morning. Ano, mahalaga ang practice. Ku'an, "
            "importante kini sa atong kaugmaon, mura'g bitaw.";
        final service = GroqTranscriptionService.finalRecording(
          apiKey: 'test-key',
          model: model,
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'text': '  $mixed  '}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        );
        addTearDown(service.dispose);
        final transcript = await service.transcribe(audioFile.path);
        expect(transcript, mixed);
        expect(
          FillerAnalysis.fromTranscript(
            transcript,
            const Duration(minutes: 1),
          ).counts,
          {'ano': 1, 'kuan': 1, "mura'g": 1, 'bitaw': 1},
        );
      },
    );
  }

  test(
    'context examples are never appended or counted as spoken words',
    () async {
      const spoken = 'Maayong buntag. Salamat sa inyong pagpaminaw.';
      final service = GroqTranscriptionService.finalRecording(
        apiKey: 'test-key',
        client: MockClient(
          (_) async => http.Response(jsonEncode({'text': spoken}), 200),
        ),
      );
      addTearDown(service.dispose);
      final transcript = await service.transcribe(audioFile.path);
      expect(transcript, spoken);
      expect(
        FillerAnalysis.fromTranscript(
          transcript,
          const Duration(minutes: 1),
        ).counts,
        isEmpty,
      );
    },
  );

  test('context does not turn an empty response into a transcript', () async {
    final service = GroqTranscriptionService.finalRecording(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response('{"text":"  "}', 200)),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.transcribe(audioFile.path),
      throwsA(
        isA<TranscriptionException>().having(
          (e) => e.type,
          'type',
          TranscriptionFailureType.emptyTranscript,
        ),
      ),
    );
  });

  test(
    'Large V3 failure does not send a hidden retry or Turbo comparison',
    () async {
      var requests = 0;
      final service = GroqTranscriptionService.finalRecording(
        apiKey: 'test-key',
        client: MockClient((_) async {
          requests++;
          return http.Response('{"error":{"message":"rate limited"}}', 429);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.transcribe(audioFile.path),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.type,
            'type',
            TranscriptionFailureType.apiFailure,
          ),
        ),
      );
      expect(requests, 1);
    },
  );

  test('API errors never echo provider bodies or credentials', () async {
    final service = GroqTranscriptionService.finalRecording(
      apiKey: 'test-key',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'test-key private student transcript'},
          }),
          400,
        ),
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.transcribe(audioFile.path),
      throwsA(
        isA<TranscriptionException>().having(
          (e) => e.message,
          'safe error',
          'Groq transcription failed with status 400.',
        ),
      ),
    );
  });

  test('uses the WAV filename for single-capture full recordings', () async {
    final wav = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}full.wav',
    );
    await wav.writeAsBytes(const [1, 2, 3, 4]);
    late http.BaseRequest sentRequest;
    final service = GroqTranscriptionService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        sentRequest = request;
        return http.Response('{"text":"Ano."}', 200);
      }),
    );
    expect(await service.transcribe(wav.path), 'Ano.');
    expect(
      utf8.decode((sentRequest as http.Request).bodyBytes),
      contains('filename="rehearsal.wav"'),
    );
  });

  test('reports a missing local API key without sending audio', () async {
    final service = GroqTranscriptionService(
      apiKey: '',
      client: MockClient(_fail),
    );

    await expectLater(
      service.transcribe(audioFile.path),
      throwsA(
        isA<TranscriptionException>().having(
          (error) => error.type,
          'type',
          TranscriptionFailureType.missingApiKey,
        ),
      ),
    );
  });

  test('reports an API failure without exposing credentials', () async {
    final service = GroqTranscriptionService(
      apiKey: 'test-key',
      client: MockClient(
        (_) async => http.Response(
          '{"error":{"message":"Audio request was rejected"}}',
          400,
        ),
      ),
    );

    await expectLater(
      service.transcribe(audioFile.path),
      throwsA(
        isA<TranscriptionException>()
            .having(
              (error) => error.type,
              'type',
              TranscriptionFailureType.apiFailure,
            )
            .having(
              (error) => error.message.contains('test-key'),
              'does not expose key',
              isFalse,
            ),
      ),
    );
  });
}

String? _field(http.Request request, String name) => RegExp(
  'name="${RegExp.escape(name)}"\r\n\r\n([^\r\n]*)',
).firstMatch(utf8.decode(request.bodyBytes))?.group(1);

Future<http.Response> _fail(http.BaseRequest request) {
  fail('The HTTP client should not be called.');
}
