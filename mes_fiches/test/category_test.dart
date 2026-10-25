import 'package:flutter_test/flutter_test.dart';
import 'package:mes_fiches/models.dart';
import 'package:mes_fiches/storage/local_storage.dart';
import 'package:mes_fiches/storage/secret_store.dart';
import 'package:mes_fiches/store.dart';
import 'package:mes_fiches/sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<HabitStore> store() async {
  SharedPreferences.setMockInitialValues({});
  return HabitStore.open(LocalStorage(await SharedPreferences.getInstance()), MemorySecretStore());
}

void main() {
  test('catégories : proposées d’abord, puis les autres de A à Z', () async {
    final s = await store();
    s.saveHabit(name: 'Guitare', emoji: '🎸', period: Period.week, target: 2, category: 'Musique');
    s.saveHabit(name: 'Vaisselle', emoji: '🍽️', period: Period.day, target: 1, category: ' Ménage ');
    s.saveHabit(name: 'Jardin', emoji: '🪴', period: Period.week, target: 1, category: 'Extérieur');
    s.saveHabit(name: 'Sans', emoji: '✨', period: Period.day, target: 1);
    expect(s.categories, ['Ménage', 'Extérieur', 'Musique']);
  });

  test('filtre par catégorie, et retour à « toutes » quand elle disparaît', () async {
    final s = await store();
    s.saveHabit(name: 'Vaisselle', emoji: '🍽️', period: Period.day, target: 1, category: 'Ménage');
    s.saveHabit(name: 'Dessin', emoji: '🎨', period: Period.week, target: 1, category: 'Loisirs');
    expect(s.visibleHabits, hasLength(2));

    s.selectCategory('Loisirs');
    expect(s.visibleHabits.map((h) => h.name), ['Dessin']);

    s.deleteHabit(s.visibleHabits.single.id);
    expect(s.category, isNull);
    expect(s.visibleHabits.map((h) => h.name), ['Vaisselle']);
  });

  test('la catégorie est conservée en local et envoyée à l’API', () async {
    final s = await store();
    s.saveHabit(name: 'Réviser', emoji: '📚', period: Period.day, target: 1, category: 'Études');
    final h = s.habits.single;
    expect(Habit.fromJson(h.toJson()).category, 'Études');
    expect(Habit.fromJson({...h.toJson()}..remove('category')).category, '', reason: 'anciennes données');

    final pending = PendingChanges()..habit(h);
    expect((pending.toRequest()['habits'] as List).single['category'], 'Études');
    pending.habits[h.id]!.remove('category');
    expect((pending.toRequest()['habits'] as List).single.containsKey('category'), isFalse);
  });
}
