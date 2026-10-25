import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import 'habit_form_sheet.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final day = store.selectedDay;
    final title = store.isToday
        ? 'Aujourd’hui'
        : sameDay(day, addDays(store.today, -1))
            ? 'Hier'
            : dayLong(day);

    final sections = <Widget>[
      ScreenHeader(
        overline: fullDate(day),
        title: title,
        trailing: store.isToday
            ? null
            : TextButton(
                onPressed: () => store.selectDay(store.today),
                style: TextButton.styleFrom(
                  foregroundColor: p.accent,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(44, 44),
                ),
                child: const Text('Revenir à aujourd’hui', style: TextStyle(fontSize: 13)),
              ),
      ),
      if (store.habits.isEmpty)
        const Padding(padding: EdgeInsets.only(top: 6), child: _EmptyCard())
      else ...[
        const _WeekStrip(),
        if (store.categories.isNotEmpty) const _CategoryBar(),
        for (final per in Period.values)
          if (store.visibleHabits.any((h) => h.period == per)) _Group(period: per),
        Text(
          'Touchez une fiche pour cocher une fois · appui long pour la modifier',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: p.muted),
        ),
      ],
    ];

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(18, 8, 18, 28 + MediaQuery.paddingOf(context).bottom),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 22),
      itemBuilder: (_, i) => sections[i],
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.overline, required this.title, this.trailing});

  final String overline, title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline.toUpperCase(),
          style: TextStyle(fontSize: 12, letterSpacing: .96, color: p.muted),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: p.ink, height: 1.2),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bande de 7 jours (lundi → dimanche de la semaine sélectionnée)
// ---------------------------------------------------------------------------

