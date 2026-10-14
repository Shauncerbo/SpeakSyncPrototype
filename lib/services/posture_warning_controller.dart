enum PostureWarningSignal { good, adjust, unavailable }

enum PostureWarningType { adjustPosture, positionYourself }

class PostureWarningUpdate {
  const PostureWarningUpdate({required this.warning, required this.changed});

  final PostureWarningType? warning;
  final bool changed;
}

/// Converts continuous pose states into stable, persistent student warnings.
/// A single frame can never create or clear a warning.
class PostureWarningController {
  PostureWarningController({
    this.warningDelay = const Duration(seconds: 3),
    this.recoveryDelay = const Duration(seconds: 2),
  });

  final Duration warningDelay;
  final Duration recoveryDelay;

  Duration? _adjustSince;
  Duration? _missingSince;
  Duration? _goodSince;
  Duration? _visibleSince;
  PostureWarningType? _warning;

  PostureWarningType? get warning => _warning;

  PostureWarningUpdate update(PostureWarningSignal signal, Duration timestamp) {
    final previous = _warning;

    if (signal == PostureWarningSignal.unavailable) {
      _missingSince ??= timestamp;
      _visibleSince = null;
      _adjustSince = null;
      _goodSince = null;

      // Invalid landmarks are unavailable, never bad posture. Remove an old
      // adjust warning immediately, then wait for persistent unavailability.
      if (_warning == PostureWarningType.adjustPosture) _warning = null;
      if (timestamp - _missingSince! >= warningDelay) {
        _warning = PostureWarningType.positionYourself;
      }
      return PostureWarningUpdate(
        warning: _warning,
        changed: previous != _warning,
      );
    }

    _visibleSince ??= timestamp;
    _missingSince = null;

    if (signal == PostureWarningSignal.good) {
      _goodSince ??= timestamp;
      _adjustSince = null;
    } else {
      _adjustSince ??= timestamp;
      _goodSince = null;
    }

    // The missing-body warning has priority until landmarks have remained
    // reliably visible for the complete recovery period.
    if (_warning == PostureWarningType.positionYourself) {
      if (timestamp - _visibleSince! >= recoveryDelay) {
        _warning = null;
      } else {
        return PostureWarningUpdate(warning: _warning, changed: false);
      }
    }

    if (signal == PostureWarningSignal.good &&
        _warning == PostureWarningType.adjustPosture &&
        timestamp - _goodSince! >= recoveryDelay) {
      _warning = null;
    } else if (signal == PostureWarningSignal.adjust &&
        _warning == null &&
        timestamp - _adjustSince! >= warningDelay) {
      _warning = PostureWarningType.adjustPosture;
    }

    return PostureWarningUpdate(
      warning: _warning,
      changed: previous != _warning,
    );
  }

  PostureWarningUpdate reset() {
    final changed = _warning != null;
    _adjustSince = null;
    _missingSince = null;
    _goodSince = null;
    _visibleSince = null;
    _warning = null;
    return PostureWarningUpdate(warning: null, changed: changed);
  }
}
