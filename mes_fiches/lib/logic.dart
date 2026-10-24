import 'dart:math' as math;

import 'models.dart';

// ---------------------------------------------------------------------------
// Dates locales (jamais d'UTC) : clés `YYYY-MM-DD`.
// ---------------------------------------------------------------------------

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Ajoute des jours calendaires (insensible aux changements d'heure).
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

String _two(int n) => n.toString().padLeft(2, '0');

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime periodStart(Period p, DateTime d) => switch (p) {
      Period.day => dateOnly(d),
      Period.week => addDays(d, -(d.weekday - 1)),
      Period.month => DateTime(d.year, d.month, 1),
    };

DateTime periodEnd(Period p, DateTime d) => switch (p) {
      Period.day => dateOnly(d),
      Period.week => addDays(periodStart(p, d), 6),
      Period.month => DateTime(d.year, d.month + 1, 0),
    };

DateTime nextPeriod(Period p, DateTime start) => switch (p) {
      Period.day => addDays(start, 1),
      Period.week => addDays(start, 7),
      Period.month => DateTime(start.year, start.month + 1, 1),
    };

DateTime previousPeriod(Period p, DateTime start) => switch (p) {
      Period.day => addDays(start, -1),
      Period.week => addDays(start, -7),
      Period.month => DateTime(start.year, start.month - 1, 1),
    };

String periodKey(Period p, DateTime d) => dateKey(periodStart(p, d));

// ---------------------------------------------------------------------------
// Libellés français
// ---------------------------------------------------------------------------

const _dayLong = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche', //
];
const _dayShort = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
const _monthLong = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', //
  'septembre', 'octobre', 'novembre', 'décembre',
];
const _monthShort = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', //
  'sept.', 'oct.', 'nov.', 'déc.',
];

String dayLong(DateTime d) => _dayLong[d.weekday - 1];
String dayShort(DateTime d) => _dayShort[d.weekday - 1];
String monthShort(DateTime d) => _monthShort[d.month - 1];

/// « Mardi 21 octobre »
String fullDate(DateTime d) => '${dayLong(d)} ${d.day} ${_monthLong[d.month - 1]}';

// ---------------------------------------------------------------------------
// Statistiques
// ---------------------------------------------------------------------------

/// Somme des logs d'une habitude sur la période qui contient [d].
int periodCount(Habit h, Map<String, int>? log, DateTime d) {
  if (log == null || log.isEmpty) return 0;
  if (h.period == Period.day) return log[dateKey(d)] ?? 0;
  final start = periodStart(h.period, d);
  final end = periodEnd(h.period, d);
  var sum = 0;
  for (var day = start; !day.isAfter(end); day = addDays(day, 1)) {
    sum += log[dateKey(day)] ?? 0;
  }
  return sum;
}

class HabitStats {
  const HabitStats(this.current, this.best, this.total, this.periodSums);

  /// Série en cours, en périodes.
  final int current;

  /// Meilleure série depuis la création.
  final int best;

  /// Somme de tous les logs.
  final int total;

  /// Somme par période, clé = début de période `YYYY-MM-DD`.
  final Map<String, int> periodSums;

  bool achieved(Habit h, DateTime d) =>
      (periodSums[periodKey(h.period, d)] ?? 0) >= h.target;
}

HabitStats computeStats(Habit h, Map<String, int>? log, DateTime today) {
  final sums = <String, int>{};
  var total = 0;
  var start = parseKey(h.created);
  log?.forEach((k, v) {
    final d = parseKey(k);
    if (d.isAfter(today)) return;
    total += v;
    final pk = periodKey(h.period, d);
    sums[pk] = (sums[pk] ?? 0) + v;
    if (d.isBefore(start)) start = d;
  });
  if (start.isAfter(today)) start = today;

  bool done(DateTime p) => (sums[dateKey(p)] ?? 0) >= h.target;

  final first = periodStart(h.period, start);
  final current = periodStart(h.period, today);

  // Meilleure série : la période en cours non terminée ne casse rien.
  var best = 0, run = 0;
  for (var p = first; !p.isAfter(current); p = nextPeriod(h.period, p)) {
    if (done(p)) {
      run++;
      best = math.max(best, run);
    } else if (!p.isAtSameMomentAs(current)) {
      run = 0;
    }
  }

  // Série en cours : si la période actuelle n'est pas faite, on part de la précédente.
  var streak = 0;
  var p = current;
  if (!done(p)) p = previousPeriod(h.period, p);
  while (!p.isBefore(first) && done(p)) {
    streak++;
    p = previousPeriod(h.period, p);
  }

  return HabitStats(streak, best, total, sums);
}

// ---------------------------------------------------------------------------
// Intensité des grilles (0 à 4)
// ---------------------------------------------------------------------------

int habitLevel(Habit h, HabitStats st, Map<String, int>? log, DateTime d) {
  final v = log?[dateKey(d)] ?? 0;
  if (h.period == Period.day) {
    if (v == 0) return 0;
    return math.min(4, (1 + 3 * v / h.target).round());
  }
  if (v > 0) return 4;
  return st.achieved(h, d) ? 1 : 0;
}

/// Niveau global d'un jour : part des objectifs quotidiens atteints,
/// + 0,25 par habitude hebdo/mensuelle cochée ce jour-là, plafonné à 1.
int globalLevel(List<Habit> habits, Logs logs, DateTime d) {
  final key = dateKey(d);
  var done = 0, goals = 0;
  var bonus = 0.0;
  for (final h in habits) {
    final v = logs[h.id]?[key] ?? 0;
    if (h.period == Period.day) {
      goals += h.target;
      done += math.min(v, h.target);
    } else if (v > 0) {
      bonus += 0.25;
    }
  }
  final ratio = math.min(1.0, (goals == 0 ? 0.0 : done / goals) + bonus);
  if (ratio <= 0) return 0;
  return math.max(1, (4 * ratio).round());
}

/// Toutes les habitudes quotidiennes atteintes ce jour-là (pastille de la bande).
bool allDailyDone(List<Habit> habits, Logs logs, DateTime d) {
  final daily = habits.where((h) => h.period == Period.day);
  if (daily.isEmpty) return false;
  final key = dateKey(d);
  return daily.every((h) => (logs[h.id]?[key] ?? 0) >= h.target);
}
