enum Period { day, week, month }

extension PeriodLabels on Period {
  /// Mot utilisé dans « 3 fois par jour ».
  String get word => const ['jour', 'semaine', 'mois'][index];

  /// Unité de série : « 🔥 5 j ».
  String get unit => const ['j', 'sem.', 'mois'][index];

  String get groupLabel =>
      const ['Chaque jour', 'Chaque semaine', 'Chaque mois'][index];

  String get optionLabel => const ['Par jour', 'Par semaine', 'Par mois'][index];

  int get maxTarget => const [12, 14, 31][index];

  static Period parse(String s) =>
      Period.values.firstWhere((p) => p.name == s, orElse: () => Period.day);
}

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.period,
    required this.target,
    required this.created,
    this.position = 0,
  });

  final String id;
  final String name;
  final String emoji;
  final Period period;
  final int target;

  /// Date locale de création, `YYYY-MM-DD`.
  final String created;
  final int position;

  String get frequency => '$target fois par ${period.word}';

  Habit copyWith({
    String? name,
    String? emoji,
    Period? period,
    int? target,
    int? position,
  }) =>
      Habit(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        period: period ?? this.period,
        target: target ?? this.target,
        created: created,
        position: position ?? this.position,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'period': period.name,
        'target': target,
        'created': created,
        'position': position,
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        period: PeriodLabels.parse(j['period'] as String),
        target: j['target'] as int,
        created: j['created'] as String,
        position: (j['position'] as int?) ?? 0,
      );
}

/// `logs[habitId][YYYY-MM-DD]` = nombre de fois ce jour-là (jamais 0).
typedef Logs = Map<String, Map<String, int>>;

class AppData {
  AppData(this.habits, this.logs);
  final List<Habit> habits;
  final Logs logs;

  static AppData empty() => AppData([], {});
}

const kEmojis = [
  '🍽️', '🛏️', '✨', '🧺', '🧹', '🛒', '🧾', '🛌', //
  '💊', '💧', '🪴', '🐕', '📚', '🏃', '🗑️', '📞',
];

/// « Charger des exemples » : habitudes sans historique.
List<Habit> exampleHabits(String today) {
  final base = DateTime.now().millisecondsSinceEpoch;
  final specs = [
    ('🍽️', 'Faire la vaisselle', Period.day, 3),
    ('🛏️', 'Faire le lit', Period.day, 1),
    ('✨', 'Ranger 10 minutes', Period.day, 1),
    ('🧺', 'Lancer une lessive', Period.week, 2),
    ('🧹', 'Passer l’aspirateur', Period.week, 1),
    ('🛒', 'Faire les courses', Period.week, 1),
    ('🧾', 'Payer les factures', Period.month, 1),
    ('🛌', 'Changer les draps', Period.month, 2),
  ];
  return [
    for (var i = 0; i < specs.length; i++)
      Habit(
        id: 'h${base + i}',
        emoji: specs[i].$1,
        name: specs[i].$2,
        period: specs[i].$3,
        target: specs[i].$4,
        created: today,
        position: i,
      ),
  ];
}
