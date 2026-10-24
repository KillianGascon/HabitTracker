import { buildApp } from './app.ts';
import { loadConfig } from './config.ts';
import { createDb, migrate } from './db.ts';

const config = loadConfig();
const db = createDb(config.databaseUrl);
const app = await buildApp(config, db);

const applied = await migrate(db);
if (applied.length) app.log.info({ applied }, 'Migrations appliquées');

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, async () => {
    app.log.info(`${signal} reçu, arrêt`);
    await app.close();
    await db.end();
    process.exit(0);
  });
}

await app.listen({ port: config.port, host: config.host });
