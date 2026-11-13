import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaksync_prototype/screens/practice_flow.dart';
import 'package:speaksync_prototype/services/full_body_framing.dart';
import 'package:speaksync_prototype/services/posture_analysis.dart';
import 'package:speaksync_prototype/state/app_state.dart';

List<PoseLandmarkPoint> _completePose({double lowerVisibility = .95}) =>
    List.generate(33, (index) {
      final isLowerBody = index >= 25;
      final y = switch (index) {
        0 => .08,
        11 || 12 => .28,
        23 || 24 => .52,
        25 || 26 => .70,
        27 || 28 => .88,
        31 || 32 => .95,
        _ => .45,
      };
      return PoseLandmarkPoint(
        x: index.isEven ? .44 : .56,
        y: y,
        visibility: isLowerBody ? lowerVisibility : .95,
      );
    });

PoseFrameLandmarks _landmarks({double lowerVisibility = .95}) {
  final points = _completePose(lowerVisibility: lowerVisibility);
  return PoseFrameLandmarks(
    leftShoulder: points[11],
    rightShoulder: points[12],
    leftHip: points[23],
    rightHip: points[24],
    allPoints: points,
  );
}

void main() {
  const analyzer = FullBodyFramingAnalyzer();

  test('complete visible head-to-feet pose is detected', () {
    expect(analyzer.analyze(_landmarks()), FullBodyFramingState.detected);
  });

  test('missing lower-body landmarks recommends moving farther away', () {
    expect(
      analyzer.analyze(_landmarks(lowerVisibility: .1)),
      FullBodyFramingState.moveFarther,
    );
  });

  test('upper-body-only and missing poses remain unavailable', () {
    const upperBodyOnly = PoseFrameLandmarks(
      leftShoulder: PoseLandmarkPoint(x: .4, y: .3, visibility: .9),
      rightShoulder: PoseLandmarkPoint(x: .6, y: .3, visibility: .9),
      leftHip: PoseLandmarkPoint(x: .44, y: .6, visibility: .9),
      rightHip: PoseLandmarkPoint(x: .56, y: .6, visibility: .9),
    );
    expect(analyzer.analyze(upperBodyOnly), FullBodyFramingState.unavailable);
    expect(analyzer.analyze(null), FullBodyFramingState.unavailable);
  });

  test(
    'native payload retains all 33 landmarks without changing torso data',
    () {
      final points = _completePose();
      Map<String, Object> point(PoseLandmarkPoint value) => {
        'x': value.x,
        'y': value.y,
        'visibility': value.visibility,
      };
      final parsed = PoseFrameLandmarks.fromMap({
        'leftShoulder': point(points[11]),
        'rightShoulder': point(points[12]),
        'leftHip': point(points[23]),
        'rightHip': point(points[24]),
        'allLandmarks': points.map(point).toList(),
      });

      expect(parsed.allPoints, hasLength(33));
      expect(parsed.leftShoulder.x, points[11].x);
      expect(parsed.rightHip.y, points[24].y);
    },
  );

  testWidgets('full-body mode reveals an enabled live-skeleton option', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppStateScope(
        notifier: AppState(),
        child: const MaterialApp(home: PracticeSetupScreen()),
      ),
    );

    final fullBody = find.byKey(const Key('full_body_framing'));
    expect(fullBody, findsOneWidget);
    expect(find.byKey(const Key('show_live_skeleton')), findsNothing);

    await tester.ensureVisible(fullBody);
    await tester.tap(fullBody);
    await tester.pump();

    final skeleton = find.byKey(const Key('show_live_skeleton'));
    expect(skeleton, findsOneWidget);
    expect(tester.widget<SwitchListTile>(skeleton).value, isTrue);
    expect(
      find.textContaining('does not change posture scores'),
      findsOneWidget,
    );
  });
}
