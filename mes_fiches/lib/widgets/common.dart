import 'package:flutter/material.dart';

import '../theme.dart';
import 'icons.dart';

/// Fiche bristol : fond carte, coins 4, contour + ombre.
class BristolCard extends StatelessWidget {
  const BristolCard({super.key, required this.child, this.color, this.ring});

  final Widget child;
  final Color? color;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: color ?? p.card,
        borderRadius: BorderRadius.circular(4),
        boxShadow: cardShadow(ring ?? p.rule),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(4), child: child),
    );
  }
}

/// Ligne de titre d'une fiche, soulignée par la ligne rouge bord à bord.
class CardTitleRow extends StatelessWidget {
  const CardTitleRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 10),
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        textBaseline: TextBaseline.alphabetic,
        children: children,
      ),
    );
  }
}

/// Bouton carré à contour (− / +), zone tactile ≥ 44.
class SquareButton extends StatelessWidget {
  const SquareButton({
    super.key,
    required this.icon,
    required this.borderColor,
    required this.onTap,
    required this.label,
    this.size = 44,
    this.iconSize = 18,
    this.dimmed = false,
  });

  final AppIconKind icon;
  final Color borderColor;
  final VoidCallback onTap;
  final String label;
  final double size, iconSize;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: dimmed ? .35 : 1,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AppIcon(icon, size: iconSize, color: p.cardInk),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre de progression : un segment par fois à faire, barre continue au-delà de 12.
class Segments extends StatelessWidget {
  const Segments({super.key, required this.total, required this.filled});

  final int total, filled;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    if (total > 12) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 8,
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: p.seg)),
            FractionallySizedBox(
              widthFactor: (filled / total).clamp(0, 1).toDouble(),
              child: ColoredBox(color: p.progress),
            ),
          ]),
        ),
      );
    }
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 8,
              decoration: BoxDecoration(
                color: i < filled ? p.progress : p.seg,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Bouton plein-largeur à contour (actions des feuilles et de l'état vide).
class OutlineAction extends StatelessWidget {
  const OutlineAction({
    super.key,
    required this.child,
    required this.color,
    required this.onTap,
    this.height = 50,
    this.enabled = true,
  });

  final Widget child;
  final Color color;
  final VoidCallback onTap;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: color),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          highlightColor: p.seg,
          child: SizedBox(height: height, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Feuille du bas façon fiche : poignée, coins 14, voile sombre.
Future<T?> showBristolSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxHeightFactor = .84,
}) {
  final p = Palette.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x730A0B12),
    elevation: 0,
    sheetAnimationStyle: AnimationStyle(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    ),
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * maxHeightFactor),
          child: Container(
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              boxShadow: const [
                BoxShadow(color: Color(0x59000000), offset: Offset(0, -12), blurRadius: 40),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: p.rule,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Flexible(child: DefaultTextStyle.merge(
                    style: TextStyle(color: p.cardInk),
                    child: builder(ctx),
                  )),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Grille façon contributions GitHub : colonnes = semaines, lignes = lun → dim.
class HeatGrid extends StatelessWidget {
  const HeatGrid({
    super.key,
    required this.columns,
    required this.levelAt,
    required this.isFuture,
    this.selected,
    this.onTapCell,
    this.radius = 3,
    this.gap = 3,
  });

  final int columns;
  final int Function(int index) levelAt;
  final bool Function(int index) isFuture;
  final int? selected;
  final void Function(int index)? onTapCell;
  final double radius, gap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (context, c) {
      final cell = (c.maxWidth - gap * (columns - 1)) / columns;
      final height = cell * 7 + gap * 6;
      final n = columns * 7;
      final levels = List.generate(n, (i) => isFuture(i) ? -1 : levelAt(i));
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onTapCell == null
            ? null
            : (d) {
                final col = (d.localPosition.dx / (cell + gap)).floor();
                final row = (d.localPosition.dy / (cell + gap)).floor();
                if (col < 0 || col >= columns || row < 0 || row > 6) return;
                final i = col * 7 + row;
                if (levels[i] >= 0) onTapCell!(i);
              },
        child: CustomPaint(
          size: Size(c.maxWidth, height),
          painter: _GridPainter(
            levels: levels,
            columns: columns,
            cell: cell,
            gap: gap,
            radius: radius,
            colors: p.levels,
            futureRing: p.seg,
            selectedRing: p.cardInk,
            selected: selected,
          ),
        ),
      );
    });
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.levels,
    required this.columns,
    required this.cell,
    required this.gap,
    required this.radius,
    required this.colors,
    required this.futureRing,
    required this.selectedRing,
    required this.selected,
  });

  final List<int> levels;
  final int columns;
  final double cell, gap, radius;
  final List<Color> colors;
  final Color futureRing, selectedRing;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = futureRing;
    for (var i = 0; i < levels.length; i++) {
      final col = i ~/ 7, row = i % 7;
      final rect = Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      if (levels[i] < 0) {
        canvas.drawRRect(rr.deflate(.5), ring);
      } else {
        fill.color = colors[levels[i]];
        canvas.drawRRect(rr, fill);
      }
      if (i == selected) {
        canvas.drawRRect(
          rr.inflate(1),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = selectedRing,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}

/// Légende « Moins ▢▢▢▢▢ Plus ».
class GridLegend extends StatelessWidget {
  const GridLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final style = TextStyle(fontSize: 11, color: p.cardMuted);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('Moins', style: style),
        const SizedBox(width: 8),
        for (final c in p.levels) ...[
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 4),
        Text('Plus', style: style),
      ],
    );
  }
}
