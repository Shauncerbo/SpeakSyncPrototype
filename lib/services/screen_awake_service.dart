import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class ScreenAwakeController {
  Future<void> enable();

  Future<void> disable();
}

class ScreenAwakeService implements ScreenAwakeController {
  const ScreenAwakeService();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}
