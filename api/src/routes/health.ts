import type { FastifyInstance } from 'fastify';

export async function healthRoutes(app: FastifyInstance) {
  app.get(
    '/health',
    {
      config: { rateLimit: false },
      schema: {
        tags: ['santé'],
        summary: 'État de l’API et de la base',
        response: {
          200: {
            type: 'object',
            properties: { status: { type: 'string', enum: ['ok'] } },
          },
          503: {
            type: 'object',
            properties: { status: { type: 'string', enum: ['indisponible'] } },
          },
        },
      },
    },
    async (_req, reply) => {
      try {
        await app.db.query('SELECT 1');
        return { status: 'ok' };
      } catch {
        return reply.status(503).send({ status: 'indisponible' });
      }
    },
  );
}
