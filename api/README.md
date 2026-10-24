# Mes fiches – API

API de synchronisation de l’appli Flutter `mes_fiches` : Fastify + PostgreSQL, en TypeScript
exécuté directement par Node 24 (pas d’étape de compilation).

Documentation interactive (Swagger) : **`/docs`** — spécification OpenAPI brute : `/docs/json`.

## Routes

| Méthode | Route | Auth | Rôle |
|---|---|---|---|
| `GET` | `/health` | – | état de l’API et de la base (supervision Coolify) |
| `POST` | `/v1/devices/pair` | code d’association | échange `PAIRING_CODE` contre un jeton d’appareil (5 essais / 15 min) |
| `GET` | `/v1/devices` | jeton | appareils actifs |
| `DELETE` | `/v1/devices/{id}` | jeton | révoque un appareil (téléphone perdu) |
| `GET` | `/v1/sync?since=N` | jeton | tout ce qui a changé après la révision `N`, suppressions comprises |
| `POST` | `/v1/sync` | jeton | envoie les changements du téléphone (la dernière écriture gagne) |

Authentification : `Authorization: Bearer <jeton>`. Le jeton (256 bits aléatoires) n’est renvoyé
qu’une fois à l’association ; la base n’en garde que l’empreinte SHA-256.

### Synchronisation

Chaque écriture en base reçoit un numéro de révision croissant (`rev`). Le téléphone :

1. envoie ses changements en attente (`POST /v1/sync`) ;
2. récupère ce qui a changé depuis sa dernière révision (`GET /v1/sync?since=…`) et garde le
   nouveau `rev`.

Les suppressions sont gardées comme « pierres tombales » (`deleted: true` pour une habitude,
`count: 0` pour un jour) afin d’être transmises aux autres appareils.

## Variables d’environnement

| Variable | Obligatoire | Défaut | Rôle |
|---|---|---|---|
| `DATABASE_URL` | oui | – | `postgres://utilisateur:motdepasse@hote:5432/base` |
| `PAIRING_CODE` | oui | – | code d’association, **≥ 16 caractères** (`openssl rand -base64 24`) |
| `PORT` | | `3000` | |
| `HOST` | | `0.0.0.0` | |
| `BEHIND_CLOUDFLARE` | | `true` | limite de débit par IP réelle (`CF-Connecting-IP`) |
| `DOCS_ENABLED` | | `true` | `false` pour masquer `/docs` |
| `LOG_LEVEL` | | `info` | |

Les migrations (`migrations/NNN_*.sql`) s’appliquent automatiquement au démarrage.

## Sécurité

- Validation stricte de chaque requête par schéma JSON (champs inconnus refusés, formats de
  date, bornes) ; requêtes SQL toutes paramétrées.
- Limite de débit globale (300 req/min/IP) et renforcée sur l’association.
- En-têtes de sécurité (Helmet : CSP, HSTS, nosniff…), corps limité à 1 Mo.
- Jeton et secret Cloudflare masqués dans les journaux.
- Conteneur : utilisateur non privilégié, code en lecture seule.

Déploiement (Coolify, tunnel Cloudflare, Cloudflare Access) : voir
[`../docs/deploiement.md`](../docs/deploiement.md).

## Développement

```bash
npm install
DATABASE_URL=postgres://postgres@localhost:5432/mes_fiches PAIRING_CODE=un-code-de-dev-assez-long npm run dev
# → http://localhost:3000/docs

npm run typecheck
TEST_DATABASE_URL=postgres://postgres@localhost:5432/mes_fiches_test npm test
```

⚠️ Les tests **effacent** le schéma `public` de la base `TEST_DATABASE_URL` : utilisez une base dédiée.
