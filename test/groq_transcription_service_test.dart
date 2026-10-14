import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    expect(requestBody, contains(GroqTranscriptionService.model));
    expect(requestBody, contains('name="file"'));
    expect(requestBody, contains('filename="rehearsal.m4a"'));
    expect(requestBody, isNot(contains('name="prompt"')));
  });

  test('sends the filler-aware prompt for the final transcription', () async {
    late http.BaseRequest sentRequest;
    final service = GroqTranscriptionService(
      apiKey: 'test-key',
      prompt: GroqTranscriptionService.fillerAwarePrompt,
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
    expect(requestBody, contains('fillers retained'));
    expect(requestBody, contains('kuan'));
    expect(requestBody, contains("mura'g"));
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

Future<http.Response> _fail(http.BaseRequest request) {
  fail('The HTTP client should not be called.');
}
