import 'package:flutter/material.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import 'day_sheet.dart';
import 'api_settings_sheet.dart';
import 'habit_form_sheet.dart';
import 'today_screen.dart' show ScreenHeader;

class SuiviScreen extends StatefulWidget {
  const SuiviScreen({super.key});

  @override
  State<SuiviScreen> createState() => _SuiviScreenState();
}

class _SuiviScreenState extends State<SuiviScreen> {
  /// Jour dont la feuille « Modifier le jour » est ouverte (anneau sur la case).
  DateTime? _openDay;

  Future<void> _openDaySheet(DateTime d) async {
    setState(() => _openDay = d);
    await openDaySheet(context, d);
    if (mounted) setState(() => _openDay = null);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);

    return LayoutBuilder(builder: (context, c) {
      // Largeur dispo pour la grille globale : page 18×2, fiche 14×2, libellés 20 + 3.
      final avail = c.maxWidth - 36 - 28 - 23;
      final weeks = ((avail + 3) / 17).floor().clamp(14, 30);
      final first = addDays(periodStart(Period.week, store.today), -7 * (weeks - 1));
      DateTime dayAt(int i) => addDays(first, i);
      bool isFuture(int i) => dayAt(i).isAfter(store.today);
      int? sel;
      for (var i = 0; _openDay != null && i < weeks * 7; i++) {
        if (sameDay(dayAt(i), _openDay!)) sel = i;
      }

      final grid = _GridSpec(weeks, first, dayAt, isFuture, sel, _openDaySheet);

      final sections = <Widget>[
        ScreenHeader(
          overline: '$weeks dernières semaines',
          title: 'Suivi',
          trailing: _DbButton(status: store.status),
        ),
        _GlobalCard(grid: grid),
        if (store.habits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rien à suivre pour l’instant. Chaque habitude aura ici sa propre grille.',
                  style: TextStyle(fontSize: 15, color: p.muted)),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => openHabitForm(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.accent,
                  side: BorderSide(color: p.accent),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Créer une habitude',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
        for (final per in Period.values)
          if (store.habits.any((h) => h.period == per))
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(per.groupLabel,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.ink)),
                ),
                for (final h in store.habits.where((h) => h.period == per)) ...[
                  const SizedBox(height: 10),
                  _HabitTrackCard(habit: h, grid: grid),
                ],
              ],
            ),
      ];

      return ListView.separated(
        padding: EdgeInsets.fromLTRB(18, 8, 18, 28 + MediaQuery.paddingOf(context).bottom),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 22),
        itemBuilder: (_, i) => sections[i],
      );
    });
  }
}

class _GridSpec {
  _GridSpec(this.weeks, this.first, this.dayAt, this.isFuture, this.selected, this.open);
  final int weeks;
  final DateTime first;
  final DateTime Function(int) dayAt;
  final bool Function(int) isFuture;
  final int? selected;
  final void Function(DateTime) open;
}

