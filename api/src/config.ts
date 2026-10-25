export interface Config {
  port: number;
  host: string;
  databaseUrl: string;
  /** Code à saisir dans l'appli pour associer un téléphone. */
  pairingCode: string;
  /** Derrière le tunnel Cloudflare : l'IP réelle est dans `CF-Connecting-IP`. */
  behindCloudflare: boolean;
  docsEnabled: boolean;
  logLevel: string;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const databaseUrl = env.DATABASE_URL;
  if (!databaseUrl) throw new Error('DATABASE_URL manquant');

  const pairingCode = env.PAIRING_CODE ?? '';
  if (pairingCode.length < 16) {
    throw new Error('PAIRING_CODE doit faire au moins 16 caractères');
  }

  return {
    port: Number(env.PORT ?? 3000),
    host: env.HOST ?? '0.0.0.0',
    databaseUrl,
    pairingCode,
    behindCloudflare: env.BEHIND_CLOUDFLARE !== 'false',
    docsEnabled: env.DOCS_ENABLED !== 'false',
    logLevel: env.LOG_LEVEL ?? 'info',
  };
}
