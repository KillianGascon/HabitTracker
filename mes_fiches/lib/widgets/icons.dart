import 'package:flutter/widgets.dart';

/// Icônes Phosphor (Regular) redessinées sur leur grille 256 × 256.
enum AppIconKind {
  calendarCheck,
  squaresFour,
  plusCircle,
  plus,
  minus,
  check,
  pencil,
  caretLeft,
  caretRight,
  database,
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.kind, {super.key, this.size = 24, required this.color});

  final AppIconKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _IconPainter(kind, color)),
      );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.kind, this.color);

  final AppIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 256);
    double stroke = 16;
    if (kind == AppIconKind.plus || kind == AppIconKind.minus) stroke = 20;
    if (kind == AppIconKind.check) stroke = 28;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);
    void poly(List<double> pts) {
      final path = Path()..moveTo(pts[0], pts[1]);
      for (var i = 2; i < pts.length; i += 2) {
        path.lineTo(pts[i], pts[i + 1]);
      }
      canvas.drawPath(path, p);
    }

    void rrect(double x, double y, double w, double h) => canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(8)), p);

    switch (kind) {
      case AppIconKind.calendarCheck:
        rrect(40, 40, 176, 176);
        line(176, 24, 176, 56);
        line(80, 24, 80, 56);
        line(40, 88, 216, 88);
        poly([96, 152, 120, 176, 168, 128]);
      case AppIconKind.squaresFour:
        rrect(48, 48, 64, 64);
        rrect(144, 48, 64, 64);
        rrect(48, 144, 64, 64);
        rrect(144, 144, 64, 64);
      case AppIconKind.plusCircle:
        canvas.drawCircle(const Offset(128, 128), 96, p);
        line(88, 128, 168, 128);
        line(128, 88, 128, 168);
      case AppIconKind.plus:
        line(40, 128, 216, 128);
        line(128, 40, 128, 216);
      case AppIconKind.minus:
        line(40, 128, 216, 128);
      case AppIconKind.check:
        poly([40, 144, 96, 200, 224, 72]);
      case AppIconKind.pencil:
        final path = Path()
          ..moveTo(92.7, 216)
          ..lineTo(48, 216)
          ..arcToPoint(const Offset(40, 208), radius: const Radius.circular(8))
          ..lineTo(40, 163.3)
          ..arcToPoint(const Offset(42.3, 157.7), radius: const Radius.circular(8))
          ..lineTo(162.3, 37.7)
          ..arcToPoint(const Offset(173.7, 37.7), radius: const Radius.circular(8))
          ..lineTo(218.3, 82.3)
          ..arcToPoint(const Offset(218.3, 93.7), radius: const Radius.circular(8))
          ..close();
        canvas.drawPath(path, p);
        line(136, 64, 192, 120);
      case AppIconKind.caretLeft:
        poly([160, 208, 80, 128, 160, 48]);
      case AppIconKind.caretRight:
        poly([96, 48, 176, 128, 96, 208]);
      case AppIconKind.database:
        canvas.drawOval(Rect.fromCenter(center: const Offset(128, 80), width: 176, height: 80), p);
        line(40, 80, 40, 176);
        line(216, 80, 216, 176);
        canvas.drawArc(Rect.fromCenter(center: const Offset(128, 128), width: 176, height: 80),
            0, 3.14159, false, p);
        canvas.drawArc(Rect.fromCenter(center: const Offset(128, 176), width: 176, height: 80),
            0, 3.14159, false, p);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.kind != kind || old.color != color;
}
