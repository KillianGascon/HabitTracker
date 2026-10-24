import 'dart:async';

import 'package:flutter/widgets.dart';

import 'logic.dart';
import 'models.dart';
import 'storage/db_config.dart';
import 'storage/local_storage.dart';
import 'storage/postgres_storage.dart';

enum SyncStatus { notConfigured, syncing, synced, offline }

class PlusResult {
  const PlusResult(this.changed, this.justCompleted, this.streak);
  final bool changed;
  final bool justCompleted;
  final int streak;
}

/// État de l'appli. Toute modification est enregistrée en local puis
/// envoyée à PostgreSQL ; en cas d'échec, l'état local est marqué « à
/// renvoyer » et sera poussé en entier à la prochaine connexion réussie.
class HabitStore extends ChangeNotifier {
  HabitStore(this._local, this._remote) {
    final data = _local.load();
    habits = data.habits..sort((a, b) => a.position.compareTo(b.position));
    logs = data.logs;
    _remote.config = _local.loadDbConfig();
    status = _remote.configured ? SyncStatus.offline : SyncStatus.notConfigured;
  }

  final LocalStorage _local;
  final PostgresStorage _remote;

  List<Habit> habits = [];
  Logs logs = {};
  DateTime today = dateOnly(DateTime.now());
  late DateTime selectedDay = today;

  SyncStatus status = SyncStatus.notConfigured;
  String? syncError;
  DbConfig? get dbConfig => _remote.config;
  bool get pendingChanges => _local.dirty;

  Future<void> _queue = Future.value();

  // ------------------------------------------------------------------ dates

  bool get isToday => sameDay(selectedDay, today);

  void selectDay(DateTime d) {
    final day = dateOnly(d);
    selectedDay = day.isAfter(today) ? today : day;
    notifyListeners();
  }

  /// Au retour au premier plan : recalcule la date du jour et resynchronise.
  void onResume() {
    final now = dateOnly(DateTime.now());
    if (!sameDay(now, today)) {
      final wasToday = isToday;
      today = now;
      if (wasToday || selectedDay.isAfter(today)) selectedDay = today;
      notifyListeners();
    }
    unawaited(reconcile());
  }

  // ---------------------------------------------------------------- lecture

  Map<String, int>? logOf(Habit h) => logs[h.id];
  int countOn(Habit h, DateTime d) => logs[h.id]?[dateKey(d)] ?? 0;
  int periodCountOf(Habit h, DateTime d) => periodCount(h, logs[h.id], d);
  HabitStats statsOf(Habit h) => computeStats(h, logs[h.id], today);

  // ------------------------------------------------------------- écritures

  void _setCount(Habit h, DateTime d, int v) {
    if (d.isAfter(today)) return;
    final key = dateKey(d);
    final log = logs[h.id] ??= {};
    if (v <= 0) {
      log.remove(key);
      if (log.isEmpty) logs.remove(h.id);
    } else {
      log[key] = v;
    }
    _persist((r) => r.setLog(h.id, key, v < 0 ? 0 : v));
  }

  /// +1 sur le jour sélectionné, sans dépasser l'objectif de la période.
  PlusResult plus(Habit h, [DateTime? day]) {
    final d = day ?? selectedDay;
    if (periodCountOf(h, d) >= h.target) return const PlusResult(false, false, 0);
    _setCount(h, d, countOn(h, d) + 1);
    final completed = periodCountOf(h, d) >= h.target;
    return PlusResult(true, completed, completed ? statsOf(h).current : 0);
  }

  /// −1 sur le jour ; pour hebdo/mensuel, s'il n'y a rien ce jour-là, retire
  /// sur le dernier jour de la période qui en a.
  void minus(Habit h, [DateTime? day, bool searchPeriod = true]) {
    final d = day ?? selectedDay;
    final v = countOn(h, d);
    if (v > 0) return _setCount(h, d, v - 1);
    if (h.period == Period.day || !searchPeriod) return;
    final start = periodStart(h.period, d);
    var end = periodEnd(h.period, d);
    if (end.isAfter(today)) end = today;
    for (var j = end; !j.isBefore(start); j = addDays(j, -1)) {
      final c = countOn(h, j);
      if (c > 0) return _setCount(h, j, c - 1);
    }
  }

