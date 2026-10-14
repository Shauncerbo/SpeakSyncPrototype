import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/services/posture_warning_controller.dart';

void main() {
  group('PostureWarningController', () {
    test('one bad frame does not show a warning', () {
      final controller = PostureWarningController();

      final update = controller.update(
        PostureWarningSignal.adjust,
        Duration.zero,
      );

      expect(update.warning, isNull);
      expect(update.changed, isFalse);
    });

    test('continuous Adjust for three seconds shows one stable warning', () {
      final controller = PostureWarningController();
      controller.update(PostureWarningSignal.adjust, Duration.zero);
      expect(
        controller
            .update(
              PostureWarningSignal.adjust,
              const Duration(milliseconds: 2999),
            )
            .warning,
        isNull,
      );

      final triggered = controller.update(
        PostureWarningSignal.adjust,
        const Duration(seconds: 3),
      );
      final unchanged = controller.update(
        PostureWarningSignal.adjust,
        const Duration(milliseconds: 3500),
      );

      expect(triggered.warning, PostureWarningType.adjustPosture);
      expect(triggered.changed, isTrue);
      expect(unchanged.warning, PostureWarningType.adjustPosture);
      expect(unchanged.changed, isFalse);
    });

    test('missing landmarks for three seconds shows position warning', () {
      final controller = PostureWarningController();
      controller.update(PostureWarningSignal.unavailable, Duration.zero);

      final update = controller.update(
        PostureWarningSignal.unavailable,
        const Duration(seconds: 3),
      );

      expect(update.warning, PostureWarningType.positionYourself);
      expect(update.changed, isTrue);
    });

    test('two seconds of good posture clears Adjust warning', () {
      final controller = PostureWarningController();
      controller.update(PostureWarningSignal.adjust, Duration.zero);
      controller.update(
        PostureWarningSignal.adjust,
        const Duration(seconds: 3),
      );
      controller.update(
        PostureWarningSignal.good,
        const Duration(milliseconds: 3500),
      );

      final update = controller.update(
        PostureWarningSignal.good,
        const Duration(milliseconds: 5500),
      );

      expect(update.warning, isNull);
      expect(update.changed, isTrue);
    });

    test('two seconds of reliable visibility clears position warning', () {
      final controller = PostureWarningController();
      controller.update(PostureWarningSignal.unavailable, Duration.zero);
      controller.update(
        PostureWarningSignal.unavailable,
        const Duration(seconds: 3),
      );
      controller.update(
        PostureWarningSignal.good,
        const Duration(milliseconds: 3500),
      );

      final update = controller.update(
        PostureWarningSignal.good,
        const Duration(milliseconds: 5500),
      );

      expect(update.warning, isNull);
      expect(update.changed, isTrue);
    });

    test('missing body takes priority over an Adjust warning', () {
      final controller = PostureWarningController();
      controller.update(PostureWarningSignal.adjust, Duration.zero);
      controller.update(
        PostureWarningSignal.adjust,
        const Duration(seconds: 3),
      );

      final firstMissing = controller.update(
        PostureWarningSignal.unavailable,
        const Duration(milliseconds: 3500),
      );
      final persistentMissing = controller.update(
        PostureWarningSignal.unavailable,
        const Duration(milliseconds: 6500),
      );

      expect(firstMissing.warning, isNot(PostureWarningType.adjustPosture));
      expect(persistentMissing.warning, PostureWarningType.positionYourself);
    });

    test('reset clears warning and all session timing state', () {
      final controller = PostureWarningController();
      controller.update(PostureWarningSignal.adjust, Duration.zero);
      controller.update(
        PostureWarningSignal.adjust,
        const Duration(seconds: 3),
      );

      final reset = controller.reset();
      final newSessionFrame = controller.update(
        PostureWarningSignal.adjust,
        const Duration(seconds: 20),
      );

      expect(reset.warning, isNull);
      expect(reset.changed, isTrue);
      expect(newSessionFrame.warning, isNull);
    });
  });
}
