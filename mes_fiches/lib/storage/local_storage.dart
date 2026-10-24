import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../sync.dart';
import 'api_config.dart';

/// Copie locale de tout l'état : l'appli reste utilisable hors connexion.
class LocalStorage {
  /// [prefix] isole les clés (les tests simulent plusieurs téléphones).
  LocalStorage(this._prefs, {String prefix = 'mes-fiches'})
      : _stateKey = '$prefix:v1',
        _pendingKey = '$prefix:pending',
        _revKey = '$prefix:rev',
        _apiKey = '$prefix:api';

  final SharedPreferences _prefs;
  final String _stateKey, _pendingKey, _revKey, _apiKey;

  AppData load() {
    final raw = _prefs.getString(_stateKey);
    if (raw == null) return AppData.empty();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final habits = (j['habits'] as List)
          .map((e) => Habit.fromJson(e as Map<String, dynamic>))
          .toList();
      final logs = <String, Map<String, int>>{
        for (final e in (j['logs'] as Map<String, dynamic>).entries)
          e.key: {
            for (final d in (e.value as Map<String, dynamic>).entries)
              d.key: d.value as int,
          },
      };
      return AppData(habits, logs);
    } catch (_) {
      return AppData.empty();
    }
  }

  Future<void> save(AppData data) => _prefs.setString(
        _stateKey,
        jsonEncode({
          'habits': data.habits.map((h) => h.toJson()).toList(),
          'logs': data.logs,
        }),
      );

  /// Changements pas encore envoyés à l'API.
  PendingChanges loadPending() {
    final raw = _prefs.getString(_pendingKey);
    if (raw == null) return PendingChanges();
    try {
      return PendingChanges.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PendingChanges();
    }
  }

  Future<void> savePending(PendingChanges p) => _prefs.setString(_pendingKey, jsonEncode(p.toJson()));

  /// Dernière révision reçue de l'API (0 = jamais synchronisé).
  int get lastRev => _prefs.getInt(_revKey) ?? 0;
  Future<void> setLastRev(int rev) => _prefs.setInt(_revKey, rev);

  ApiConfig? loadApiConfig() {
    final raw = _prefs.getString(_apiKey);
    if (raw == null) return null;
    try {
      return ApiConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveApiConfig(ApiConfig? c) =>
      c == null ? _prefs.remove(_apiKey) : _prefs.setString(_apiKey, jsonEncode(c.toJson()));
}
