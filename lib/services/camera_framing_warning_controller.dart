import 'camera_framing.dart';

/// Presentation-only persistence; does not alter landmark classification.
class CameraFramingWarningController {
  CameraFramingWarningController({
    this.warningDelay = const Duration(seconds: 3),
    this.recoveryDelay = const Duration(seconds: 2),
  });

  final Duration warningDelay;
  final Duration recoveryDelay;
  CameraFramingState? _candidate;
  Duration? _candidateSince;
  CameraFramingState? _warning;

  CameraFramingState? get warning => _warning;

  CameraFramingState? update(CameraFramingState state, Duration timestamp) {
    if (_candidate != state) {
      _candidate = state;
      _candidateSince = timestamp;
    }
    // Invalid landmarks cannot sustain a misleading distance instruction.
    if (state == CameraFramingState.unavailable &&
        _warning != CameraFramingState.unavailable) {
      _warning = null;
    }
    final delay = state == CameraFramingState.proper
        ? recoveryDelay
        : warningDelay;
    if (timestamp - _candidateSince! >= delay) {
      _warning = state == CameraFramingState.proper ? null : state;
    }
    return _warning;
  }

  void reset() {
    _candidate = null;
    _candidateSince = null;
    _warning = null;
  }
}
