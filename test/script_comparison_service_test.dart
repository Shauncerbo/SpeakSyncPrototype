import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/script_comparison_service.dart';

void main() {
  const service = ScriptComparisonService();

  test('identifies omitted, added, and differently delivered portions', () {
    final result = service.compare(
      referenceScript: 'Opening line. Important point. Closing statement.',
      transcript: 'Opening line. A different important point. Extra thought.',
    );

    expect(result.omittedPortions, contains('Closing statement.'));
    expect(result.addedPortions, contains('Extra thought.'));
    expect(
      result.differentlyDeliveredPortions.single,
      contains('Reference: Important point.'),
    );
  });

  test('reports no changes when the wording matches', () {
    final result = service.compare(
      referenceScript: 'Good morning. Thank you for listening.',
      transcript: 'Good morning. Thank you for listening.',
    );

    expect(result.hasDifferences, isFalse);
  });
}
