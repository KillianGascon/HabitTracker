import 'models.dart';

/// Changements locaux pas encore envoyés à l'API, au format de `POST /v1/sync`.
/// Une seule entrée par habitude et par (habitude, jour) : la plus récente.
class PendingChanges {
  PendingChanges([Map<String, Map<String, dynamic>>? habits, Map<String, Map<String, dynamic>>? logs])
      : habits = habits ?? {},
        logs = logs ?? {};

  /// Clé : id de l'habitude.
  final Map<String, Map<String, dynamic>> habits;

  /// Clé : `habitId|jour`.
  final Map<String, Map<String, dynamic>> logs;

  bool get isEmpty => habits.isEmpty && logs.isEmpty;

  static String now() => DateTime.now().toUtc().toIso8601String();
  static String logKey(String habitId, String day) => '$habitId|$day';

  void habit(Habit h, {bool deleted = false}) => habits[h.id] = {
        ...h.toJson(),
        'deleted': deleted,
        'updatedAt': now(),
      };

  void log(String habitId, String day, int count) => logs[logKey(habitId, day)] = {
        'habitId': habitId,
        'day': day,
        'count': count,
        'updatedAt': now(),
      };

  /// Retire les entrées envoyées, sauf celles modifiées entre-temps.
  void acknowledge(PendingChanges sent) {
    void drop(Map<String, Map<String, dynamic>> mine, Map<String, Map<String, dynamic>> theirs) {
      theirs.forEach((k, v) {
        if (mine[k]?['updatedAt'] == v['updatedAt']) mine.remove(k);
      });
    }

    drop(habits, sent.habits);
    drop(logs, sent.logs);
  }

  PendingChanges copy() => PendingChanges(
        {for (final e in habits.entries) e.key: Map.of(e.value)},
        {for (final e in logs.entries) e.key: Map.of(e.value)},
      );

  Map<String, dynamic> toJson() => {'habits': habits, 'logs': logs};

  factory PendingChanges.fromJson(Map<String, dynamic> j) => PendingChanges(
        {for (final e in (j['habits'] as Map<String, dynamic>).entries) e.key: e.value as Map<String, dynamic>},
        {for (final e in (j['logs'] as Map<String, dynamic>).entries) e.key: e.value as Map<String, dynamic>},
      );

  /// Corps de `POST /v1/sync`.
  Map<String, dynamic> toRequest() => {
        'habits': [
          for (final h in habits.values)
            {
              for (final k in ['id', 'name', 'emoji', 'category', 'period', 'target', 'position', 'created', 'deleted', 'updatedAt'])
                // `category` manque dans les changements notés avant son ajout.
                if (h[k] != null) k: h[k],
            },
        ],
        'logs': logs.values.toList(),
      };
}

/// Réponse de `GET /v1/sync`.
class RemoteChanges {
  RemoteChanges(this.rev, this.habits, this.logs);

  final int rev;
  final List<Map<String, dynamic>> habits;
  final List<Map<String, dynamic>> logs;

  factory RemoteChanges.fromJson(Map<String, dynamic> j) => RemoteChanges(
        j['rev'] as int,
        (j['habits'] as List).cast<Map<String, dynamic>>(),
        (j['logs'] as List).cast<Map<String, dynamic>>(),
      );
}
