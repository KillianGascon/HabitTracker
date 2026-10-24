import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens du thème violet « Mes fiches ».
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.ink,
    required this.muted,
    required this.card,
    required this.cardInk,
    required this.cardMuted,
    required this.cardAccent,
    required this.rule,
    required this.seg,
    required this.ruled,
    required this.line,
    required this.red,
    required this.progress,
    required this.progressDeep,
    required this.doneBg,
    required this.doneInk,
    required this.doneInkBg,
    required this.accent,
    required this.tabBg,
    required this.level1,
    required this.level2,
  });

  final Color bg, ink, muted;
  final Color card, cardInk, cardMuted, cardAccent;
  final Color rule, seg, ruled;

  /// Ligne sous les titres des fiches.
  final Color line;

  /// Réservé à la suppression et aux erreurs.
  final Color red;
  final Color progress, progressDeep, doneBg, doneInk, doneInkBg;
  final Color accent, tabBg;
  final Color level1, level2;

  /// Couleurs des niveaux 0 à 4 des grilles.
  List<Color> get levels => [seg, level1, level2, progress, progressDeep];

  static const light = Palette(
    bg: Color(0xFFF1ECFB),
    ink: Color(0xFF241A3D),
    muted: Color(0xFF6B6087),
    card: Color(0xFFFDFBFF),
    cardInk: Color(0xFF241A3D),
    cardMuted: Color(0xFF6B6087),
    cardAccent: Color(0xFF7C4DDB),
    rule: Color(0xFFDDD3F3),
    seg: Color(0xFFEDE6FB),
    ruled: Color(0xFFE6DEF7),
    line: Color(0xFFA67CEB),
    red: Color(0xFFD9433F),
    progress: Color(0xFF7C4DDB),
    progressDeep: Color(0xFF45238F),
    doneBg: Color(0xFFEEE5FF),
    doneInk: Color(0xFF5B33B8),
    doneInkBg: Color(0xFF5B33B8),
    accent: Color(0xFF7C4DDB),
    tabBg: Color(0xFFFDFBFF),
    level1: Color(0xFFD3C2F8),
    level2: Color(0xFFA784EE),
  );

  static const dark = Palette(
    bg: Color(0xFF140F24),
    ink: Color(0xFFEFEAFB),
    muted: Color(0xFFA59CC4),
    card: Color(0xFF221A38),
    cardInk: Color(0xFFEFEAFB),
    cardMuted: Color(0xFFA59CC4),
    cardAccent: Color(0xFFB596FF),
    rule: Color(0xFF3B305A),
    seg: Color(0xFF30274D),
    ruled: Color(0xFF2E2547),
    line: Color(0xFF8E62E6),
    red: Color(0xFFF0605B),
    progress: Color(0xFF9C6CFF),
    progressDeep: Color(0xFFD4BFFF),
    doneBg: Color(0xFF332459),
    doneInk: Color(0xFFD4BFFF),
    doneInkBg: Color(0xFFC4A8FF),
    accent: Color(0xFFB596FF),
    tabBg: Color(0xFF1A1430),
    level1: Color(0xFF47367A),
    level2: Color(0xFF6D4FC4),
  );

  static Palette of(BuildContext context) => Theme.of(context).extension<Palette>()!;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < .5 || other == null ? this : other;
}

ThemeData buildTheme(Palette p, Brightness b) {
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: b),
  );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.cardAccent,
      selectionColor: p.cardAccent.withValues(alpha: .25),
      selectionHandleColor: p.cardAccent,
    ),
  );
}

const tabular = [FontFeature.tabularFigures()];

/// Ombre des fiches : contour 1 pt + ombre douce.
List<BoxShadow> cardShadow(Color ring) => [
      BoxShadow(color: ring, spreadRadius: 1),
      const BoxShadow(color: Color(0x14000000), offset: Offset(0, 2), blurRadius: 6),
    ];
