import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';

class SpeechDocument {
  const SpeechDocument({required this.fileName, required this.text});

  final String fileName;
  final String text;
}

class SpeechDocumentException implements Exception {
  const SpeechDocumentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SpeechDocumentService {
  const SpeechDocumentService();

  Future<SpeechDocument?> pickAndExtract() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'docx'],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();

    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';
    final text = switch (extension) {
      'txt' => _extractTextFile(bytes),
      'docx' => _extractDocx(bytes),
      _ => throw const SpeechDocumentException(
        'Choose a TXT or DOCX speech document.',
      ),
    };
    final cleaned = _cleanText(text);
    if (cleaned.isEmpty) {
      throw const SpeechDocumentException(
        'No readable speech text was found in the document.',
      );
    }
    return SpeechDocument(fileName: file.name, text: cleaned);
  }

  String _extractTextFile(Uint8List bytes) {
    try {
      return utf8
          .decode(bytes, allowMalformed: false)
          .replaceFirst('\uFEFF', '');
    } on FormatException {
      return latin1.decode(bytes).replaceFirst('\uFEFF', '');
    }
  }

  String _extractDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final document = archive.findFile('word/document.xml');
      if (document == null) {
        throw const SpeechDocumentException(
          'The DOCX file does not contain a readable document body.',
        );
      }
      final documentBytes = document.readBytes();
      if (documentBytes == null) {
        throw const SpeechDocumentException(
          'The DOCX file does not contain a readable document body.',
        );
      }
      final xml = utf8.decode(documentBytes, allowMalformed: true);
      return xml
          .replaceAll(RegExp(r'</w:p\s*>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<w:tab\s*/>', caseSensitive: false), '\t')
          .replaceAll(
            RegExp(r'<w:br(?:\s[^>]*)?\s*/>', caseSensitive: false),
            '\n',
          )
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'");
    } on SpeechDocumentException {
      rethrow;
    } catch (_) {
      throw const SpeechDocumentException(
        'The DOCX file could not be opened. Try saving it again or use TXT.',
      );
    }
  }

  String _cleanText(String value) => value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
