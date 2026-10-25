-- =====================================================================
--  Mes fiches – schéma initial
--
--  Synchronisation : chaque écriture reçoit un numéro de révision `rev`
--  croissant (séquence `sync_rev`). Le téléphone demande « tout ce qui a
--  changé depuis la révision N ». Les suppressions sont conservées sous
--  forme de pierres tombales (habit.deleted = true, habit_log.count = 0)
--  pour être transmises aux autres appareils.
--  `updated_at` est l'horodatage du téléphone : la dernière écriture gagne.
-- =====================================================================

CREATE SEQUENCE sync_rev;

CREATE OR REPLACE FUNCTION bump_rev() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.rev := nextval('sync_rev');
    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------
--  Habitudes
-- ---------------------------------------------------------------------
CREATE TABLE habit (
    id          text        PRIMARY KEY CHECK (id ~ '^[A-Za-z0-9_-]{1,64}$'),
    name        text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 100),
    emoji       text        NOT NULL CHECK (length(emoji) BETWEEN 1 AND 16),
    period      text        NOT NULL CHECK (period IN ('day', 'week', 'month')),
    target      smallint    NOT NULL CHECK (target BETWEEN 1 AND 50),  -- nb de fois par période
    position    integer     NOT NULL DEFAULT 0,                        -- ordre d'affichage
    created     date        NOT NULL,                                  -- date locale de création
    deleted     boolean     NOT NULL DEFAULT false,
    updated_at  timestamptz NOT NULL,
    rev         bigint      NOT NULL
);

COMMENT ON COLUMN habit.period IS 'day = le jour même ; week = lundi → dimanche ; month = 1er → dernier jour';

CREATE INDEX habit_rev_idx ON habit (rev);

CREATE TRIGGER habit_rev BEFORE INSERT OR UPDATE ON habit
    FOR EACH ROW EXECUTE FUNCTION bump_rev();

-- ---------------------------------------------------------------------
--  Historique : nombre de fois cochées par habitude et par jour (0 = effacé)
-- ---------------------------------------------------------------------
CREATE TABLE habit_log (
    habit_id    text        NOT NULL REFERENCES habit (id) ON DELETE CASCADE,
    day         date        NOT NULL,
    count       smallint    NOT NULL CHECK (count BETWEEN 0 AND 1000),
    updated_at  timestamptz NOT NULL,
    rev         bigint      NOT NULL,
    PRIMARY KEY (habit_id, day)
);

CREATE INDEX habit_log_rev_idx ON habit_log (rev);
CREATE INDEX habit_log_day_idx ON habit_log (day);

CREATE TRIGGER habit_log_rev BEFORE INSERT OR UPDATE ON habit_log
    FOR EACH ROW EXECUTE FUNCTION bump_rev();

-- ---------------------------------------------------------------------
--  Appareils associés (pas de compte : un jeton par téléphone)
-- ---------------------------------------------------------------------
CREATE TABLE device (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name          text        NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 60),
    token_hash    bytea       NOT NULL UNIQUE,   -- SHA-256 du jeton, jamais le jeton lui-même
    created_at    timestamptz NOT NULL DEFAULT now(),
    last_seen_at  timestamptz,
    revoked_at    timestamptz
);

-- ---------------------------------------------------------------------
--  Vue pratique : progression de chaque habitude par période
--  (date_trunc('week') démarre bien le lundi en PostgreSQL)
-- ---------------------------------------------------------------------
CREATE VIEW habit_period_progress AS
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
JOIN habit_log l ON l.habit_id = h.id AND l.count > 0
WHERE NOT h.deleted
GROUP BY h.id, h.name, h.period, h.target, period_start;
