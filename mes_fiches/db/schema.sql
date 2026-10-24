-- =====================================================================
--  Mes fiches – schéma PostgreSQL (≥ 12)
--
--  Utilisation :
--    createdb mes_fiches
--    psql -d mes_fiches -f db/schema.sql
--
--  Le script est idempotent : il peut être relancé sans perte de données.
--  Pas de table utilisateur : l'appli est mono-utilisateur (un seul téléphone).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
--  Habitudes
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS habit (
    id          text        PRIMARY KEY,                      -- ex. 'h1729500000000'
    name        text        NOT NULL CHECK (length(btrim(name)) > 0),
    emoji       text        NOT NULL DEFAULT '✨',
    period      text        NOT NULL CHECK (period IN ('day', 'week', 'month')),
    target      smallint    NOT NULL CHECK (target BETWEEN 1 AND 50), -- nb de fois par période
    position    integer     NOT NULL DEFAULT 0,               -- ordre d'affichage
    created     date        NOT NULL DEFAULT current_date,    -- date locale de création
    updated_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  habit        IS 'Habitude récurrente à faire N fois par jour, semaine ou mois';
COMMENT ON COLUMN habit.period IS 'day = le jour même ; week = lundi → dimanche ; month = 1er → dernier jour';
COMMENT ON COLUMN habit.target IS 'Nombre de fois à faire sur la période';

CREATE INDEX IF NOT EXISTS habit_position_idx ON habit (position, created);

-- ---------------------------------------------------------------------
--  Historique : nombre de fois cochées par habitude et par jour
--  (un compteur à 0 n'est pas stocké : la ligne est supprimée)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS habit_log (
    habit_id    text        NOT NULL REFERENCES habit (id) ON DELETE CASCADE,
    day         date        NOT NULL,                         -- date locale 'YYYY-MM-DD'
    count       smallint    NOT NULL CHECK (count > 0),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (habit_id, day)
);

COMMENT ON TABLE habit_log IS 'logs[habit_id][day] = nombre de fois ce jour-là';

CREATE INDEX IF NOT EXISTS habit_log_day_idx ON habit_log (day);

-- ---------------------------------------------------------------------
--  updated_at automatique
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS habit_touch ON habit;
CREATE TRIGGER habit_touch BEFORE UPDATE ON habit
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

DROP TRIGGER IF EXISTS habit_log_touch ON habit_log;
CREATE TRIGGER habit_log_touch BEFORE UPDATE ON habit_log
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

-- ---------------------------------------------------------------------
--  Vue pratique : progression de chaque habitude par période
--  (date_trunc('week') démarre bien le lundi en PostgreSQL)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW habit_period_progress AS
SELECT h.id                                         AS habit_id,
       h.name,
       h.period,
       h.target,
       CASE h.period
           WHEN 'day'   THEN l.day
           WHEN 'week'  THEN date_trunc('week',  l.day)::date
           WHEN 'month' THEN date_trunc('month', l.day)::date
       END                                          AS period_start,
       sum(l.count)::int                            AS done_count,
       sum(l.count) >= h.target                     AS achieved
FROM habit h
JOIN habit_log l ON l.habit_id = h.id
GROUP BY h.id, h.name, h.period, h.target, period_start;

COMMIT;

-- ---------------------------------------------------------------------
--  Optionnel : un rôle dédié pour l'appli (à adapter, puis décommenter)
-- ---------------------------------------------------------------------
-- CREATE ROLE mes_fiches_app LOGIN PASSWORD 'changez-moi';
-- GRANT CONNECT ON DATABASE mes_fiches TO mes_fiches_app;
-- GRANT USAGE ON SCHEMA public TO mes_fiches_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON habit, habit_log TO mes_fiches_app;
-- GRANT SELECT ON habit_period_progress TO mes_fiches_app;
