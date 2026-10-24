import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Verre liquide : le contenu derrière [child] est réfracté par un shader
/// (bords qui font lentille, aberration chromatique, reflet).
/// Sans Impeller, repli sur un simple flou.
class LiquidGlass extends StatefulWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    required this.dark,
    this.radius = 28,
    this.bevel = 24,
    this.strength = 16,
    this.blur = 4,
  });

  final Widget child;
  final bool dark;

  /// Rayon des coins, largeur de la zone qui réfracte, déplacement maximal
  /// et rayon du flou (pt).
  final double radius, bevel, strength, blur;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  static Future<ui.FragmentProgram>? _program;

  ui.FragmentShader? _shader;

  /// Position de la barre à l'écran, en pixels physiques.
  Rect? _rect;

  /// Impeller (Flutter 3.29) peut planter si le filtre shader est appliqué
  /// pendant que la surface d'affichage est (re)créée : on ne l'active
  /// qu'une fois l'appli affichée et stable, flou classique en attendant.
  bool _ready = false;
  Timer? _readyTimer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: _armSoon,
      onHide: () => setState(() {
        _readyTimer?.cancel();
        _ready = false;
      }),
    );
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    _program ??= ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    _program!.then((p) {
      if (!mounted) return;
      setState(() => _shader = p.fragmentShader());
      _armSoon();
    }, onError: (_) {});
  }

  void _armSoon() {
    _readyTimer?.cancel();
    _readyTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    _lifecycle.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final o = box.localToGlobal(Offset.zero);
    final r = Rect.fromLTWH(o.dx * dpr, o.dy * dpr, box.size.width * dpr, box.size.height * dpr);
    if (r != _rect) setState(() => _rect = r);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final shader = _shader;
    final rect = _rect;

    final ui.ImageFilter filter;
    if (_ready && shader != null && rect != null && !rect.isEmpty) {
      shader
        ..setFloat(0, 0) // uSize : fourni par le moteur
        ..setFloat(1, 0)
        ..setFloat(2, rect.left)
        ..setFloat(3, rect.top)
        ..setFloat(4, rect.width)
        ..setFloat(5, rect.height)
        ..setFloat(6, widget.radius * dpr)
        ..setFloat(7, widget.bevel * dpr)
        ..setFloat(8, widget.strength * dpr)
        ..setFloat(9, widget.dark ? 1 : 0)
        ..setFloat(10, widget.blur * dpr);
      filter = ui.ImageFilter.shader(shader);
    } else {
      filter = ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: BackdropFilter(filter: filter, child: widget.child),
    );
  }
}
