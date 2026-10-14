import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/camera_framing.dart';
import '../services/posture_warning_controller.dart';

/// Silent, in-preview feedback. Persistent warnings are supplied by the existing
/// warning controllers; speech events retain the rehearsal's short timeout.
class LiveFeedbackOverlay extends StatelessWidget {
  const LiveFeedbackOverlay({
    super.key,
    required this.enabled,
    required this.visualEnabled,
    required this.monitorBodyLanguage,
    required this.monitorCameraAttention,
    required this.faceWarning,
    required this.faceMissingWarning,
    required this.postureWarning,
    required this.framingWarning,
    this.temporaryMessage,
    this.temporaryColor = primaryBlue,
    this.temporaryIcon = Icons.info_outline_rounded,
    this.systemMessage,
    this.systemColor = primaryBlue,
    this.systemIcon = Icons.info_outline_rounded,
  });

  final bool enabled;
  final bool visualEnabled;
  final bool monitorBodyLanguage;
  final bool monitorCameraAttention;
  final ValueListenable<bool> faceWarning;
  final ValueListenable<PostureWarningType?> faceMissingWarning;
  final ValueListenable<PostureWarningType?> postureWarning;
  final ValueListenable<CameraFramingState?> framingWarning;
  final String? temporaryMessage;
  final Color temporaryColor;
  final IconData temporaryIcon;
  // Operational notices are independent of performance-monitoring settings.
  final String? systemMessage;
  final Color systemColor;
  final IconData systemIcon;

  @override
  Widget build(BuildContext context) {
    if (!enabled && systemMessage == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge([
        faceWarning,
        faceMissingWarning,
        postureWarning,
        framingWarning,
      ]),
      builder: (context, child) {
        final cards = <Widget>[];
        if (systemMessage != null) {
          cards.add(
            _card(
              'system_rehearsal_alert',
              systemMessage!,
              systemIcon,
              color: systemColor,
            ),
          );
        }
        var missing = false;
        if (enabled && visualEnabled && monitorCameraAttention) {
          missing = faceMissingWarning.value != null;
          if (faceWarning.value && !missing) {
            cards.add(
              _card(
                'face_attention_warning',
                'Please face the camera',
                Icons.face_rounded,
              ),
            );
          }
        }
        if (enabled && visualEnabled && monitorBodyLanguage) {
          if (postureWarning.value == PostureWarningType.adjustPosture) {
            cards.add(
              _card(
                'persistent_posture_warning',
                'Adjust your posture',
                Icons.accessibility_new_rounded,
              ),
            );
          }
          missing =
              missing ||
              postureWarning.value == PostureWarningType.positionYourself ||
              framingWarning.value == CameraFramingState.unavailable;
          final message = switch (framingWarning.value) {
            CameraFramingState.tooClose => 'Move farther from the camera',
            CameraFramingState.tooFar => 'Move closer to the camera',
            _ => null,
          };
          if (message != null) {
            cards.add(
              _card(
                'camera_framing_warning',
                message,
                Icons.fit_screen_rounded,
              ),
            );
          }
        }
        // Missing face/body landmarks share one instruction, not duplicate cards.
        if (missing) {
          cards.add(
            _card(
              'missing_landmarks_warning',
              'Position yourself in the camera view',
              Icons.center_focus_weak_rounded,
            ),
          );
        }
        if (enabled && temporaryMessage != null) {
          cards.add(
            _card(
              'temporary_rehearsal_alert',
              temporaryMessage!,
              temporaryIcon,
              color: temporaryColor,
            ),
          );
        }
        if (cards.isEmpty) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            // Reserve bottom space for the mic meter and media controls. On short
            // landscape previews or large text, cards scroll rather than overflow.
            final maxHeight = math.max(
              36.0,
              math.min(220.0, constraints.maxHeight - 76),
            );
            return Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Center(
                    child: ConstrainedBox(
                      key: const Key('live_feedback_overlay'),
                      constraints: BoxConstraints(
                        maxWidth: 360,
                        maxHeight: maxHeight,
                      ),
                      child: SingleChildScrollView(
                        primary: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              if (i > 0) const SizedBox(height: 4),
                              cards[i],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _card(
    String id,
    String message,
    IconData icon, {
    Color color = warningOrange,
  }) {
    return Container(
      key: Key(id),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE61A2938),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
