import type { FastifyInstance } from 'fastify';

import { newToken, sameSecret, sha256 } from '../auth.ts';

const error = { type: 'object', properties: { error: { type: 'string' } } } as const;

const device = {
  type: 'object',
  properties: {
    id: { type: 'string', format: 'uuid' },
    name: { type: 'string' },
    createdAt: { type: 'string', format: 'date-time' },
    lastSeenAt: { type: ['string', 'null'], format: 'date-time' },
    current: { type: 'boolean', description: 'Appareil qui fait la requête' },
  },
} as const;

export async function deviceRoutes(app: FastifyInstance) {
  app.post<{ Body: { code: string; name: string } }>(
    '/pair',
    {
      // Protège le code d'association contre les essais en série.
      config: { rateLimit: { max: 5, timeWindow: '15 minutes' } },
      schema: {
        tags: ['appareils'],
        summary: 'Associer un appareil',
        description:
          'Échange le code d’association (variable `PAIRING_CODE` du serveur) contre un jeton d’appareil. ' +
          'Le jeton n’est renvoyé qu’une seule fois : seul son empreinte SHA-256 est stockée. ' +
          'Limité à 5 essais par 15 minutes.',
        body: {
          type: 'object',
          required: ['code', 'name'],
          additionalProperties: false,
          properties: {
            code: { type: 'string', minLength: 1, maxLength: 200 },
            name: { type: 'string', minLength: 1, maxLength: 60, examples: ['Pixel de Killian'] },
          },
        },
        response: {
          201: {
            type: 'object',
            properties: {
              deviceId: { type: 'string', format: 'uuid' },
              token: { type: 'string', description: 'À conserver dans le coffre sécurisé du téléphone' },
            },
          },
          401: error,
        },
      },
    },
    async (req, reply) => {
      if (!sameSecret(req.body.code, app.config.pairingCode)) {
        req.log.warn('Code d’association refusé');
        return reply.status(401).send({ error: 'Code d’association invalide' });
      }
      const name = req.body.name.trim();
      if (!name) return reply.status(400).send({ error: 'Nom d’appareil vide' });
      const token = newToken();
      const { rows } = await app.db.query<{ id: string }>(
        'INSERT INTO device (name, token_hash, last_seen_at) VALUES ($1, $2, now()) RETURNING id',
        [name, sha256(token)],
      );
      req.log.info({ deviceId: rows[0]!.id }, 'Appareil associé');
      return reply.status(201).send({ deviceId: rows[0]!.id, token });
    },
  );

  app.get(
    '/',
    {
      onRequest: app.authenticate,
      schema: {
        tags: ['appareils'],
        summary: 'Lister les appareils actifs',
        security: [{ bearerAuth: [] }],
        response: { 200: { type: 'array', items: device }, 401: error },
      },
    },
    async (req) => {
      const { rows } = await app.db.query(
        `SELECT id, name, created_at AS "createdAt", last_seen_at AS "lastSeenAt", id = $1 AS current
           FROM device WHERE revoked_at IS NULL ORDER BY created_at`,
        [req.deviceId],
      );
      return rows;
    },
  );

  app.delete<{ Params: { id: string } }>(
    '/:id',
    {
      onRequest: app.authenticate,
      schema: {
        tags: ['appareils'],
        summary: 'Révoquer un appareil',
        description: 'Le jeton de l’appareil cesse immédiatement de fonctionner (téléphone perdu…).',
        security: [{ bearerAuth: [] }],
        params: {
          type: 'object',
          required: ['id'],
          properties: { id: { type: 'string', format: 'uuid' } },
        },
        response: { 204: { type: 'null' }, 401: error, 404: error },
      },
    },
    async (req, reply) => {
      const { rowCount } = await app.db.query(
        'UPDATE device SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL',
        [req.params.id],
      );
      if (!rowCount) return reply.status(404).send({ error: 'Appareil introuvable' });
      req.log.info({ deviceId: req.params.id }, 'Appareil révoqué');
      return reply.status(204).send();
    },
  );
}
