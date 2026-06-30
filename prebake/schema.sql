-- Foresight — canonical DB shape (AD-3 single source of truth).
--
-- This file is THE contract between the Python prebake (which writes the bundled DB)
-- and the Flutter app (which only ever reads it). PRAGMA user_version is DERIVED from a
-- hash of this file's normalized contents (see prebake/schema_version.py): the prebake
-- stamps it, the app re-computes the same hash and asserts equality on open. So a shape
-- change with a forgotten version bump still fails LOUD — never silently serves a stale DB.
--
-- Rules baked into this contract:
--   * recent_views is the ONLY table the app writes (AD-5). Everything else is READ-ONLY.
--   * Type vocabulary is ALWAYS lowercase PokeAPI slugs ('fire', 'dark', ...). SQLite can't
--     cheaply enforce that, so it is a convention: capitalize for DISPLAY only, never in a key
--     or a query. A 'Fire' value here would silently return zero rows downstream.
--   * pokemon.id is the PokeAPI id — assigned upstream, so NO AUTOINCREMENT.
--   * form_label is the exact badge string ('Alola'/'Galar'/'Mega'/'Mega X'/'Primal') or NULL
--     for base forms — never an empty string. The prebake owns that value (AD-4).
--   * The 18x18 type_chart is materialized DENSE (full 324 rows incl. explicit 1x and 0x) by
--     the prebake (Story 1.3). A missing (attacking,defending) row is a loud violation later
--     (AD-7), never a silent 1x.
--   * assets/db/ is a regenerable artifact — never hand-edit the generated DB (AD-8).

PRAGMA foreign_keys = ON;

-- One row per typing-distinct Pokémon form. id = PokeAPI id (no AUTOINCREMENT).
CREATE TABLE pokemon (
  id          INTEGER PRIMARY KEY,          -- PokeAPI id; assigned upstream
  slug        TEXT    NOT NULL UNIQUE,       -- natural debug key, e.g. 'ninetales-alola'
  name        TEXT    NOT NULL,              -- display name, e.g. 'Ninetales'
  form_label  TEXT,                          -- exact badge string, or NULL for base forms (AD-4)
  sprite_path TEXT    NOT NULL               -- complete forward-slash assets/-rooted key (AD-4)
);

-- A Pokémon's 1-2 types. slot 1 = primary, slot 2 = secondary. type_name = lowercase slug.
CREATE TABLE pokemon_types (
  pokemon_id  INTEGER NOT NULL REFERENCES pokemon(id),
  slot        INTEGER NOT NULL,             -- 1 or 2
  type_name   TEXT    NOT NULL,             -- lowercase PokeAPI slug
  PRIMARY KEY (pokemon_id, slot)
);

-- Dense 18x18 = 324-row effectiveness chart. Both type columns are lowercase slugs.
-- multiplier is exactly one of {0, 0.5, 1, 2}. Populated dense by the prebake (Story 1.3).
CREATE TABLE type_chart (
  attacking_type TEXT NOT NULL,             -- lowercase slug
  defending_type TEXT NOT NULL,             -- lowercase slug
  multiplier     REAL NOT NULL,             -- {0, 0.5, 1, 2}
  PRIMARY KEY (attacking_type, defending_type)
);

-- The ONLY table the app writes (AD-5): insert/update on each Result view; read newest-first;
-- cap ~10 with oldest-eviction (enforced in app logic, Epic 3). viewed_at = epoch milliseconds.
CREATE TABLE recent_views (
  pokemon_id INTEGER NOT NULL REFERENCES pokemon(id),
  viewed_at  INTEGER NOT NULL,
  PRIMARY KEY (pokemon_id)
);
