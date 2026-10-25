// Tests d'intégration : nécessitent une base PostgreSQL VIDE dédiée aux tests,
// donnée par TEST_DATABASE_URL (son schéma public est effacé à chaque lancement).
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import type { FastifyInstance } from 'fastify';

import { buildApp } from '../src/app.ts';
import type { Config } from '../src/config.ts';
import { createDb, type Db, migrate } from '../src/db.ts';

const url = process.env.TEST_DATABASE_URL;
const PAIRING_CODE = 'code-de-test-assez-long';

const config = (): Config => ({
  port: 0,
  host: '127.0.0.1',
  databaseUrl: url ?? '',
  pairingCode: PAIRING_CODE,
  behindCloudflare: false,
  docsEnabled: true,
  logLevel: 'silent',
});

const habit = (over: Record<string, unknown> = {}) => ({
  id: 'h1',
  name: 'Faire la vaisselle',
  emoji: '🍽️',
  category: 'Ménage',
  period: 'day',
  target: 3,
  position: 0,
  created: '2026-10-21',
  deleted: false,
  updatedAt: '2026-10-21T10:00:00.000Z',
  ...over,
});

describe('API Mes fiches', { skip: !url && 'TEST_DATABASE_URL non défini' }, () => {
  let db: Db;
  let app: FastifyInstance;
  let token = '';
  const auth = () => ({ authorization: `Bearer ${token}` });

  before(async () => {
    db = createDb(url!);
    await db.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
    await db.query('DROP SEQUENCE IF EXISTS sync_rev');
    assert.deepEqual(await migrate(db), ['001_init.sql', '002_habit_category.sql']);
    assert.deepEqual(await migrate(db), [], 'les migrations ne repassent pas');
    app = await buildApp(config(), db);
  });

  after(async () => {
    await app.close();
    await db.end();
  });

  test('santé', async () => {
    const res = await app.inject('/health');
    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.json(), { status: 'ok' });
  });

  test('Swagger : spécification OpenAPI et interface', async () => {
    const spec = await app.inject('/docs/json');
    assert.equal(spec.statusCode, 200);
    const paths = Object.keys(spec.json().paths);
    for (const p of ['/v1/devices/pair', '/v1/sync/', '/health']) assert.ok(paths.includes(p), p);
    const ui = await app.inject('/docs/');
    assert.equal(ui.statusCode, 200);
  });

  test('association : mauvais code refusé', async () => {
    const res = await app.inject({ method: 'POST', url: '/v1/devices/pair', payload: { code: 'faux', name: 'x' } });
    assert.equal(res.statusCode, 401);
  });

  test('association : bon code → jeton', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/v1/devices/pair',
      payload: { code: PAIRING_CODE, name: 'Pixel' },
    });
    assert.equal(res.statusCode, 201);
    token = res.json().token;
    assert.match(token, /^[A-Za-z0-9_-]{43}$/);
    const { rows } = await db.query('SELECT token_hash FROM device');
    assert.equal(rows.length, 1);
    assert.notEqual(rows[0].token_hash.toString(), token, 'seule l’empreinte est stockée');
  });

  test('sans jeton ou jeton inconnu → 401', async () => {
    assert.equal((await app.inject('/v1/sync')).statusCode, 401);
    const bad = await app.inject({ url: '/v1/sync', headers: { authorization: `Bearer ${'a'.repeat(43)}` } });
    assert.equal(bad.statusCode, 401);
  });

  test('envoi puis récupération des changements', async () => {
    const push = await app.inject({
      method: 'POST',
      url: '/v1/sync',
      headers: auth(),
      payload: {
        habits: [habit(), habit({ id: 'h2', name: 'Lessive', period: 'week', target: 2 })],
        logs: [
          { habitId: 'h1', day: '2026-10-21', count: 2, updatedAt: '2026-10-21T10:00:00.000Z' },
          { habitId: 'inconnue', day: '2026-10-21', count: 1, updatedAt: '2026-10-21T10:00:00.000Z' },
        ],
      },
    });
    assert.equal(push.statusCode, 200);
    assert.deepEqual(push.json(), { habits: 2, logs: 1 }, 'l’historique d’une habitude inconnue est ignoré');

    const pull = await app.inject({ url: '/v1/sync?since=0', headers: auth() });
    assert.equal(pull.statusCode, 200);
    const body = pull.json();
    assert.equal(body.habits.length, 2);
    assert.deepEqual(body.logs.map((l: { day: string; count: number }) => [l.day, l.count]), [['2026-10-21', 2]]);
    assert.equal(body.habits[0].created, '2026-10-21');
    assert.equal(body.habits[0].category, 'Ménage');
    assert.ok(body.rev > 0);

    const again = await app.inject({ url: `/v1/sync?since=${body.rev}`, headers: auth() });
    assert.deepEqual(again.json(), { rev: body.rev, habits: [], logs: [] });
  });

  test('la dernière écriture gagne', async () => {
    const before = (await app.inject({ url: '/v1/sync', headers: auth() })).json().rev;
    const old = await app.inject({
      method: 'POST',
      url: '/v1/sync',
      headers: auth(),
      payload: { habits: [habit({ name: 'Ancien nom', updatedAt: '2026-10-20T00:00:00.000Z' })] },
    });
    assert.deepEqual(old.json(), { habits: 0, logs: 0 });

    await app.inject({
      method: 'POST',
      url: '/v1/sync',
      headers: auth(),
      payload: { habits: [habit({ deleted: true, updatedAt: '2026-10-22T00:00:00.000Z' })] },
    });
    const pull = (await app.inject({ url: `/v1/sync?since=${before}`, headers: auth() })).json();
    assert.equal(pull.habits.length, 1);
    assert.equal(pull.habits[0].deleted, true, 'la suppression est transmise');
  });

  test('catégorie : facultative, vide par défaut', async () => {
    const { category: _, ...sans } = habit({ id: 'h3', name: 'Sans catégorie' });
    const push = await app.inject({ method: 'POST', url: '/v1/sync', headers: auth(), payload: { habits: [sans] } });
    assert.equal(push.statusCode, 200);
    const pull = (await app.inject({ url: '/v1/sync', headers: auth() })).json();
    assert.equal(pull.habits.find((h: { id: string }) => h.id === 'h3').category, '');
  });

  test('validation stricte des données', async () => {
    const cases = [
      { habits: [habit({ period: 'year' })] },
      { habits: [habit({ target: 0 })] },
      { habits: [habit({ name: '   ' })] },
      { habits: [habit({ created: '2026-13-01' })] },
      { habits: [habit({ category: ' Ménage' })] },
      { habits: [habit({ category: 'x'.repeat(41) })] },
      { habits: [habit({ extra: 'champ inconnu' })] },
      { habits: [habit({ id: "h1'; DROP TABLE habit;--" })] },
      { logs: [{ habitId: 'h1', day: '2026-10-21', count: -1, updatedAt: '2026-10-21T10:00:00Z' }] },
    ];
    for (const payload of cases) {
      const res = await app.inject({ method: 'POST', url: '/v1/sync', headers: auth(), payload });
      assert.equal(res.statusCode, 400, JSON.stringify(payload));
    }
  });

  test('révocation : le jeton cesse de marcher', async () => {
    const list = await app.inject({ url: '/v1/devices', headers: auth() });
    assert.equal(list.statusCode, 200);
    const [me] = list.json();
    assert.equal(me.current, true);

    const del = await app.inject({ method: 'DELETE', url: `/v1/devices/${me.id}`, headers: auth() });
    assert.equal(del.statusCode, 204);
    assert.equal((await app.inject({ url: '/v1/sync', headers: auth() })).statusCode, 401);
  });

  test('association limitée à 5 essais par 15 minutes', async () => {
    const limited = await buildApp(config(), db);
    try {
      const codes = [];
      for (let i = 0; i < 6; i++) {
        const res = await limited.inject({ method: 'POST', url: '/v1/devices/pair', payload: { code: 'faux', name: 'x' } });
        codes.push(res.statusCode);
      }
      assert.deepEqual(codes, [401, 401, 401, 401, 401, 429]);
    } finally {
      await limited.close();
    }
  });

  test('en-têtes de sécurité', async () => {
    const res = await app.inject('/health');
    assert.equal(res.headers['x-content-type-options'], 'nosniff');
    assert.ok(res.headers['content-security-policy']);
    assert.ok(res.headers['strict-transport-security']);
  });
});
