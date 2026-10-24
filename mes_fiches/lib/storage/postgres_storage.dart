import 'package:postgres/postgres.dart';

import '../models.dart';
import 'db_config.dart';

/// Accès à la base PostgreSQL décrite dans `db/schema.sql`.
class PostgresStorage {
  DbConfig? config;
  Connection? _conn;

  bool get configured => config != null;

  Future<Connection> _open() async {
    final c = config;
    if (c == null) throw StateError('Base non configurée');
    final existing = _conn;
    if (existing != null && existing.isOpen) return existing;
    _conn = await Connection.open(
      Endpoint(
        host: c.host,
        port: c.port,
        database: c.database,
        username: c.username,
        password: c.password,
      ),
      settings: ConnectionSettings(
        sslMode: c.ssl ? SslMode.require : SslMode.disable,
        connectTimeout: const Duration(seconds: 6),
        queryTimeout: const Duration(seconds: 15),
        applicationName: 'mes_fiches',
      ),
    );
    return _conn!;
  }

  Future<T> _run<T>(Future<T> Function(Connection s) f) async {
    try {
      return await f(await _open());
    } catch (_) {
      await close();
      rethrow;
    }
  }

  Future<void> close() async {
    final c = _conn;
    _conn = null;
    if (c != null) {
      try {
        await c.close();
      } catch (_) {}
    }
  }

  Future<void> ping() => _run((s) => s.execute('SELECT 1'));

  Future<AppData> fetchAll() => _run((s) async {
        final hs = await s.execute(
          "SELECT id, name, emoji, period, target, position, to_char(created, 'YYYY-MM-DD') "
          'FROM habit ORDER BY position, created, id',
        );
        final habits = [
          for (final r in hs)
            Habit(
              id: r[0] as String,
              name: r[1] as String,
              emoji: r[2] as String,
              period: PeriodLabels.parse(r[3] as String),
              target: r[4] as int,
              position: r[5] as int,
              created: r[6] as String,
            ),
        ];
        final ls = await s.execute(
          "SELECT habit_id, to_char(day, 'YYYY-MM-DD'), count FROM habit_log",
        );
        final logs = <String, Map<String, int>>{};
        for (final r in ls) {
          (logs[r[0] as String] ??= {})[r[1] as String] = r[2] as int;
        }
        return AppData(habits, logs);
      });

  static final _upsertHabit = Sql.named(
    'INSERT INTO habit (id, name, emoji, period, target, position, created) '
    'VALUES (@id, @name, @emoji, @period, @target, @position, CAST(@created AS date)) '
    'ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, emoji = EXCLUDED.emoji, '
    'period = EXCLUDED.period, target = EXCLUDED.target, position = EXCLUDED.position',
  );

  static final _upsertLog = Sql.named(
    'INSERT INTO habit_log (habit_id, day, count) VALUES (@h, CAST(@d AS date), @c) '
    'ON CONFLICT (habit_id, day) DO UPDATE SET count = EXCLUDED.count',
  );

  static final _deleteLog =
      Sql.named('DELETE FROM habit_log WHERE habit_id = @h AND day = CAST(@d AS date)');

  static Map<String, Object?> _habitParams(Habit h) => {
        'id': h.id,
        'name': h.name,
        'emoji': h.emoji,
        'period': h.period.name,
        'target': h.target,
        'position': h.position,
        'created': h.created,
      };

  Future<void> upsertHabits(List<Habit> habits) => _run((s) => s.runTx((tx) async {
        for (final h in habits) {
          await tx.execute(_upsertHabit, parameters: _habitParams(h));
        }
      }));

  Future<void> deleteHabit(String id) => _run((s) => s.execute(
        Sql.named('DELETE FROM habit WHERE id = @id'),
        parameters: {'id': id},
      ));

  Future<void> setLog(String habitId, String day, int count) => _run((s) => s.execute(
        count > 0 ? _upsertLog : _deleteLog,
        parameters: {'h': habitId, 'd': day, if (count > 0) 'c': count},
      ));

  /// Remplace tout le contenu de la base par l'état local.
  Future<void> replaceAll(AppData data) => _run((s) => s.runTx((tx) async {
        await tx.execute('DELETE FROM habit_log');
        await tx.execute('DELETE FROM habit');
        for (final h in data.habits) {
          await tx.execute(_upsertHabit, parameters: _habitParams(h));
        }
        final ids = {for (final h in data.habits) h.id};
        for (final e in data.logs.entries) {
          if (!ids.contains(e.key)) continue;
          for (final d in e.value.entries) {
            await tx.execute(_upsertLog, parameters: {'h': e.key, 'd': d.key, 'c': d.value});
          }
        }
      }));
}
