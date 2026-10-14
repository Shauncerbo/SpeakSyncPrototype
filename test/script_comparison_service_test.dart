import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/script_comparison_service.dart';

void main() {
  const service = ScriptComparisonService();
  test('exact match counts every reference word and matched phrase', () {
    final r = service.compare(
      referenceScript: 'Good morning everyone.',
      transcript: 'Good morning everyone.',
    );
    expect(r.coverage, 100);
    expect(r.matchedReferenceWords, 3);
    expect(r.totalReferenceWords, 3);
    expect(r.matchedPortions, ['Good morning everyone']);
    expect(r.hasDifferences, false);
  });
  test('omitted words are grouped and reduce coverage', () {
    final r = service.compare(
      referenceScript: 'We value effective clear communication today',
      transcript: 'We value communication today',
    );
    expect(r.omittedPortions, ['effective clear']);
    expect(r.matchedReferenceWords, 4);
    expect(r.coverage, closeTo(66.6667, .001));
  });
  test('added words are grouped without reducing reference coverage', () {
    final r = service.compare(
      referenceScript: 'We speak today',
      transcript: 'We speak based on experience today',
    );
    expect(r.addedPortions, ['based on experience']);
    expect(r.coverage, 100);
    expect(r.hasDifferences, true);
  });
  test('replacement pairs expected and spoken wording', () {
    final r = service.compare(
      referenceScript: 'Public speaking is an essential communication skill',
      transcript: 'Public speaking is a very important skill',
    );
    expect(r.differentlyDeliveredPortions, [
      'Expected: an essential communication\nSpoken: a very important',
    ]);
    expect(r.omittedPortions, isEmpty);
    expect(r.addedPortions, isEmpty);
    expect(r.matchedReferenceWords, 4);
  });
  test('capitalization is ignored', () {
    expect(
      service
          .compare(referenceScript: 'HELLO World', transcript: 'hello WORLD')
          .coverage,
      100,
    );
  });
  test('punctuation and whitespace are ignored', () {
    expect(
      service
          .compare(
            referenceScript: 'Hello,\n\nworld! This is practice.',
            transcript: 'hello world this   is practice',
          )
          .hasDifferences,
      false,
    );
  });
  test('Filipino/Bisaya characters and apostrophes are preserved', () {
    final r = service.compare(
      referenceScript:
          "Maayong buntag, mura’g maayo ang Niño ug iyang pangandoy.",
      transcript: "MAAYONG BUNTAG mura'g maayo ang niño ug iyang pangandoy",
    );
    expect(r.coverage, 100);
    expect(r.totalReferenceWords, 9);
  });
  test('empty script is unavailable, not a zero score', () {
    expect(
      service.compare(referenceScript: '...', transcript: 'Hello').status,
      'emptyScript',
    );
    expect(
      service.compare(referenceScript: null, transcript: 'Hello').coverage,
      isNull,
    );
  });
  test('empty transcript does not label all script words omitted', () {
    final r = service.compare(referenceScript: 'Hello world', transcript: null);
    expect(r.status, 'emptyTranscript');
    expect(r.coverage, isNull);
    expect(r.omittedPortions, isEmpty);
  });
  test('Impromptu is not eligible', () {
    expect(ScriptComparisonService.supports('Impromptu'), false);
    expect(ScriptComparisonService.supports('Prepared'), true);
    expect(ScriptComparisonService.supports('Persuasive'), true);
  });
  test('repeated words and word order are not collapsed into sets', () {
    final r = service.compare(
      referenceScript: 'one two one two',
      transcript: 'two one',
    );
    expect(r.matchedReferenceWords, 2);
    expect(r.coverage, 50);
  });
  test(
    'long exact scripts are fast; excessive different scripts fail safely',
    () {
      final script = List.filled(12000, 'word').join(' ');
      expect(
        service.compare(referenceScript: script, transcript: script).coverage,
        100,
      );
      final r = service.compare(
        referenceScript: List.filled(3000, 'first').join(' '),
        transcript: List.filled(3000, 'second').join(' '),
      );
      expect(r.status, 'tooLong');
      expect(r.coverage, isNull);
    },
  );
}
