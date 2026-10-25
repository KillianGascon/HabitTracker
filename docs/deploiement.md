# Déploiement de l’API – Coolify (Proxmox) + Cloudflare

```
Téléphone ──HTTPS──► Cloudflare Access ──tunnel sortant──► Coolify (VM Proxmox)
                     (jeton de service)                     ├─ API Fastify  (conteneur)
                                                            └─ PostgreSQL   (réseau interne)
```

Trois verrous successifs :

1. **Cloudflare Access** rejette toute requête sans le jeton de service de l’appli : robots et
   scanners n’atteignent jamais la VM.
2. **L’API** exige le jeton d’appareil du téléphone (révocable).
3. **PostgreSQL** n’a aucun port publié : seule l’API y accède.

Aucun port n’est ouvert sur la box : le tunnel est une connexion sortante.

---

## 1. Base PostgreSQL (Coolify)

1. *Projects* → ton projet → *+ New* → *Database* → **PostgreSQL** (16 ou plus).
2. Laisse **« Make it publicly available » décoché** : la base reste sur le réseau Docker interne.
3. Démarre-la, puis copie l’**URL interne** (`postgres://…@<id-du-conteneur>:5432/postgres`).
4. Onglet *Backups* : active une sauvegarde planifiée (quotidienne), idéalement vers un
   stockage S3 hors de la VM.

## 2. Application API (Coolify)

1. *+ New* → *Application* → dépôt GitHub `KillianGascon/HabitTracker` (via la GitHub App de
   Coolify, ou dépôt public).
2. Branche : `main` (ou la branche de travail pour tester).
3. **Build Pack : Dockerfile** — **Base Directory : `/api`**.
4. **Ports Exposes : `3000`**.
5. **Domaine** : `api.<ton-domaine>` (voir l’étape 3 pour `http://` ou `https://`).
6. *Health check* : chemin **`/health`**, port `3000`.
7. Variables d’environnement (cocher « secret » pour les deux premières) :

   | Variable | Valeur |
   |---|---|
   | `DATABASE_URL` | l’URL interne copiée à l’étape 1 |
   | `PAIRING_CODE` | sortie de `openssl rand -base64 24` (garde-la pour associer le téléphone) |
   | `BEHIND_CLOUDFLARE` | `true` |

8. *Deploy*. Les migrations s’appliquent au démarrage (voir les journaux : « Migrations
   appliquées »). Active le déploiement automatique à chaque push si tu veux.

## 3. Tunnel Cloudflare

Ton Coolify est déjà exposé via Cloudflare : ajoute simplement le sous-domaine de l’API au
tunnel existant.

*Cloudflare Zero Trust* → *Networks* → *Tunnels* → ton tunnel → *Public Hostname* → *Add* :

- **Hostname** : `api.<ton-domaine>`
- **Service** : la même cible que tes autres applis Coolify — en général le proxy de Coolify,
  `http://localhost:80`.

Le HTTPS est assuré par Cloudflare jusqu’au tunnel. Si ton tunnel pointe en HTTP vers le proxy
de Coolify, déclare le domaine **en `http://api.<ton-domaine>`** dans Coolify (sinon Coolify
redirige vers HTTPS et crée une boucle de redirections). Garde la même convention que tes
autres applis.

## 4. Cloudflare Access (verrou n°1)

1. *Zero Trust* → *Access* → *Service Auth* → **Create Service Token** « mes-fiches-app ».
   Note le **Client ID** et le **Client Secret** (affiché une seule fois).
2. *Access* → *Applications* → *Add an application* → **Self-hosted** :
   - domaine : `api.<ton-domaine>` ;
   - politique 1 — action **Service Auth**, règle *Include* → *Service Token* →
     « mes-fiches-app » (l’appli) ;
   - politique 2 — action **Allow**, règle *Include* → *Emails* → ton e-mail (pour ouvrir
     Swagger `/docs` dans le navigateur après connexion).
3. L’appli enverra à chaque requête les en-têtes `CF-Access-Client-Id` et
   `CF-Access-Client-Secret`.

Vérification (doit être **refusé** sans les en-têtes, **accepté** avec) :

```bash
curl -i https://api.<ton-domaine>/health
curl -i https://api.<ton-domaine>/health \
  -H "CF-Access-Client-Id: <id>" -H "CF-Access-Client-Secret: <secret>"
```

## 5. Associer le téléphone

Dans l’appli : adresse de l’API, Client ID / Secret Cloudflare, puis le `PAIRING_CODE`.
L’appli reçoit son jeton d’appareil et le range dans le coffre sécurisé d’Android.

Téléphone perdu : `DELETE /v1/devices/{id}` depuis Swagger (ou un autre appareil), et
révoque/régénère le jeton de service dans Cloudflare.

---

## Checklist de sécurité

- [ ] **Tableau de bord Coolify non public** — ou seulement derrière Cloudflare Access avec ton
      e-mail. C’est la porte d’entrée de tout le serveur.
- [ ] Aucune redirection de port sur la box vers la VM (ni 80/443, ni 5432, ni 8000).
- [ ] PostgreSQL : « Make it publicly available » **décoché**.
- [ ] `PAIRING_CODE` long et aléatoire, stocké en secret dans Coolify, jamais dans Git.
- [ ] Cloudflare Access actif sur `api.<ton-domaine>` (le `curl` sans en-têtes est refusé).
- [ ] VM Proxmox : pare-feu Proxmox activé (entrées bloquées sauf SSH depuis le LAN), SSH par
      clé uniquement, mises à jour automatiques (`unattended-upgrades`).
- [ ] Sauvegardes : base (Coolify) + VM (vzdump / Proxmox Backup Server), testées une fois.
- [ ] Optionnel : `DOCS_ENABLED=false` si tu ne veux pas de Swagger en production.