class _WeekStrip extends StatelessWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final start = periodStart(Period.week, store.selectedDay);
    final canNext = !addDays(start, 7).isAfter(store.today);

    void prevWeek() => store.selectDay(addDays(store.selectedDay, -7));
    void nextWeek() {
      if (canNext) store.selectDay(addDays(store.selectedDay, 7));
    }

    Widget arrow(AppIconKind icon, String label, VoidCallback? onTap) => Semantics(
          button: true,
          label: label,
          child: InkResponse(
            onTap: onTap,
            radius: 22,
            child: SizedBox(
              width: 28,
              height: 64,
              child: Center(
                child: Opacity(
                  opacity: onTap == null ? .3 : 1,
                  child: AppIcon(icon, size: 18, color: p.muted),
                ),
              ),
            ),
          ),
        );

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 200) prevWeek();
        if (v < -200) nextWeek();
      },
      child: Row(
        children: [
          arrow(AppIconKind.caretLeft, 'Semaine précédente', prevWeek),
          for (var k = 0; k < 7; k++) ...[
            if (k > 0) const SizedBox(width: 5),
            Expanded(child: _DayChip(day: addDays(start, k))),
          ],
          arrow(AppIconKind.caretRight, 'Semaine suivante', canNext ? nextWeek : null),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final selected = sameDay(day, store.selectedDay);
    final future = day.isAfter(store.today);
    final all = !future && allDailyDone(store.habits, store.logs, day);
    final ink = selected ? p.cardInk : p.ink;

    return Semantics(
      button: true,
      selected: selected,
      enabled: !future,
      label: fullDate(day),
      excludeSemantics: true,
      child: Opacity(
        opacity: future ? .35 : 1,
        child: Material(
          color: selected ? p.card : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: selected ? p.rule : Colors.transparent),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: future ? null : () => store.selectDay(day),
            child: SizedBox(
              height: 64,
              child: Stack(
                children: [
                  if (selected)
                    Positioned(left: 0, right: 0, top: 14, child: Container(height: 1, color: p.line)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(dayShort(day),
                            style: TextStyle(fontSize: 11, color: ink.withValues(alpha: .7))),
                        const SizedBox(height: 3),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: ink,
                            fontFeatures: tabular,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: all ? p.progress : Colors.transparent,
                            border: Border.all(color: all ? p.progress : p.muted, width: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filtre par catégorie
// ---------------------------------------------------------------------------

class _CategoryBar extends StatelessWidget {
  const _CategoryBar();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final current = store.category;

    Widget chip(String label, String? value) {
      final sel = value == current;
      return Semantics(
        button: true,
        selected: sel,
        child: Material(
          color: sel ? p.accent : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: sel ? p.accent : p.muted.withValues(alpha: .45)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              store.selectCategory(value);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: sel ? Colors.white : p.ink,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          chip('Toutes', null),
          for (final c in store.categories) ...[
            const SizedBox(width: 8),
            chip(categoryLabel(c), c),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Groupes et fiches
// ---------------------------------------------------------------------------

class _Group extends StatelessWidget {
  const _Group({required this.period});
  final Period period;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final items = store.visibleHabits.where((h) => h.period == period).toList();
    final done = items.where((h) => store.periodCountOf(h, store.selectedDay) >= h.target).length;
    final all = done == items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(period.groupLabel,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.ink)),
              ),
              Text(
                '$done/${items.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFeatures: tabular,
                  color: all ? p.doneInkBg : p.muted,
                ),
              ),
            ],
          ),
        ),
        for (final h in items) ...[
          const SizedBox(height: 10),
          HabitCard(habit: h),
        ],
      ],
    );
  }
}

class HabitCard extends StatefulWidget {
  const HabitCard({super.key, required this.habit});
  final Habit habit;

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard> {
  bool _pressed = false;

  void _plus(HabitStore store) {
    final h = widget.habit;
    final r = store.plus(h);
    if (!r.changed) return;
    if (r.justCompleted) {
      HapticFeedback.mediumImpact();
      final messenger = ScaffoldMessenger.of(context);
      final p = Palette.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: p.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        content: Text(
          r.streak > 1 ? 'Fait ! Série de ${r.streak} ${h.period.unit}' : 'Fait !',
          style: TextStyle(color: p.bg, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ));
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    final h = widget.habit;
    final count = store.periodCountOf(h, store.selectedDay).clamp(0, h.target);
    final done = count >= h.target;
    final streak = store.statsOf(h).current;

    return Semantics(
      button: true,
      label: '${h.name}, ${h.frequency}, $count sur ${h.target}${done ? ', fait' : ''}',
      hint: 'Touchez pour cocher une fois, appui long pour modifier',
      onLongPressHint: 'Modifier',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () => _plus(store),
        onLongPress: () {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          openHabitForm(context, habit: h);
        },
        child: AnimatedScale(
          scale: _pressed ? .99 : 1,
          duration: const Duration(milliseconds: 100),
          child: BristolCard(
            color: done ? p.doneBg : p.card,
            ring: done ? p.progress : p.rule,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitleRow(children: [
                  Text(h.emoji, style: const TextStyle(fontSize: 22, height: 1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      h.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: p.cardInk),
                    ),
                  ),
                  if (done)
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: p.progress, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: AppIcon(AppIconKind.check, size: 14, color: p.doneBg),
                    )
                  else
                    const SizedBox(height: 26),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DefaultTextStyle(
                              style: TextStyle(fontSize: 13, color: p.cardMuted),
                              maxLines: 1,
                              child: Row(children: [
                                Flexible(child: Text(h.frequency, overflow: TextOverflow.ellipsis)),
                                if (streak > 0) ...[
                                  const SizedBox(width: 12),
                                  Text('🔥 $streak ${h.period.unit}'),
                                ],
                              ]),
                            ),
                            const SizedBox(height: 9),
                            Segments(total: h.target, filled: count),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SquareButton(
                        icon: AppIconKind.minus,
                        label: 'Retirer une fois',
                        borderColor: p.rule,
                        dimmed: count == 0,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          store.minus(h);
                        },
                      ),
                      const SizedBox(width: 10),
                      SquareButton(
                        icon: AppIconKind.plus,
                        label: 'Ajouter une fois',
                        borderColor: p.cardInk,
                        onTap: () => _plus(store),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// État vide
// ---------------------------------------------------------------------------

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = Palette.of(context);
    return BristolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitleRow(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            children: [
              Text('Votre première fiche',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: p.cardInk)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'La table est vide. Notez ce que vous voulez faire chaque jour, '
                  'chaque semaine ou chaque mois, comme sur vos fiches papier.',
                  style: TextStyle(fontSize: 15, height: 28 / 15, color: p.cardInk),
                ),
                const SizedBox(height: 20),
                OutlineAction(
                  color: p.cardAccent,
                  onTap: () => openHabitForm(context),
                  child: Text('Créer ma première habitude',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.cardAccent)),
                ),
                const SizedBox(height: 8),
                OutlineAction(
                  color: p.rule,
                  onTap: store.loadExamples,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Charger des exemples', style: TextStyle(fontSize: 15, color: p.cardInk)),
                      Text('vaisselle, lessive, factures…',
                          style: TextStyle(fontSize: 11, color: p.cardMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
