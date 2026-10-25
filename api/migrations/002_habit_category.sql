-- =====================================================================
--  Catégorie d'une habitude (Ménage, Loisirs, Études…), texte libre.
--  '' = sans catégorie.
-- =====================================================================

ALTER TABLE habit
    ADD COLUMN category text NOT NULL DEFAULT ''
        CHECK (length(category) <= 40 AND category = btrim(category));

CREATE INDEX habit_category_idx ON habit (category) WHERE NOT deleted;