class _DbButton extends StatelessWidget {
  const _DbButton({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dot = switch (status) {
      SyncStatus.synced => p.progress,
      SyncStatus.offline => p.red,
      SyncStatus.syncing => p.accent,
      SyncStatus.notConfigured => null,
    };
    return Semantics(
      button: true,
      label: 'Synchronisation',
      child: InkResponse(
        onTap: () => openApiSettings(context),
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(alignment: Alignment.center, children: [
            AppIcon(AppIconKind.database, size: 22, color: p.muted),
            if (dot != null)
              Positioned(
                right: 8,
                top: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.bg, width: 1.5),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _GlobalCard extends StatelessWidget {
  const _GlobalCard({required this.grid});
  final _GridSpec grid;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    const labelW = 20.0, gap = 3.0;

    // Stats globales : jours actifs sur 30 jours, total de coches.
    var active = 0;
    for (var k = 0; k < 30; k++) {
      final key = dateKey(addDays(store.today, -k));
      if (store.logs.values.any((l) => (l[key] ?? 0) > 0)) active++;
    }
    final total = store.logs.values.fold<int>(0, (s, l) => s + l.values.fold<int>(0, (a, b) => a + b));

    return BristolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitleRow(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              Expanded(
                child: Text('Toutes les habitudes',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: p.cardInk)),
              ),
              Text('Touchez un jour', style: TextStyle(fontSize: 12, color: p.cardMuted)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(builder: (context, c) {
                  final cell = (c.maxWidth - labelW - gap * grid.weeks) / grid.weeks;
                  final rowStyle = TextStyle(fontSize: 9, color: p.cardMuted);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 13,
                        child: Stack(clipBehavior: Clip.none, children: [
                          for (var w = 0; w < grid.weeks; w++)
                            if (_monthLabel(w) case final m?)
                              Positioned(
                                left: labelW + gap + w * (cell + gap),
                                top: 0,
                                child: Text(m,
                                    softWrap: false,
                                    style: TextStyle(fontSize: 10, color: p.cardMuted)),
                              ),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: labelW,
                            height: cell * 7 + gap * 6,
                            child: Stack(children: [
                              for (final (row, l) in [(0, 'lun'), (2, 'mer'), (4, 'ven')])
                                Positioned(
                                  top: row * (cell + gap),
                                  height: cell,
                                  left: 0,
                                  child: Center(child: Text(l, style: rowStyle)),
                                ),
                            ]),
                          ),
                          const SizedBox(width: gap),
                          Expanded(
                            child: HeatGrid(
                              columns: grid.weeks,
                              isFuture: grid.isFuture,
                              selected: grid.selected,
                              levelAt: (i) => globalLevel(store.habits, store.logs, grid.dayAt(i)),
                              onTapCell: (i) => grid.open(grid.dayAt(i)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _Stat(label: 'Jours actifs (30 j)', value: '$active')),
                  Expanded(child: _Stat(label: 'Total de coches', value: '$total')),
                ]),
                const SizedBox(height: 12),
                const GridLegend(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _monthLabel(int w) {
    DateTime? firstOfMonth(int col) {
      for (var r = 0; r < 7; r++) {
        final d = grid.dayAt(col * 7 + r);
        if (d.day == 1) return d;
      }
      return null;
    }

    final f = firstOfMonth(w);
    if (f != null) return monthShort(f);
    // Première colonne : mois en cours, sauf si un repère arrive juste après.
    if (w == 0 && firstOfMonth(1) == null && firstOfMonth(2) == null) {
      return monthShort(grid.dayAt(0));
    }
    return null;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.cardMuted)),
        const SizedBox(height: 2),
        Text(value,
            maxLines: 1,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: p.cardInk, fontFeatures: tabular)),
      ],
    );
  }
}

class _HabitTrackCard extends StatelessWidget {
  const _HabitTrackCard({required this.habit, required this.grid});
  final Habit habit;
  final _GridSpec grid;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final h = habit;
    final st = store.statsOf(h);
    final log = store.logOf(h);
    final u = h.period.unit;

    return BristolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'Modifier l’habitude ${h.name}',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => openHabitForm(context, habit: h),
              child: CardTitleRow(children: [
                Text(h.emoji, style: const TextStyle(fontSize: 22, height: 1)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(h.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: p.cardInk)),
                ),
                const SizedBox(width: 10),
                Text(h.frequency, style: TextStyle(fontSize: 12, color: p.cardMuted)),
                const SizedBox(width: 10),
                AppIcon(AppIconKind.pencil, size: 16, color: p.cardMuted),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(child: _Stat(label: 'Série en cours', value: '${st.current} $u')),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(label: 'Meilleure série', value: '${st.best} $u')),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(label: 'Total', value: '${st.total}')),
                ]),
                const SizedBox(height: 12),
                HeatGrid(
                  columns: grid.weeks,
                  radius: 2,
                  isFuture: grid.isFuture,
                  selected: grid.selected,
                  levelAt: (i) => habitLevel(h, st, log, grid.dayAt(i)),
                  onTapCell: (i) => grid.open(grid.dayAt(i)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
