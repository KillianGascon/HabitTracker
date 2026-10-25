import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'logic.dart';
import 'models.dart';
import 'storage/api_client.dart';
import 'storage/api_config.dart';
import 'storage/local_storage.dart';
import 'storage/secret_store.dart';
import 'sync.dart';

enum SyncStatus { notConfigured, syncing, synced, offline }

class PlusResult {
  const PlusResult(this.changed, this.justCompleted, this.streak);
  final bool changed;
  final bool justCompleted;
  final int streak;
}

/// État de l'appli. Toute modification est enregistrée en local et notée
/// comme « à envoyer » ; la synchronisation avec l'API envoie ces changements
/// puis récupère ceux faits ailleurs. Hors connexion, rien n'est perdu : les
/// changements attendent la prochaine synchronisation réussie.
class HabitStore extends ChangeNotifier {
  HabitStore._(this._local, this._secrets, this._httpClient) {
    final data = _local.load();
    habits = data.habits..sort(_byPosition);
    logs = data.logs;
    _pending = _local.loadPending();
  }

  /// Charge l'état local et, si le téléphone est associé, prépare le client API.
  static Future<HabitStore> open(LocalStorage local, SecretStore secrets, {http.Client? httpClient}) async {
    final store = HabitStore._(local, secrets, httpClient);
    final config = local.loadApiConfig();
    final token = await secrets.read(_tokenKey);
    if (config != null && token != null) {
      store._api = ApiClient(
        config,
        cfClientSecret: await secrets.read(_cfSecretKey) ?? '',
        token: token,
        client: httpClient,
      );
      store.status = SyncStatus.offline;
    }
    return store;
  }

  static const _tokenKey = 'device_token';
  static const _cfSecretKey = 'cf_client_secret';

  final LocalStorage _local;
  final SecretStore _secrets;
  final http.Client? _httpClient;
  ApiClient? _api;
  late PendingChanges _pending;

  List<Habit> habits = [];
  Logs logs = {};
  DateTime today = dateOnly(DateTime.now());
  late DateTime selectedDay = today;

  SyncStatus status = SyncStatus.notConfigured;
  String? syncError;
  DateTime? lastSyncAt;
  ApiConfig? get apiConfig => _api?.config;
  int get pendingCount => _pending.habits.length + _pending.logs.length;

  Future<void> _queue = Future.value();
  Timer? _syncTimer;

  static int _byPosition(Habit a, Habit b) {
    final c = a.position.compareTo(b.position);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

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
    unawaited(sync());
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
    _pending.log(h.id, key, v < 0 ? 0 : v);
    _changed();
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
        id: _newId(),
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
    _pending.habit(h);
    _changed();
  }

  /// `h<millisecondes>`, sans reprendre un id existant (créations rapprochées).
  String _newId() {
    var n = DateTime.now().millisecondsSinceEpoch;
    while (habits.any((h) => h.id == 'h$n')) {
      n++;
    }
    return 'h$n';
  }

  /// Supprime l'habitude et tout son historique.
  void deleteHabit(String id) {
    final h = habits.firstWhere((x) => x.id == id);
    habits = habits.where((x) => x.id != id).toList();
    logs.remove(id);
    _pending.logs.removeWhere((_, l) => l['habitId'] == id);
    _pending.habit(h, deleted: true);
    _changed();
  }

  void loadExamples() {
    final ex = exampleHabits(dateKey(today));
    habits = [...habits, ...ex];
    selectedDay = today;
    ex.forEach(_pending.habit);
    _changed();
  }

  // --------------------------------------------------------------- synchro

