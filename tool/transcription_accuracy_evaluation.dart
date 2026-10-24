import 'dart:convert';
import 'dart:io';

import 'package:speaksync_prototype/services/groq_transcription_service.dart';
import 'package:speaksync_prototype/services/transcription_accuracy_evaluator.dart';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options.help) {
    stdout.write(_usage);
    return;
  }
  if (options.manifestPath == null) {
    stderr.writeln('Missing --manifest.');
    stderr.write(_usage);
    exitCode = 64;
    return;
  }
  if (options.runApi && !options.authorizePaidApi) {
    stderr.writeln(
      'API evaluation requires both --run-api and --authorize-paid-api.',
    );
    exitCode = 64;
    return;
  }

  final manifestFile = File(options.manifestPath!);
  if (!await manifestFile.exists()) {
    stderr.writeln('Manifest not found.');
    exitCode = 66;
    return;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(await manifestFile.readAsString());
  } on FormatException {
    stderr.writeln('Manifest is not valid JSON.');
    exitCode = 65;
    return;
  }
  if (decoded is! Map<String, dynamic> || decoded['recordings'] is! List) {
    stderr.writeln('Manifest must contain a recordings array.');
    exitCode = 65;
    return;
  }

  final apiKey = options.runApi
      ? (Platform.environment['GROQ_API_KEY'] ?? '').trim()
      : '';
  if (options.runApi && apiKey.isEmpty) {
    stderr.writeln('GROQ_API_KEY is not available in the process environment.');
    exitCode = 78;
    return;
  }

  final manifestDirectory = manifestFile.absolute.parent.path;
  final rows = <TranscriptionEvaluationRow>[];
  for (final rawRecording in decoded['recordings'] as List) {
    if (rawRecording is! Map) continue;
    final recording = Map<String, dynamic>.from(rawRecording);
    final recordingId = _text(recording['recordingId']);
    final referencePath = _text(recording['referenceTranscriptPath']);
    final audioPath = _text(recording['audioPath']);
    final rehearsalSeconds = _number(recording['rehearsalDurationSeconds']);
    if (recordingId == null ||
        referencePath == null ||
        rehearsalSeconds == null) {
      stderr.writeln('Skipped an invalid recording entry.');
      continue;
    }
    if (options.runApi && recording['consentConfirmed'] != true) {
      stderr.writeln(
        'Recording $recordingId has no explicit consentConfirmed=true.',
      );
      exitCode = 77;
      return;
    }
    if (options.runApi && recording['referenceVerified'] != true) {
      stderr.writeln(
        'Recording $recordingId has no explicit referenceVerified=true.',
      );
      exitCode = 65;
      return;
    }
    final resolvedReference = _resolve(manifestDirectory, referencePath);
    final referenceFile = File(resolvedReference);
    if (!await referenceFile.exists()) {
      stderr.writeln('Reference transcript missing for $recordingId.');
      continue;
    }
    final referenceTranscript = await referenceFile.readAsString();
    final hypotheses = recording['hypotheses'] is Map
        ? Map<String, dynamic>.from(recording['hypotheses'] as Map)
        : const <String, dynamic>{};

    for (final configuration in TranscriptionEvaluationConfig.all) {
      String? hypothesisTranscript;
      Duration? latency;
      String? statusOverride;
      if (options.runApi) {
        if (audioPath == null) {
          statusOverride = 'audio_path_missing';
        } else {
          final resolvedAudio = _resolve(manifestDirectory, audioPath);
          if (!await File(resolvedAudio).exists()) {
            statusOverride = 'audio_file_missing';
          } else {
            final transcriber = GroqTranscriptionService.finalRecording(
              apiKey: apiKey,
              model: configuration.model,
              enableContextPrompt: configuration.contextEnabled,
            );
            final stopwatch = Stopwatch()..start();
            try {
              hypothesisTranscript = await transcriber.transcribe(
                resolvedAudio,
              );
            } on TranscriptionException catch (error) {
              statusOverride = 'api_${error.type.name}';
            } catch (_) {
              statusOverride = 'api_unexpected_failure';
            } finally {
              stopwatch.stop();
              latency = stopwatch.elapsed;
              transcriber.dispose();
            }
          }
        }
      } else {
        final rawHypothesis = hypotheses[configuration.id];
        if (rawHypothesis is Map) {
          final hypothesis = Map<String, dynamic>.from(rawHypothesis);
          final transcriptPath = _text(hypothesis['transcriptPath']);
          final latencyMilliseconds = _number(hypothesis['latencyMs']);
          if (latencyMilliseconds != null && latencyMilliseconds >= 0) {
            latency = Duration(
              microseconds: (latencyMilliseconds * 1000).round(),
            );
          }
          if (transcriptPath == null) {
            statusOverride = 'hypothesis_path_missing';
          } else {
            final file = File(_resolve(manifestDirectory, transcriptPath));
            if (await file.exists()) {
              hypothesisTranscript = await file.readAsString();
            } else {
              statusOverride = 'hypothesis_file_missing';
            }
          }
        } else {
          statusOverride = 'hypothesis_not_provided';
        }
      }

      final metrics = TranscriptionAccuracyEvaluator.evaluate(
        referenceTranscript: referenceTranscript,
        hypothesisTranscript: hypothesisTranscript,
        rehearsalDuration: Duration(
          microseconds: (rehearsalSeconds * 1000000).round(),
        ),
        latency: latency,
      );
      rows.add(
        TranscriptionEvaluationRow(
          recordingId: recordingId,
          configuration: configuration,
          metrics: metrics,
          rehearsalDurationSeconds: rehearsalSeconds,
          referenceVerified: recording['referenceVerified'] == true,
          audioDurationSeconds: _number(recording['audioDurationSeconds']),
          languageGroup: _text(recording['languageGroup']),
          environment: _text(recording['environment']),
          speakingVolume: _text(recording['speakingVolume']),
          microphone: _text(recording['microphone']),
          boundaryCase: _text(recording['boundaryCase']),
          interruptionNotes: _text(recording['interruptionNotes']),
          statusOverride: statusOverride,
        ),
      );
    }
  }

  final outputPath = options.outputPath ?? 'transcription_accuracy_results.csv';
  final output = File(outputPath);
  await output.parent.create(recursive: true);
  await output.writeAsString(TranscriptionEvaluationCsv.encode(rows));
  stdout.writeln('Wrote ${rows.length} metric rows to ${output.path}.');
  stdout.writeln(
    options.runApi
        ? 'API evaluation completed; review failures and consent records.'
        : 'Offline evaluation completed; no audio was uploaded.',
  );
}