  void saveHabit({
    String? id,
    required String name,
    required String emoji,
    required Period period,
    required int target,
  }) {
    final t = target.clamp(1, period.maxTarget);
    final Habit h;
    if (id == null) {
      h = Habit(
        id: 'h${DateTime.now().millisecondsSinceEpoch}',
        name: name.trim(),
        emoji: emoji,
        period: period,
        target: t,
        created: dateKey(today),
        position: habits.isEmpty ? 0 : habits.last.position + 1,
      );
      habits = [...habits, h];
    } else {
      final old = habits.firstWhere((x) => x.id == id);
      h = old.copyWith(name: name.trim(), emoji: emoji, period: period, target: t);
      habits = [for (final x in habits) x.id == id ? h : x];
    }
    _persist((r) => r.upsertHabits([h]));
  }

  /// Supprime l'habitude et tout son historique.
  void deleteHabit(String id) {
    habits = habits.where((h) => h.id != id).toList();
    logs.remove(id);
    _persist((r) => r.deleteHabit(id));
  }

  void loadExamples() {
    final ex = exampleHabits(dateKey(today));
    habits = [...habits, ...ex];
    selectedDay = today;
    _persist((r) => r.upsertHabits(ex));
  }

  // --------------------------------------------------------------- synchro

  void _persist(Future<void> Function(PostgresStorage r) op) {
    notifyListeners();
    unawaited(_local.save(AppData(habits, logs)));
    if (!_remote.configured) return;
    _enqueue(() async {
      if (_local.dirty) return _pushAll();
      try {
        await op(_remote);
        _setStatus(SyncStatus.synced);
      } catch (e) {
        await _local.setDirty(true);
        _setStatus(SyncStatus.offline, e);
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.catchError((_) {});
    return _queue;
  }

  void _setStatus(SyncStatus s, [Object? error]) {
    status = s;
    syncError = error?.toString();
    notifyListeners();
  }

  Future<void> _pushAll() async {
    _setStatus(SyncStatus.syncing);
    try {
      await _remote.replaceAll(AppData(habits, logs));
      await _local.setDirty(false);
      _setStatus(SyncStatus.synced);
    } catch (e) {
      await _local.setDirty(true);
      _setStatus(SyncStatus.offline, e);
    }
  }

  /// Aligne local et base :
  /// - changements locaux en attente → la base est remplacée par l'état local ;
  /// - base vide et données locales → envoi des données locales ;
  /// - sinon la base fait foi.
  Future<void> reconcile() {
    if (!_remote.configured) return Future.value();
    return _enqueue(() async {
      if (_local.dirty) return _pushAll();
      _setStatus(SyncStatus.syncing);
      try {
        final remote = await _remote.fetchAll();
        if (remote.habits.isEmpty && habits.isNotEmpty) {
          await _remote.replaceAll(AppData(habits, logs));
        } else {
          habits = remote.habits;
          logs = remote.logs;
          await _local.save(remote);
        }
        _setStatus(SyncStatus.synced);
      } catch (e) {
        _setStatus(SyncStatus.offline, e);
      }
    });
  }

  /// Teste la connexion puis l'enregistre. Renvoie un message d'erreur ou null.
  Future<String?> configureDb(DbConfig? config) async {
    await _queue;
    await _remote.close();
    final previous = _remote.config;
    _remote.config = config;
    if (config == null) {
      await _local.saveDbConfig(null);
      await _local.setDirty(false);
      _setStatus(SyncStatus.notConfigured);
      return null;
    }
    try {
      await _remote.ping();
    } catch (e) {
      _remote.config = previous;
      _setStatus(previous == null ? SyncStatus.notConfigured : SyncStatus.offline, e);
      return e.toString();
    }
    await _local.saveDbConfig(config);
    await reconcile();
    return status == SyncStatus.synced ? null : syncError;
  }
}

/// Donne accès au store à tout l'arbre de widgets.
class StoreScope extends InheritedNotifier<HabitStore> {
  const StoreScope({super.key, required HabitStore store, required super.child})
      : super(notifier: store);

  static HabitStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static HabitStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
