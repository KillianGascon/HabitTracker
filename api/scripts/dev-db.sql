-- Base de développement locale (PostgreSQL installé sur le PC).
-- À lancer une fois, en tant que superutilisateur, avec le mot de passe choisi :
--
--   psql -U postgres -v pwd=<mot-de-passe> -f api/scripts/dev-db.sql
--
-- Crée l'utilisateur `mes_fiches` et deux bases qui lui appartiennent :
--   mes_fiches       → l'API en développement (npm run dev)
--   mes_fiches_test  → les tests (effacée à chaque lancement de npm test)
-- Relançable sans risque : rien n'est recréé, seul le mot de passe est remis à jour.

SELECT format('CREATE ROLE mes_fiches LOGIN PASSWORD %L', :'pwd')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mes_fiches')
\gexec

ALTER ROLE mes_fiches PASSWORD :'pwd';

SELECT 'CREATE DATABASE mes_fiches OWNER mes_fiches'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'mes_fiches')
\gexec

SELECT 'CREATE DATABASE mes_fiches_test OWNER mes_fiches'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'mes_fiches_test')
\gexec
