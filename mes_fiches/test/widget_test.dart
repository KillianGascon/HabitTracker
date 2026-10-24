import 'package:flutter_test/flutter_test.dart';
import 'package:mes_fiches/logic.dart';
import 'package:mes_fiches/models.dart';

Habit habit(Period p, int target, {String created = '2026-01-01'}) => Habit(
      id: 'h',
      name: 'Test',
      emoji: '✨',
      period: p,
      target: target,
      created: created,
    );

void main() {
  test('les semaines vont du lundi au dimanche', () {
    final wed = DateTime(2026, 10, 21);
    expect(dateKey(periodStart(Period.week, wed)), '2026-10-19');
    expect(dateKey(periodEnd(Period.week, wed)), '2026-10-25');
    expect(dateKey(periodEnd(Period.month, DateTime(2026, 2, 10))), '2026-02-28');
  });

  test('compteur de période hebdo', () {
    final h = habit(Period.week, 2);
    final log = {'2026-10-19': 1, '2026-10-24': 1, '2026-10-18': 3};
    expect(periodCount(h, log, DateTime(2026, 10, 21)), 2);
  });

  test('série en cours : la période actuelle non faite ne casse pas la série', () {
    final h = habit(Period.day, 1, created: '2026-10-15');
    final today = DateTime(2026, 10, 21);
    final log = {'2026-10-18': 1, '2026-10-19': 1, '2026-10-20': 1, '2026-10-16': 1};
    final st = computeStats(h, log, today);
    expect(st.current, 3);
    expect(st.best, 3);
    expect(st.total, 4);

    final st2 = computeStats(h, {...log, '2026-10-21': 1}, today);
    expect(st2.current, 4);
  });

  test('série mensuelle', () {
    final h = habit(Period.month, 1, created: '2026-06-01');
    final st = computeStats(h, {'2026-08-05': 1, '2026-09-05': 1}, DateTime(2026, 10, 21));
    expect(st.current, 2);
    expect(st.best, 2);
  });

  test('niveaux de grille', () {
    final h = habit(Period.day, 3);
    final st = computeStats(h, {'2026-10-20': 3}, DateTime(2026, 10, 21));
    expect(habitLevel(h, st, {'2026-10-20': 3}, DateTime(2026, 10, 20)), 4);
    expect(habitLevel(h, st, {'2026-10-20': 1}, DateTime(2026, 10, 20)), 2);
    expect(habitLevel(h, st, {}, DateTime(2026, 10, 20)), 0);
  });
}
