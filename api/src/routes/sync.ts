import type { FastifyInstance } from 'fastify';

interface HabitChange {
  id: string;
  name: string;
  emoji: string;
  category: string;
  period: 'day' | 'week' | 'month';
  target: number;
  position: number;
  created: string;
  deleted: boolean;
  updatedAt: string;
}

interface LogChange {
  habitId: string;
  day: string;
  count: number;
  updatedAt: string;
}

const DAY = '^\\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\\d|3[01])$';
const ID = '^[A-Za-z0-9_-]{1,64}$';

const habit = {
  type: 'object',
  required: ['id', 'name', 'emoji', 'period', 'target', 'position', 'created', 'deleted', 'updatedAt'],
  additionalProperties: false,
  properties: {
    id: { type: 'string', pattern: ID, examples: ['h1729500000000'] },
    name: { type: 'string', minLength: 1, maxLength: 100, pattern: '\\S', examples: ['Faire la vaisselle'] },
    emoji: { type: 'string', minLength: 1, maxLength: 16, examples: ['🍽️'] },
    category: {
      type: 'string',
      maxLength: 40,
      pattern: '^(\\S(.*\\S)?)?$',
      default: '',
      description: 'Catégorie (Ménage, Loisirs…) ; vide = sans catégorie',
      examples: ['Ménage'],
    },
    period: { type: 'string', enum: ['day', 'week', 'month'] },
    target: { type: 'integer', minimum: 1, maximum: 50, description: 'Nombre de fois par période' },
    position: { type: 'integer', minimum: -1000000, maximum: 1000000 },
    created: { type: 'string', pattern: DAY, examples: ['2026-10-21'] },
    deleted: { type: 'boolean', description: 'true = habitude supprimée (avec son historique)' },
    updatedAt: { type: 'string', format: 'date-time', description: 'Heure du changement sur le téléphone' },
  },
} as const;

const log = {
  type: 'object',
  required: ['habitId', 'day', 'count', 'updatedAt'],
  additionalProperties: false,
  properties: {
    habitId: { type: 'string', pattern: ID },
    day: { type: 'string', pattern: DAY, examples: ['2026-10-21'] },
    count: { type: 'integer', minimum: 0, maximum: 1000, description: 'Nombre de fois ce jour-là (0 = effacé)' },
    updatedAt: { type: 'string', format: 'date-time' },
  },
} as const;

const error = { type: 'object', properties: { error: { type: 'string' } } } as const;

/** Garde, pour une même clé, le changement le plus récent. */
function latest<T extends { updatedAt: string }>(items: T[], key: (t: T) => string): T[] {
  const byKey = new Map<string, T>();
  for (const it of items) {
    const prev = byKey.get(key(it));
    if (!prev || Date.parse(it.updatedAt) >= Date.parse(prev.updatedAt)) byKey.set(key(it), it);
  }
  return [...byKey.values()];
}

