import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'db_config.dart';

/// Copie locale de tout l'état : l'appli reste utilisable hors connexion.
class LocalStorage {
  LocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _stateKey = 'mes-fiches:v1';
  static const _dirtyKey = 'mes-fiches:dirty';
  static const _dbKey = 'mes-fiches:db';

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

  /// Vrai quand des changements locaux n'ont pas pu être envoyés à la base.
  bool get dirty => _prefs.getBool(_dirtyKey) ?? false;
  Future<void> setDirty(bool v) => _prefs.setBool(_dirtyKey, v);

  DbConfig? loadDbConfig() {
    final raw = _prefs.getString(_dbKey);
    if (raw == null) return null;
    try {
      return DbConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDbConfig(DbConfig? c) => c == null
      ? _prefs.remove(_dbKey)
      : _prefs.setString(_dbKey, jsonEncode(c.toJson()));
}
