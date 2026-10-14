import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:speaksync_prototype/services/speech_document_service.dart';

Uint8List _pdf({bool withText = true}) {
  final stream = withText
      ? 'BT /F1 12 Tf 72 720 Td (Hello SpeakSync) Tj ET'
      : '0 0 20 20 re f';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    out.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF',
  );
  return Uint8List.fromList(ascii.encode(out.toString()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Use real PDFium text extraction; only the Flutter cache directory is set.
  Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
  const service = SpeechDocumentService();
  Uint8List bytes(String value) => Uint8List.fromList(utf8.encode(value));
  test(
    'TXT preserves localized characters and normalizes whitespace',
    () async {
      final doc = await service.extractBytes(
        'speech.TXT',
        bytes('\uFEFFMaayong  buntag!\r\nNiño mura’g maayo.'),
      );
      expect(doc.fileName, 'speech.TXT');
      expect(doc.text, 'Maayong buntag!\nNiño mura’g maayo.');
    },
  );
  test('DOCX reads XML text runs, paragraphs and numeric entities', () async {
    final body = bytes(
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Ni&#241;o &amp; </w:t></w:r><w:r><w:t>mura’g maayo</w:t></w:r></w:p><w:p><w:r><w:t>Salamat</w:t></w:r></w:p></w:body></w:document>',
    );
    final archive = Archive()
      ..addFile(ArchiveFile('word/document.xml', body.length, body));
    final doc = await service.extractBytes(
      'speech.docx',
      Uint8List.fromList(ZipEncoder().encode(archive)),
    );
    expect(doc.text, 'Niño & mura’g maayo\nSalamat');
  });
  test('text-based PDF extracts locally through PDFium', () async {
    final doc = await service.extractBytes('speech.pdf', _pdf());
    expect(doc.text, contains('Hello SpeakSync'));
  });
  test('PDF without text explains that OCR is not supported', () async {
    await expectLater(
      service.extractBytes('scan.pdf', _pdf(withText: false)),
      throwsA(
        isA<SpeechDocumentException>().having(
          (e) => e.message,
          'message',
          contains('Scanned/image-only'),
        ),
      ),
    );
  });
  for (final name in [
    'empty.txt',
    'corrupt.docx',
    'unreadable.pdf',
    'unsupported.jpg',
  ]) {
    test('$name fails gracefully', () async {
      await expectLater(
        service.extractBytes(
          name,
          bytes(name == 'empty.txt' ? ' \n ' : 'bad data'),
        ),
        throwsA(isA<SpeechDocumentException>()),
      );
    });
  }
  test('oversized document is rejected before parsing', () async {
    await expectLater(
      service.extractBytes(
        'large.pdf',
        Uint8List(SpeechDocumentService.maxFileBytes + 1),
      ),
      throwsA(isA<SpeechDocumentException>()),
    );
  });
}
