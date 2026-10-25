import 'package:flutter/widgets.dart';

/// Logo « Mes fiches » : fiche blanche, ligne violette, coche.
/// Même dessin que `android/.../drawable/ic_logo.xml` (grille 108 × 108),
/// pour enchaîner sans saut l'écran de démarrage natif et le loader.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 216});

  /// Taille de la grille complète ; la fiche en occupe le centre.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 108);
    canvas.drawRRect(
      RRect.fromLTRBR(33, 30, 75, 78, const Radius.circular(5)),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawRect(const Rect.fromLTRB(33, 42, 75, 43.6), Paint()..color = const Color(0xFFA67CEB));
    canvas.drawPath(
      Path()
        ..moveTo(42, 59)
        ..lineTo(50.5, 67.5)
        ..lineTo(66, 51),
      Paint()
        ..color = const Color(0xFF7C4DDB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
