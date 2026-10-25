import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';
import Fastify, { type FastifyError, type FastifyInstance } from 'fastify';

import { authPlugin } from './auth.ts';
import type { Config } from './config.ts';
import type { Db } from './db.ts';
import { deviceRoutes } from './routes/devices.ts';
import { healthRoutes } from './routes/health.ts';
import { syncRoutes } from './routes/sync.ts';

declare module 'fastify' {
  interface FastifyInstance {
    db: Db;
    config: Config;
  }
}

export async function buildApp(config: Config, db: Db): Promise<FastifyInstance> {
  const app = Fastify({
    logger: {
      level: config.logLevel,
      redact: ['req.headers.authorization', 'req.headers["cf-access-client-secret"]'],
    },
    bodyLimit: 1024 * 1024,
    // Les en-têtes X-Forwarded-* ne viennent que du tunnel Cloudflare.
    trustProxy: config.behindCloudflare,
    ajv: { customOptions: { removeAdditional: false, coerceTypes: 'array', allErrors: false } },
  });

  app.decorate('db', db);
  app.decorate('config', config);

  await app.register(swagger, {
    openapi: {
      info: {
        title: 'Mes fiches – API',
        description:
          'Synchronisation des habitudes de l’appli « Mes fiches ».\n\n' +
          'Associez d’abord un appareil avec `POST /v1/devices/pair`, puis utilisez le jeton reçu ' +
          '(bouton **Authorize**).',
        version: '1.0.0',
      },
      components: {
        securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer' } },
      },
      tags: [
        { name: 'santé', description: 'Supervision' },
        { name: 'appareils', description: 'Association et révocation des téléphones' },
        { name: 'synchro', description: 'Échange des changements avec le téléphone' },
      ],
    },
  });
  if (config.docsEnabled) {
    await app.register(swaggerUi, { routePrefix: '/docs', staticCSP: true });
  }

  await app.register(helmet, (instance) => ({
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        'default-src': ["'self'"],
        'base-uri': ["'self'"],
        'font-src': ["'self'", 'data:'],
        'form-action': ["'self'"],
        'frame-ancestors': ["'none'"],
        'object-src': ["'none'"],
        'script-src-attr': ["'none'"],
        'img-src': ["'self'", 'data:'],
        'script-src': ["'self'", ...(instance.swaggerCSP?.script ?? [])],
        'style-src': ["'self'", ...(instance.swaggerCSP?.style ?? [])],
      },
    },
  }));

  await app.register(rateLimit, {
    max: 300,
    timeWindow: '1 minute',
    // Derrière Cloudflare, l'IP du client est dans CF-Connecting-IP.
    keyGenerator: (req) =>
      (config.behindCloudflare && (req.headers['cf-connecting-ip'] as string | undefined)) || req.ip,
  });

  app.setErrorHandler((err: FastifyError, req, reply) => {
    const status = err.statusCode ?? 500;
    if (status >= 500) {
      req.log.error(err);
      return reply.status(500).send({ error: 'Erreur interne' });
    }
    return reply.status(status).send({ error: err.message });
  });

  await app.register(authPlugin);
  await app.register(healthRoutes);
  await app.register(deviceRoutes, { prefix: '/v1/devices' });
  await app.register(syncRoutes, { prefix: '/v1/sync' });

  return app;
}
