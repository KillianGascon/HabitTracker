import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';

/// Feuille « Modifier le jour » ouverte depuis une case de grille.
Future<void> openDaySheet(BuildContext context, DateTime day) => showBristolSheet(
      context,
      builder: (_) => DaySheet(day: day),
    );

class DaySheet extends StatelessWidget {
  const DaySheet({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Modifier le jour', style: TextStyle(fontSize: 12, color: p.cardMuted)),
                const SizedBox(height: 1),
                Text(fullDate(day), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500)),
              ]),
            ),
            SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.cardAccent,
                  side: BorderSide(color: p.cardAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Terminé', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ),
          ]),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            children: [for (final h in store.habits) _row(context, store, p, h)],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, HabitStore store, Palette p, Habit h) {
    final v = store.countOn(h, day);
    final daily = h.period == Period.day;
    final done = daily && v >= h.target;
    final canPlus = store.periodCountOf(h, day) < h.target;
    final sub = daily
        ? (done ? 'Objectif atteint · $v/${h.target}' : '$v/${h.target} ce jour-là')
        : '${h.frequency} · ${store.periodCountOf(h, day)}/${h.target} sur la période';

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.ruled))),
      child: Row(children: [
        SizedBox(width: 28, child: Text(h.emoji, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            Text(sub, style: TextStyle(fontSize: 12, color: done ? p.doneInk : p.cardMuted)),
          ]),
        ),
        const SizedBox(width: 10),
        SquareButton(
          icon: AppIconKind.minus,
          iconSize: 16,
          label: 'Retirer une fois',
          borderColor: p.rule,
          dimmed: v == 0,
          onTap: () {
            HapticFeedback.selectionClick();
            store.minus(h, day, false);
          },
        ),
        SizedBox(
          width: 32,
          child: Text('$v',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, fontFeatures: tabular)),
        ),
        SquareButton(
          icon: AppIconKind.plus,
          iconSize: 16,
          label: 'Ajouter une fois',
          borderColor: p.cardInk,
          dimmed: !canPlus,
          onTap: () {
            HapticFeedback.selectionClick();
            store.plus(h, day);
          },
        ),
      ]),
    );
  }
}
