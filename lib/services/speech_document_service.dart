import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:xml/xml.dart';

import 'script_comparison_service.dart';

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
  static const maxFileBytes = 10 * 1024 * 1024;

  Future<SpeechDocument?> pickAndExtract() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'txt', 'docx'],
    );
    if (file == null) return null;

    if (await file.length() > maxFileBytes) {
      throw const SpeechDocumentException(
        'Choose a document smaller than 10 MB.',
      );
    }
    return extractBytes(file.name, await file.readAsBytes());
  }

  Future<SpeechDocument> extractBytes(String fileName, Uint8List bytes) async {
    if (bytes.length > maxFileBytes) {
      throw const SpeechDocumentException(
        'Choose a document smaller than 10 MB.',
      );
    }
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final text = switch (extension) {
      'pdf' => await _extractPdf(bytes),
      'txt' || 'docx' => await compute(_extractEditable, (extension, bytes)),
      _ => throw const SpeechDocumentException(
        'Choose a PDF, DOCX, or TXT speech document.',
      ),
    };
    final cleaned = _cleanText(text);
    if (cleaned.isEmpty) {
      throw const SpeechDocumentException(
        'No readable speech text was found in the document.',
      );
    }
    if (cleaned.length > ScriptComparisonService.maxTextCharacters) {
      throw const SpeechDocumentException(
        'This script is too long. Choose a shorter section (up to 120,000 characters).',
      );
    }
    return SpeechDocument(fileName: fileName, text: cleaned);
  }

  static String _extractEditable((String, Uint8List) input) => input.$1 == 'txt'
      ? const SpeechDocumentService()._extractTextFile(input.$2)
      : const SpeechDocumentService()._extractDocx(input.$2);

  Future<String> _extractPdf(Uint8List bytes) async {
    PdfDocument? document;
    try {
      await pdfrxFlutterInitialize();
      document = await PdfDocument.openData(bytes);
      if (document.pages.length > 100) {
        throw const SpeechDocumentException(
          'Choose a speech PDF with 100 pages or fewer.',
        );
      }
      final buffer = StringBuffer();
      for (final page in document.pages) {
        buffer.writeln((await page.loadText())?.fullText ?? '');
        if (buffer.length > ScriptComparisonService.maxTextCharacters) {
          throw const SpeechDocumentException(
            'This PDF contains too much text. Choose a shorter section.',
          );
        }
      }
      if (buffer.toString().trim().isEmpty) {
        throw const SpeechDocumentException(
          'No readable text was found in this PDF. Scanned/image-only PDFs are not supported yet. Choose a text-based PDF, DOCX, or TXT.',
        );
      }
      return buffer.toString();
    } on SpeechDocumentException {
      rethrow;
    } catch (_) {
      throw const SpeechDocumentException(
        'This PDF could not be read. It may be damaged or password-protected. Try an unlocked text-based PDF, DOCX, or TXT.',
      );
    } finally {
      await document?.dispose();
    }
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
      if (document.size > 4 * 1024 * 1024) {
        throw const SpeechDocumentException(
          'The DOCX body is too large. Choose a shorter speech document.',
        );
      }
      final documentBytes = document.readBytes();
      if (documentBytes == null) {
        throw const SpeechDocumentException(
          'The DOCX file does not contain a readable document body.',
        );
      }
      final xml = XmlDocument.parse(utf8.decode(documentBytes));
      final buffer = StringBuffer();
      for (final paragraph in xml.descendants.whereType<XmlElement>().where(
        (e) => e.name.local == 'p',
      )) {
        for (final element in paragraph.descendants.whereType<XmlElement>()) {
          switch (element.name.local) {
            case 't':
              buffer.write(element.innerText);
            case 'tab':
              buffer.write(' ');
            case 'br':
            case 'cr':
              buffer.write('\n');
          }
        }
        buffer.writeln();
      }
      return buffer.toString();
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
