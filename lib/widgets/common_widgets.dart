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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF9AA8B8),
                      size: 13,
                    ),
                ],
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
    this.isPending = false,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool isChecking;
  final bool isPending;

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
        trailing: SizedBox(
          width: 110,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (isChecking)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (isPending)
                const Icon(
                  Icons.more_horiz_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                )
              else
                const Icon(
                  Icons.check_circle_rounded,
                  color: successGreen,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  status,
                  style: TextStyle(
                    color: isPending ? const Color(0xFF94A3B8) : successGreen,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 34),
            child: Text(
              'Overall score',
              style: TextStyle(
                color: navy,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            height: 210,
            width: double.infinity,
            child: CustomPaint(painter: _ProgressChartPainter(sessions)),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 34, top: 4, bottom: 4),
            child: Text(
              'Based on your saved rehearsal scores.',
              style: TextStyle(color: Color(0xFF617085), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressChartPainter extends CustomPainter {
  _ProgressChartPainter(this.sessions);
  final List<PracticeSession> sessions;

  @override
  void paint(Canvas canvas, Size size) {
    const plotLeft = 35.0;
    const plotRight = 10.0;
    const plotTop = 20.0;
    const plotBottom = 35.0;
    final plotHeight = size.height - plotTop - plotBottom;
    final plotWidth = size.width - plotLeft - plotRight;
    final gridPaint = Paint()
      ..color = const Color(0xFFE4EAF2)
      ..strokeWidth = 1;
    const scoreScale = [100, 80, 60, 40];
    for (var i = 0; i < scoreScale.length; i++) {
      final y = plotTop + plotHeight * i / (scoreScale.length - 1);
      canvas.drawLine(
        Offset(plotLeft, y),
        Offset(size.width - plotRight, y),
        gridPaint,
      );
      _paintText(
        canvas,
        '${scoreScale[i]}',
        Offset(plotLeft - 7, y),
        const TextStyle(color: Color(0xFF7A8798), fontSize: 10),
        alignRight: true,
        centerVertically: true,
      );
    }

    final values = [...sessions]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (values.length > 6) values.removeRange(0, values.length - 6);
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
          ? plotLeft + plotWidth / 2
          : plotLeft + plotWidth * i / (values.length - 1);
      final normalized = (values[i].overallScore.clamp(40, 100) - 40) / 60;
      final y = plotTop + plotHeight - normalized * plotHeight;
      points.add(Offset(x, y));
    }
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, plotTop + plotHeight)
      ..lineTo(points.first.dx, plotTop + plotHeight)
      ..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      canvas.drawCircle(point, 6, Paint()..color = Colors.white);
      canvas.drawCircle(point, 4, pointPaint);
      _paintText(
        canvas,
        '${values[index].overallScore}',
        Offset(point.dx, point.dy - 10),
        const TextStyle(
          color: primaryBlue,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
        centerHorizontally: true,
        alignBottom: true,
      );
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final date = values[index].dateTime;
      _paintText(
        canvas,
        '${months[date.month - 1]} ${date.day}',
        Offset(point.dx, size.height - 18),
        const TextStyle(color: Color(0xFF617085), fontSize: 9),
        centerHorizontally: true,
        centerVertically: true,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset anchor,
    TextStyle style, {
    bool alignRight = false,
    bool centerHorizontally = false,
    bool centerVertically = false,
    bool alignBottom = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = anchor.dx;
    var dy = anchor.dy;
    if (alignRight) dx -= painter.width;
    if (centerHorizontally) dx -= painter.width / 2;
    if (centerVertically) dy -= painter.height / 2;
    if (alignBottom) dy -= painter.height;
    painter.paint(canvas, Offset(dx, dy));
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
