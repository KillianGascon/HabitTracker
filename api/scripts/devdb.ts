// PostgreSQL de développement propre au projet (données dans api/.pgdata,
// ignoré par Git), sans toucher au PostgreSQL éventuellement installé en
// service. Nécessite les binaires PostgreSQL (initdb, pg_ctl, psql) dans le PATH.
//
//   npm run db:start   crée la base au premier lancement, puis la démarre
//   npm run db:stop    l'arrête
//
// Utilisateur, mot de passe, port et noms de base viennent de DATABASE_URL et
// TEST_DATABASE_URL (fichier .env).
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const dataDir = new URL('../.pgdata', import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1');
const main = new URL(process.env.DATABASE_URL ?? '');
const test = process.env.TEST_DATABASE_URL ? new URL(process.env.TEST_DATABASE_URL) : null;
const user = decodeURIComponent(main.username);
const password = decodeURIComponent(main.password);
const port = main.port || '5432';
const databases = [main, test].filter((u) => u !== null).map((u) => u.pathname.slice(1));

if (!user || !password) throw new Error('DATABASE_URL doit contenir utilisateur et mot de passe (voir .env.example)');

// `detach` : sous Windows, le serveur lancé par pg_ctl hériterait de notre
// sortie standard et garderait la commande bloquée ; ses messages vont dans
// .pgdata/log.txt de toute façon.
const run = (cmd: string, args: string[], detach = false) =>
  execFileSync(cmd, args, {
    stdio: detach ? 'ignore' : 'inherit',
    env: { ...process.env, PGPASSWORD: password },
  });

function init() {
  const tmp = mkdtempSync(join(tmpdir(), 'devdb-'));
  const pwfile = join(tmp, 'pw');
  writeFileSync(pwfile, password);
  try {
    run('initdb', ['-D', dataDir, '-U', user, '--pwfile', pwfile, '-A', 'scram-sha-256', '-E', 'UTF8', '--locale=C']);
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

function start() {
  const fresh = !existsSync(dataDir);
  if (fresh) init();
  try {
    run(
      'pg_ctl',
      ['-D', dataDir, '-o', `-p ${port} -c listen_addresses=localhost`, '-l', join(dataDir, 'log.txt'), '-w', 'start'],
      true,
    );
  } catch {
    throw new Error(`PostgreSQL n'a pas démarré : voir ${join(dataDir, 'log.txt')}`);
  }
  if (fresh) {
    for (const db of databases) {
      run('psql', ['-h', 'localhost', '-p', port, '-U', user, '-d', 'postgres', '-c', `CREATE DATABASE "${db}"`]);
    }
  }
  console.log(`PostgreSQL de dev prêt sur localhost:${port} (bases : ${databases.join(', ')})`);
}

function stop() {
  run('pg_ctl', ['-D', dataDir, '-w', 'stop']);
}

const action = process.argv[2];
if (action === 'start') start();
else if (action === 'stop') stop();
else {
  console.error('Usage : node scripts/devdb.ts start|stop');
  process.exit(1);
}