String _resolve(String base, String path) {
  final absolute = RegExp(r'^(?:[A-Za-z]:[\\/]|[/\\]{2}|/)').hasMatch(path);
  return absolute ? path : '$base${Platform.pathSeparator}$path';
}

String? _text(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

double? _number(Object? value) => value is num ? value.toDouble() : null;

class _Options {
  const _Options({
    required this.manifestPath,
    required this.outputPath,
    required this.runApi,
    required this.authorizePaidApi,
    required this.help,
  });

  final String? manifestPath;
  final String? outputPath;
  final bool runApi;
  final bool authorizePaidApi;
  final bool help;

  factory _Options.parse(List<String> arguments) {
    String? manifest;
    String? output;
    var runApi = false;
    var authorize = false;
    var help = false;
    for (var index = 0; index < arguments.length; index++) {
      switch (arguments[index]) {
        case '--manifest':
          if (index + 1 < arguments.length) manifest = arguments[++index];
        case '--output':
          if (index + 1 < arguments.length) output = arguments[++index];
        case '--run-api':
          runApi = true;
        case '--authorize-paid-api':
          authorize = true;
        case '--help' || '-h':
          help = true;
      }
    }
    return _Options(
      manifestPath: manifest,
      outputPath: output,
      runApi: runApi,
      authorizePaidApi: authorize,
      help: help,
    );
  }
}

const _usage = '''
SpeakSync transcription accuracy evaluation

Offline (default; no upload):
  dart run tool/transcription_accuracy_evaluation.dart \\
    --manifest evaluation/manifest.json \\
    --output evaluation/results.csv

Paid/API evaluation (uploads each consented recording four times):
  dart run tool/transcription_accuracy_evaluation.dart \\
    --manifest evaluation/manifest.json \\
    --output evaluation/results.csv \\
    --run-api --authorize-paid-api

API mode reads GROQ_API_KEY from the process environment. It never writes raw
audio or generated transcripts to the report.
''';