export async function syncRoutes(app: FastifyInstance) {
  app.addHook('onRequest', app.authenticate);

  app.get<{ Querystring: { since: number } }>(
    '/',
    {
      schema: {
        tags: ['synchro'],
        summary: 'Récupérer les changements',
        description:
          'Renvoie tout ce qui a changé après la révision `since` (0 = tout), suppressions comprises. ' +
          'Le téléphone garde la révision `rev` renvoyée et la repasse au prochain appel.',
        security: [{ bearerAuth: [] }],
        querystring: {
          type: 'object',
          additionalProperties: false,
          properties: { since: { type: 'integer', minimum: 0, default: 0 } },
        },
        response: {
          200: {
            type: 'object',
            properties: {
              rev: { type: 'integer', description: 'Révision à repasser en `since` la prochaine fois' },
              habits: { type: 'array', items: habit },
              logs: { type: 'array', items: log },
            },
          },
          401: error,
        },
      },
    },
    async (req) => {
      const since = req.query.since;
      const [habits, logs] = await Promise.all([
        app.db.query<HabitChange & { rev: string }>(
          `SELECT id, name, emoji, category, period, target, position, to_char(created, 'YYYY-MM-DD') AS created,
                  deleted, updated_at AS "updatedAt", rev
             FROM habit WHERE rev > $1 ORDER BY rev`,
          [since],
        ),
        app.db.query<LogChange & { rev: string }>(
          `SELECT habit_id AS "habitId", to_char(day, 'YYYY-MM-DD') AS day, count,
                  updated_at AS "updatedAt", rev
             FROM habit_log WHERE rev > $1 ORDER BY rev`,
          [since],
        ),
      ]);
      const rev = Math.max(since, ...habits.rows.map((r) => Number(r.rev)), ...logs.rows.map((r) => Number(r.rev)));
      return { rev, habits: habits.rows, logs: logs.rows };
    },
  );

  app.post<{ Body: { habits: HabitChange[]; logs: LogChange[] } }>(
    '/',
    {
      schema: {
        tags: ['synchro'],
        summary: 'Envoyer les changements du téléphone',
        description:
          'Applique les habitudes puis l’historique, en une transaction. Pour chaque élément, ' +
          'la dernière écriture gagne (`updatedAt`). L’historique d’une habitude inconnue est ignoré.',
        security: [{ bearerAuth: [] }],
        body: {
          type: 'object',
          additionalProperties: false,
          properties: {
            habits: { type: 'array', maxItems: 1000, items: habit, default: [] },
            logs: { type: 'array', maxItems: 20000, items: log, default: [] },
          },
        },
        response: {
          200: {
            type: 'object',
            properties: {
              habits: { type: 'integer', description: 'Habitudes appliquées' },
              logs: { type: 'integer', description: 'Lignes d’historique appliquées' },
            },
          },
          401: error,
        },
      },
    },
    async (req) => {
      const habits = latest(req.body.habits, (h) => h.id);
      const logs = latest(req.body.logs, (l) => `${l.habitId}|${l.day}`);
      const client = await app.db.connect();
      try {
        await client.query('BEGIN');
        const h = await client.query(
          `INSERT INTO habit (id, name, emoji, category, period, target, position, created, deleted, updated_at)
           SELECT id, btrim(name), emoji, coalesce(category, ''), period, target, position, created, deleted, "updatedAt"
             FROM jsonb_to_recordset($1::jsonb) AS x(id text, name text, emoji text, category text, period text,
                  target smallint, position int, created date, deleted boolean, "updatedAt" timestamptz)
           ON CONFLICT (id) DO UPDATE SET
             name = EXCLUDED.name, emoji = EXCLUDED.emoji, category = EXCLUDED.category, period = EXCLUDED.period,
             target = EXCLUDED.target, position = EXCLUDED.position, deleted = EXCLUDED.deleted,
             updated_at = EXCLUDED.updated_at
           WHERE habit.updated_at <= EXCLUDED.updated_at`,
          [JSON.stringify(habits)],
        );
        const l = await client.query(
          `INSERT INTO habit_log (habit_id, day, count, updated_at)
           SELECT x."habitId", x.day, x.count, x."updatedAt"
             FROM jsonb_to_recordset($1::jsonb) AS x("habitId" text, day date, count smallint, "updatedAt" timestamptz)
            WHERE EXISTS (SELECT 1 FROM habit WHERE habit.id = x."habitId")
           ON CONFLICT (habit_id, day) DO UPDATE SET count = EXCLUDED.count, updated_at = EXCLUDED.updated_at
           WHERE habit_log.updated_at <= EXCLUDED.updated_at`,
          [JSON.stringify(logs)],
        );
        await client.query('COMMIT');
        return { habits: h.rowCount ?? 0, logs: l.rowCount ?? 0 };
      } catch (e) {
        await client.query('ROLLBACK');
        throw e;
      } finally {
        client.release();
      }
    },
  );
}