  void _changed() {
    notifyListeners();
    unawaited(_local.save(AppData(habits, logs)));
    unawaited(_local.savePending(_pending));
    if (_api == null) return;
    // Regroupe les changements rapprochés (plusieurs +1 d'affilée).
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 1500), () => unawaited(sync()));
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _queue.then((_) => task());
    _queue = next.catchError((_) {});
    return _queue;
  }

  void _setStatus(SyncStatus s, [String? error]) {
    status = s;
    syncError = error;
    notifyListeners();
  }

  /// Envoie les changements en attente, puis récupère ceux faits ailleurs.
  Future<void> sync() {
    _syncTimer?.cancel();
    if (_api == null) return Future.value();
    return _enqueue(_syncNow);
  }

  Future<void> _syncNow() async {
    final api = _api;
    if (api == null) return;
    _setStatus(SyncStatus.syncing);
    try {
      if (!_pending.isEmpty) {
        final sent = _pending.copy();
        await api.push(sent);
        _pending.acknowledge(sent);
        await _local.savePending(_pending);
      }
      final remote = await api.pull(_local.lastRev);
      _merge(remote);
      await _local.save(AppData(habits, logs));
      await _local.setLastRev(remote.rev);
      lastSyncAt = DateTime.now();
      _setStatus(SyncStatus.synced);
    } on ApiException catch (e) {
      _setStatus(
        SyncStatus.offline,
        e.unauthorized ? 'Téléphone non reconnu par l’API (révoqué ?) : associez-le à nouveau.' : e.toString(),
      );
    }
  }

  /// Applique les changements reçus, sauf là où un changement local attend
  /// encore d'être envoyé (il est plus récent et partira au prochain envoi).
  void _merge(RemoteChanges r) {
    if (r.habits.isEmpty && r.logs.isEmpty) return;
    final byId = {for (final h in habits) h.id: h};
    for (final j in r.habits) {
      final id = j['id'] as String;
      if (_pending.habits.containsKey(id)) continue;
      if (j['deleted'] == true) {
        byId.remove(id);
        logs.remove(id);
      } else {
        byId[id] = Habit.fromJson(j);
      }
    }
    habits = byId.values.toList()..sort(_byPosition);
    for (final j in r.logs) {
      final habitId = j['habitId'] as String;
      final day = j['day'] as String;
      if (!byId.containsKey(habitId) || _pending.logs.containsKey(PendingChanges.logKey(habitId, day))) continue;
      final count = j['count'] as int;
      if (count > 0) {
        (logs[habitId] ??= {})[day] = count;
      } else {
        logs[habitId]?.remove(day);
        if (logs[habitId]?.isEmpty ?? false) logs.remove(habitId);
      }
    }
    notifyListeners();
  }

  /// Associe ce téléphone à l'API avec le code d'association, puis envoie
  /// toutes les données locales et récupère celles du serveur.
  /// Renvoie un message d'erreur, ou null si tout s'est bien passé.
  Future<String?> pair(ApiConfig config, {required String cfClientSecret, required String code}) async {
    await _queue;
    final api = ApiClient(config, cfClientSecret: cfClientSecret, client: _httpClient);
    try {
      await api.pair(code.trim());
    } on ApiException catch (e) {
      return e.toString();
    }
    await _secrets.write(_tokenKey, api.token!);
    await _secrets.write(_cfSecretKey, cfClientSecret);
    await _local.saveApiConfig(config);
    await _local.setLastRev(0);
    // Tout l'existant local part au serveur (fusion : la dernière écriture gagne).
    for (final h in habits) {
      _pending.habit(h);
    }
    logs.forEach((habitId, days) => days.forEach((day, count) => _pending.log(habitId, day, count)));
    await _local.savePending(_pending);
    _api = api;
    await sync();
    return status == SyncStatus.synced ? null : syncError;
  }

  /// Oublie l'association (les données restent sur le téléphone).
  Future<void> unpair() async {
    await _queue;
    _syncTimer?.cancel();
    _api = null;
    await _secrets.delete(_tokenKey);
    await _secrets.delete(_cfSecretKey);
    await _local.saveApiConfig(null);
    await _local.setLastRev(0);
    _pending = PendingChanges();
    await _local.savePending(_pending);
    lastSyncAt = null;
    _setStatus(SyncStatus.notConfigured);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
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
