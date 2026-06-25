import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/practice_session.dart';

class SpeakSyncLogo extends StatelessWidget {
  const SpeakSyncLogo({
    super.key,
    this.size = 64,
    this.showName = true,
    this.light = false,
  });

  final double size;
  final bool showName;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : navy;
    return Semantics(
      label: 'SpeakSync logo',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * .28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryBlue, accentTeal],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withValues(alpha: .22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.record_voice_over_rounded,
              color: Colors.white,
              size: size * .55,
            ),
          ),
          if (showName) ...[
            const SizedBox(width: 12),
            Text(
              'SpeakSync',
              style: TextStyle(
                color: foreground,
                fontSize: size * .38,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
    this.maxWidth = 720,
  });

  final Widget child;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: navy,
            ),
          ),
        ),
        if (trailing case final Widget trailing) trailing,
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = primaryBlue,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: Color(0xFF617085))),
          ],
        ),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = primaryBlue,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    this.isChecking = false,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minTileHeight: 72,
        leading: CircleAvatar(
          backgroundColor: accentTeal.withValues(alpha: .1),
          foregroundColor: accentTeal,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isChecking)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.check_circle_rounded,
                color: successGreen,
                size: 20,
              ),
            const SizedBox(width: 7),
            Text(
              status,
              style: const TextStyle(
                color: successGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 150});
  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? successGreen
        : score >= 70
        ? warningOrange
        : errorRed;
    return Semantics(
      label: 'Performance score $score out of 100',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: const Color(0xFFE4EAF2),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: size * .3,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: navy,
                  ),
                ),
                const Text(
                  'out of 100',
                  style: TextStyle(color: Color(0xFF617085)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.session, required this.onTap});

  final PracticeSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = formatDate(session.dateTime);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${session.overallScore}',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$date • ${formatDuration(session.duration)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF617085),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      session.speechType,
                      style: const TextStyle(
                        fontSize: 12,
                        color: accentTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8B98A9)),
            ],
          ),
        ),
      ),
    );
  }
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String formatDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class ProgressChart extends StatelessWidget {
  const ProgressChart({super.key, required this.sessions});
  final List<PracticeSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progress chart showing recent performance scores',
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: CustomPaint(painter: _ProgressChartPainter(sessions)),
      ),
    );
  }
}

class _ProgressChartPainter extends CustomPainter {
  _ProgressChartPainter(this.sessions);
  final List<PracticeSession> sessions;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE4EAF2)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = 16 + (size.height - 36) * i / 3;
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), gridPaint);
    }

    final values = sessions.take(6).toList().reversed.toList();
    if (values.isEmpty) return;
    final path = Path();
    final pointPaint = Paint()..color = accentTeal;
    final linePaint = Paint()
      ..color = primaryBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryBlue.withValues(alpha: .2),
          primaryBlue.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : 14 + (size.width - 28) * i / (values.length - 1);
      final normalized = (values[i].overallScore.clamp(40, 100) - 40) / 60;
      final y = size.height - 20 - normalized * (size.height - 42);
      points.add(Offset(x, y));
    }
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height - 15)
      ..lineTo(points.first.dx, size.height - 15)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 6, Paint()..color = Colors.white);
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(_ProgressChartPainter oldDelegate) =>
      !const ListEquality().equals(oldDelegate.sessions, sessions);
}

class ListEquality {
  const ListEquality();
  bool equals(List<Object> a, List<Object> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < math.min(a.length, b.length); i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.rating, this.maxRating = 5});
  final int rating;
  final int maxRating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: warningOrange,
          size: 20,
        );
      }),
    );
  }
}

class FillerBarChart extends StatelessWidget {
  const FillerBarChart({super.key, required this.fillerCounts});
  final Map<String, int> fillerCounts;

  @override
  Widget build(BuildContext context) {
    if (fillerCounts.isEmpty) return const SizedBox.shrink();
    final maxCount = fillerCounts.values.reduce(math.max);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: fillerCounts.entries.map((entry) {
            final percentage = maxCount > 0 ? entry.value / maxCount : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 65,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE4EAF2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: warningOrange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class PaceLineChart extends StatelessWidget {
  const PaceLineChart({super.key, required this.paceHistory});
  final List<int> paceHistory;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Line chart showing simulated speaking pace over time',
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: CustomPaint(painter: _PaceLineChartPainter(paceHistory)),
      ),
    );
  }
}

class _PaceLineChartPainter extends CustomPainter {
  _PaceLineChartPainter(this.paceHistory);
  final List<int> paceHistory;

  @override
  void paint(Canvas canvas, Size size) {
    if (paceHistory.isEmpty) return;
    final gridPaint = Paint()
      ..color = const Color(0xFFE4EAF2)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = 10 + (size.height - 20) * i / 3;
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), gridPaint);
    }

    final path = Path();
    final pointPaint = Paint()..color = primaryBlue;
    final linePaint = Paint()
      ..color = primaryBlue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final points = <Offset>[];
    double minPace = 80;
    double maxPace = 180;
    for (var i = 0; i < paceHistory.length; i++) {
      final x = paceHistory.length == 1
          ? size.width / 2
          : 14 + (size.width - 28) * i / (paceHistory.length - 1);
      final normalized = (paceHistory[i].clamp(minPace, maxPace) - minPace) / (maxPace - minPace);
      final y = size.height - 10 - normalized * (size.height - 20);
      points.add(Offset(x, y));
    }

    if (points.length == 1) {
      canvas.drawCircle(points.first, 4, pointPaint);
      return;
    }

    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 5, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(_PaceLineChartPainter oldDelegate) =>
      !const ListEquality().equals(oldDelegate.paceHistory, paceHistory);
}
