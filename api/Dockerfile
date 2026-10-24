# Image de l'API « Mes fiches ». Node 24 exécute le TypeScript directement.
FROM node:24-alpine

ENV NODE_ENV=production
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY src ./src
COPY migrations ./migrations

# Fichiers appartenant à root, lisibles seulement : le processus (utilisateur
# non privilégié `node`) ne peut pas modifier son propre code.
USER node

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "src/server.ts"]
