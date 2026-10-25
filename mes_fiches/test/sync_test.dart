// Test de bout en bout : deux « téléphones » se synchronisent via une vraie API.
// Lancement (API de dev démarrée, voir api/README.md) :
//   API_TEST_URL=http://localhost:3000 API_TEST_PAIRING_CODE=... flutter test test/sync_test.dart
// Ignoré si API_TEST_URL n'est pas défini. Chaque lancement associe deux
// appareils (limite de l'API : 5 associations par 15 minutes).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_fiches/models.dart';
import 'package:mes_fiches/storage/api_config.dart';
import 'package:mes_fiches/storage/local_storage.dart';
import 'package:mes_fiches/storage/secret_store.dart';
import 'package:mes_fiches/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final url = Platform.environment['API_TEST_URL'];
final code = Platform.environment['API_TEST_PAIRING_CODE'] ?? '';

Future<HabitStore> phone(String name) async {
  final prefs = await SharedPreferences.getInstance();
  final store = await HabitStore.open(LocalStorage(prefs, prefix: name), MemorySecretStore());
  return store;
}

Future<void> pair(HabitStore s, String name) async {
  final err = await s.pair(ApiConfig(baseUrl: url!, deviceName: name), cfClientSecret: '', code: code);
  expect(err, isNull, reason: 'association de $name');
}

Habit named(HabitStore s, String name) => s.habits.firstWhere((h) => h.name == name);

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  test('synchronisation entre deux téléphones', () async {
    final tag = DateTime.now().millisecondsSinceEpoch;
    final vaisselle = 'Vaisselle $tag';
    final lessive = 'Lessive $tag';

    // Téléphone A : des données hors connexion, puis association.
    final a = await phone('a$tag');
    a.saveHabit(name: vaisselle, emoji: '🍽️', period: Period.day, target: 3);
    a.saveHabit(name: lessive, emoji: '🧺', period: Period.week, target: 2);
    a.plus(named(a, vaisselle));
    a.plus(named(a, vaisselle));
    expect(a.status, SyncStatus.notConfigured);
    await pair(a, 'Téléphone A');
    expect(a.status, SyncStatus.synced);
    expect(a.pendingCount, 0, reason: 'tout est parti');

    // Téléphone B : s'associe et récupère tout.
    final b = await phone('b$tag');
    await pair(b, 'Téléphone B');
    final vB = named(b, vaisselle);
    expect(b.countOn(vB, b.today), 2);
    expect(named(b, lessive).period, Period.week);

    // B coche une 3e fois et renomme la lessive ; A le voit.
    b.plus(vB);
    b.saveHabit(id: named(b, lessive).id, name: '$lessive (40°)', emoji: '🧺', period: Period.week, target: 2);
    await b.sync();
    await a.sync();
    expect(a.countOn(named(a, vaisselle), a.today), 3);
    expect(a.habits.any((h) => h.name == '$lessive (40°)'), isTrue);

    // A supprime la vaisselle ; elle disparaît de B avec son historique.
    final vId = named(a, vaisselle).id;
    a.deleteHabit(vId);
    await a.sync();
    await b.sync();
    expect(b.habits.any((h) => h.id == vId), isFalse);
    expect(b.logs.containsKey(vId), isFalse);

    // Même jour modifié des deux côtés : la dernière écriture gagne, et un
    // changement local pas encore envoyé n'est pas écrasé par la synchro entrante.
    b.plus(named(b, '$lessive (40°)'));
    await b.sync();
    a.plus(named(a, '$lessive (40°)'));
    a.plus(named(a, '$lessive (40°)'));
    expect(a.pendingCount, greaterThan(0));
    await a.sync();
    expect(a.status, SyncStatus.synced);
    expect(a.countOn(named(a, '$lessive (40°)'), a.today), 2, reason: 'le local plus récent gagne');
    await b.sync();
    expect(b.countOn(named(b, '$lessive (40°)'), b.today), 2);

    // Oublier l'association garde les données locales.
    await a.unpair();
    expect(a.status, SyncStatus.notConfigured);
    expect(a.habits, isNotEmpty);
  }, skip: url == null ? 'API_TEST_URL non défini' : false);

  test('code d’association refusé', () async {
    final s = await phone('refus');
    final err = await s.pair(ApiConfig(baseUrl: url!, deviceName: 'x'), cfClientSecret: '', code: 'mauvais-code');
    expect(err, contains('401'));
    expect(s.status, SyncStatus.notConfigured);
  }, skip: url == null ? 'API_TEST_URL non défini' : false);

  test('API injoignable : les changements attendent', () async {
    final s = await phone('horsligne');
    final err = await s.pair(
      const ApiConfig(baseUrl: 'http://127.0.0.1:9', deviceName: 'x'),
      cfClientSecret: '',
      code: 'peu importe',
    );
    expect(err, contains('injoignable'));
    s.saveHabit(name: 'Hors ligne', emoji: '✨', period: Period.day, target: 1);
    expect(s.habits.single.name, 'Hors ligne');
  });
}
