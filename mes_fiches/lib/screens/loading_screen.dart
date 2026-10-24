import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../widgets/app_logo.dart';

/// Écran de chargement : prend le relais de l'écran de démarrage natif (même
/// fond, même logo au même endroit) pendant que l'appli charge ses données.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  /// Mêmes couleurs que `android/.../values(-night)/colors.xml`.
  static const lightBackground = Color(0xFF7C4DDB);
  static const darkBackground = Color(0xFF140F24);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: const Color(0x00000000),
        systemNavigationBarColor: dark ? LoadingScreen.darkBackground : LoadingScreen.lightBackground,
      ),
      child: ColoredBox(
        color: dark ? LoadingScreen.darkBackground : LoadingScreen.lightBackground,
        child: Semantics(
          label: 'Chargement de Mes fiches',
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Le logo reste exactement au centre, comme sur l'écran natif.
              AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => Transform.scale(
                  scale: reduceMotion ? 1 : 1 + 0.03 * math.sin(_controller.value * 2 * math.pi),
                  child: child,
                ),
                child: const AppLogo(),
              ),
              Transform.translate(
                offset: const Offset(0, 96),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Mes fiches',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        letterSpacing: .2,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Dots(controller: _controller, still: reduceMotion),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trois points qui s'allument tour à tour.
class _Dots extends StatelessWidget {
  const _Dots({required this.controller, required this.still});

  final AnimationController controller;
  final bool still;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFFFFF).withValues(alpha: still ? .7 : _alpha(i)),
                ),
              ),
            ],
          ],
        ),
      );

  double _alpha(int i) {
    final t = (controller.value - i / 3) % 1;
    return .3 + .7 * math.max(0, math.sin(t * math.pi));
  }
}
