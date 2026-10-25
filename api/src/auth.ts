import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import fp from 'fastify-plugin';

declare module 'fastify' {
  interface FastifyInstance {
    /** À utiliser en `onRequest` sur les routes protégées. */
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
  interface FastifyRequest {
    deviceId?: string;
  }
}

const TOKEN_RE = /^[A-Za-z0-9_-]{43}$/;

export const sha256 = (s: string): Buffer => createHash('sha256').update(s, 'utf8').digest();

/** Jeton d'appareil : 32 octets aléatoires (256 bits), encodés en base64url. */
export const newToken = (): string => randomBytes(32).toString('base64url');

/** Comparaison en temps constant (les deux côtés sont hachés à la même longueur). */
export const sameSecret = (a: string, b: string): boolean => timingSafeEqual(sha256(a), sha256(b));

export const authPlugin = fp(async (app: FastifyInstance) => {
  app.decorate('authenticate', async (req: FastifyRequest, reply: FastifyReply) => {
    const header = req.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!TOKEN_RE.test(token)) {
      return reply.status(401).send({ error: 'Jeton manquant ou invalide' });
    }
    const { rows } = await app.db.query<{ id: string; stale: boolean }>(
      `SELECT id, last_seen_at IS NULL OR last_seen_at < now() - interval '1 minute' AS stale
         FROM device WHERE token_hash = $1 AND revoked_at IS NULL`,
      [sha256(token)],
    );
    const device = rows[0];
    if (!device) {
      return reply.status(401).send({ error: 'Jeton manquant ou invalide' });
    }
    req.deviceId = device.id;
    if (device.stale) {
      await app.db.query('UPDATE device SET last_seen_at = now() WHERE id = $1', [device.id]);
    }
  });
});
