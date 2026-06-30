"""Foresight prebake (Story 1.3) — fetch PokeAPI ONCE and emit the bundled read-only
DB + sprite PNGs that the Flutter app reads. This is the SOLE writer of assets/db/ and
assets/sprites/ (AD-8) and the ONLY code in the repo that touches the network (AD-1).

Run:  python prebake.py            (from prebake/)
  or  python prebake/prebake.py    (from repo root)

Contract it must hit (populates the fixed Story-1.2 schema — never alters it):
  * pokemon(id PK = PokeAPI id, slug UNIQUE, name, form_label NULL=base, sprite_path)
  * pokemon_types(pokemon_id, slot, type_name[lowercase slug])
  * type_chart(attacking_type, defending_type, multiplier)  -- DENSE 18x18 = 324 rows
  * recent_views                                             -- NOT written (app-only, AD-5)
  * PRAGMA user_version = hash of schema.sql (via schema_version.py)

Design (AD-2-style separation, even though this is Python): the network lives in ONE
place (`PokeApiClient`); everything else (`build_type_chart`, `form_label_for`,
`types_key`, `sprite_path_for`) is a PURE function so it can be unit-tested with fixture
JSON and no network. The worst failure for this app is silently-wrong data, so every
contract violation raises loudly rather than defaulting (AD-7).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import sys
import time
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

import requests

from schema_version import user_version_for_file

# --- Paths (all relative to the repo, derived from this file's location) -------------
PREBAKE_DIR = Path(__file__).resolve().parent
REPO_ROOT = PREBAKE_DIR.parent
SCHEMA_SQL = PREBAKE_DIR / "schema.sql"
CACHE_DIR = PREBAKE_DIR / ".cache"
ASSETS_DIR = REPO_ROOT / "assets"
DB_PATH = ASSETS_DIR / "db" / "foresight.db"
SPRITES_DIR = ASSETS_DIR / "sprites"

API_BASE = "https://pokeapi.co/api/v2"
USER_AGENT = "foresight-prebake/1.0 (offline dex builder; non-commercial; PokeAPI fair-use)"

# The 18 battle types are the only valid type vocabulary. PokeAPI's /type endpoint also
# returns non-battle pseudo-types we must exclude (confirmed: stellar id 19, unknown
# 10001, shadow 10002). We key off this allow-list rather than a numeric id cutoff.
BATTLE_TYPES = frozenset({
    "normal", "fighting", "flying", "poison", "ground", "rock", "bug", "ghost",
    "steel", "fire", "water", "grass", "electric", "psychic", "ice", "dragon",
    "dark", "fairy",
})
NON_BATTLE_TYPES = frozenset({"unknown", "shadow", "stellar", "???"})

# Form-suffix -> exact badge string (AD-4). The app treats form_label as opaque; the
# prebake OWNS this mapping. Scope = Option B (regional + Mega + Primal). A typing-distinct
# form whose suffix is NOT here is out of v1 scope: logged + skipped, never silently
# dropped and never given a wrong/empty badge. Matched by EXACT remainder after stripping
# the species-name prefix, so "-mega-x" can never collide with "-mega".
FORM_BADGES: dict[str, str] = {
    "alola": "Alola",
    "galar": "Galar",
    # Galarian Darmanitan's leadable form is slugged `-galar-standard` (Ice); its Zen
    # transformation (`-galar-zen`) and the mainline `-zen` are mid-battle states we don't
    # surface as opponents. The `-standard` regional base IS a regional form (Option B).
    "galar-standard": "Galar",
    "hisui": "Hisui",
    "paldea": "Paldea",
    "paldea-combat-breed": "Paldea",
    "paldea-blaze-breed": "Paldea",
    "paldea-aqua-breed": "Paldea",
    "mega": "Mega",
    "mega-x": "Mega X",
    "mega-y": "Mega Y",
    "primal": "Primal",
}


# === Pure helpers (no network, no DB — unit-tested in test_prebake.py) ================

def multiplier_from_damage_relations(damage_relations: dict) -> dict[str, float]:
    """Map ONE attacking type's `damage_relations` -> {defending_slug: multiplier}.

    Only the three "*_to" arrays are needed (the "*_from" arrays are the same data from
    the defender's side). The API lists only deviations from 1x, so any battle type not
    named defaults to 1.0. Returns ONLY the deviations; the dense fill happens in
    build_type_chart so the 1x default is explicit there.
    """
    out: dict[str, float] = {}
    for ref in damage_relations.get("double_damage_to", []):
        out[ref["name"]] = 2.0
    for ref in damage_relations.get("half_damage_to", []):
        out[ref["name"]] = 0.5
    for ref in damage_relations.get("no_damage_to", []):
        out[ref["name"]] = 0.0
    return out


def build_type_chart(damage_relations_by_type: dict[str, dict]) -> list[tuple[str, str, float]]:
    """Build the DENSE 324-row chart from {attacking_slug: damage_relations}.

    For every (attacking, defending) pair over the 18 battle types: seed 1.0, then
    overwrite with any deviation from the attacking type's damage_relations. Emits all
    324 rows explicitly (incl. 1x and 0x) — a missing row is a loud violation later
    (AD-7), never a silent 1x. Sorted by (attacking, defending) for deterministic output.
    """
    attackers = sorted(damage_relations_by_type)
    if set(attackers) != set(BATTLE_TYPES):
        missing = BATTLE_TYPES - set(attackers)
        extra = set(attackers) - BATTLE_TYPES
        raise ValueError(f"type set wrong: missing={sorted(missing)} extra={sorted(extra)}")

    rows: list[tuple[str, str, float]] = []
    for atk in attackers:
        deviations = multiplier_from_damage_relations(damage_relations_by_type[atk])
        # A deviation naming a non-battle type would corrupt the chart — refuse it.
        bad = set(deviations) - BATTLE_TYPES
        if bad:
            raise ValueError(f"{atk} damage_relations reference non-battle types: {sorted(bad)}")
        for dfn in sorted(BATTLE_TYPES):
            mult = deviations.get(dfn, 1.0)
            if mult not in (0.0, 0.5, 1.0, 2.0):
                raise ValueError(f"illegal multiplier {mult} for {atk}->{dfn}")
            rows.append((atk, dfn, mult))
    if len(rows) != 324:
        raise ValueError(f"expected 324 chart rows, got {len(rows)}")
    return rows


def types_key(types: list[dict]) -> frozenset[str]:
    """A slot-order-insensitive key for a Pokémon's typing (set of lowercase slugs).

    Two forms with the same types in swapped slots are NOT typing-distinct.
    """
    return frozenset(t["type"]["name"] for t in types)


def ordered_types(types: list[dict]) -> list[tuple[int, str]]:
    """(slot, type_name) pairs sorted by slot — for pokemon_types rows."""
    return sorted((t["slot"], t["type"]["name"]) for t in types)


def form_suffix(slug: str, species_name: str) -> str | None:
    """The form remainder after the species-name prefix, e.g.
    ('charizard-mega-x','charizard') -> 'mega-x'. None if slug isn't a '{species}-...' form.
    Robust to hyphenated species names (mr-mime -> mr-mime-galar -> 'galar')."""
    prefix = species_name + "-"
    if not slug.startswith(prefix):
        return None
    return slug[len(prefix):]


def form_label_for(slug: str, species_name: str, is_default: bool) -> tuple[bool, str | None]:
    """Decide inclusion + badge for a variety (AD-4).

    Returns (in_scope, label):
      * base/default form               -> (True, None)
      * in-scope alt (regional/Mega/Primal per Option B) -> (True, badge)
      * out-of-scope typing-distinct alt -> (False, None)  [caller logs + skips]
    """
    if is_default:
        return True, None
    suffix = form_suffix(slug, species_name)
    if suffix is not None and suffix in FORM_BADGES:
        return True, FORM_BADGES[suffix]
    return False, None


def sprite_path_for(slug: str) -> str:
    """Complete forward-slash, assets/-rooted Flutter asset key (AD-4). NEVER os.path.join
    (Windows backslash trap) — PurePosixPath guarantees '/'."""
    return str(PurePosixPath("assets") / "sprites" / f"{slug}.png")


def english_name(species_json: dict) -> str:
    """Proper display name from species `names` (en), e.g. 'Mr. Mime', 'Ho-Oh'.
    Falls back to a title-cased slug if no English entry exists."""
    for entry in species_json.get("names", []):
        if entry.get("language", {}).get("name") == "en":
            return entry["name"]
    return species_json["name"].replace("-", " ").title()


# === Network (the ONLY place that touches the wire — AD-1) ============================

class PokeApiClient:
    def __init__(self, polite_delay: float = 0.0):
        self.session = requests.Session()
        self.session.headers.update({"User-Agent": USER_AGENT})
        self.polite_delay = polite_delay
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        self.network_hits = 0

    def _cache_file(self, url: str) -> Path:
        return CACHE_DIR / (hashlib.sha256(url.encode("utf-8")).hexdigest() + ".json")

    def get_json(self, url: str) -> dict:
        """Cached GET. A re-run reads the on-disk cache and does NOT re-hit the network
        unless the entry is missing (idempotence; PokeAPI fair-use). A cache entry left
        truncated by an interrupted prior run (partial write) is treated as missing and
        re-fetched rather than wedging the run on a JSONDecodeError."""
        cf = self._cache_file(url)
        if cf.exists():
            try:
                return json.loads(cf.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                # Corrupt/truncated cache (e.g. crash mid-write) — heal by re-fetching.
                cf.unlink()
        if self.polite_delay:
            time.sleep(self.polite_delay)
        resp = self.session.get(url, timeout=60)
        resp.raise_for_status()
        data = resp.json()
        # Atomic write (temp + replace) so an interrupted run can't leave truncated JSON.
        tmp = cf.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(data), encoding="utf-8")
        tmp.replace(cf)
        self.network_hits += 1
        return data

    def get_resource(self, kind: str, name_or_id: str | int) -> dict:
        return self.get_json(f"{API_BASE}/{kind}/{name_or_id}")

    def list_all(self, kind: str) -> list[dict]:
        return self.get_json(f"{API_BASE}/{kind}?limit=100000")["results"]

    def download_sprite(self, url: str, dest: Path) -> None:
        """Download a sprite PNG to dest. Skips if the file already exists (idempotence)."""
        if dest.exists() and dest.stat().st_size > 0:
            return
        if self.polite_delay:
            time.sleep(self.polite_delay)
        resp = self.session.get(url, timeout=60)
        resp.raise_for_status()
        content = resp.content
        if not content:
            raise ValueError(f"empty sprite body from {url}")
        dest.parent.mkdir(parents=True, exist_ok=True)
        # Atomic write (temp + replace): a run killed mid-write must not leave a non-empty
        # but truncated PNG that the size>0 skip-gate would then trust forever.
        tmp = dest.with_suffix(".png.tmp")
        tmp.write_bytes(content)
        tmp.replace(dest)
        self.network_hits += 1


# === Row models gathered before the DB write =========================================

@dataclass
class PokemonRow:
    id: int
    slug: str
    name: str
    form_label: str | None
    sprite_path: str
    types: list[tuple[int, str]]  # (slot, type_name)
    sprite_url: str | None


# === Orchestration ====================================================================

def gather_type_chart(client: PokeApiClient) -> list[tuple[str, str, float]]:
    damage_relations_by_type: dict[str, dict] = {}
    for ref in client.list_all("type"):
        slug = ref["name"]
        if slug in NON_BATTLE_TYPES or slug not in BATTLE_TYPES:
            continue
        damage_relations_by_type[slug] = client.get_resource("type", slug)["damage_relations"]
    return build_type_chart(damage_relations_by_type)


def gather_pokemon(client: PokeApiClient, limit: int | None = None) -> tuple[list[PokemonRow], list[str]]:
    """Walk species -> varieties; emit base + typing-distinct in-scope forms.
    Returns (rows, excluded_typing_distinct_slugs)."""
    species_refs = client.list_all("pokemon-species")
    if limit is not None:
        species_refs = species_refs[:limit]

    rows: list[PokemonRow] = []
    excluded: list[str] = []

    for sref in species_refs:
        species = client.get_resource("pokemon-species", sref["name"])
        disp_name = english_name(species)

        # Fetch every variety's /pokemon up front so we can compare typings.
        varieties = []
        for v in species["varieties"]:
            poke = client.get_resource("pokemon", v["pokemon"]["name"])
            varieties.append((bool(v["is_default"]), poke))

        defaults = [p for is_def, p in varieties if is_def]
        if len(defaults) != 1:
            # Exactly one base form per species is the PokeAPI invariant. Zero or two
            # would silently pick a wrong base_key and mis-skip a typing-distinct form
            # (silently-wrong data, AD-7) — fail loud instead.
            raise ValueError(
                f"species {species['name']} has {len(defaults)} is_default varieties — expected 1"
            )
        base = defaults[0]
        base_key = types_key(base["types"])

        for is_default, poke in varieties:
            slug = poke["name"]
            this_key = types_key(poke["types"])
            if not is_default and this_key == base_key:
                continue  # same typing as base -> omit entirely (PRD §5.2)

            in_scope, label = form_label_for(slug, species["name"], is_default)
            if not in_scope:
                excluded.append(slug)  # typing-distinct but out of v1 scope (Option B)
                continue

            # Every leadable Pokémon has 1-2 types. 0 or >2 means bad upstream data
            # (e.g. the non-canonical `meowstic-female-mega` returns []). Fail loud rather
            # than ship a typeless row that would yield silently-wrong advice (AD-7).
            ntypes = len(poke["types"])
            if ntypes not in (1, 2):
                raise ValueError(f"{slug} has {ntypes} types {this_key} — expected 1 or 2")

            # Slots must be the distinct set {1} or {1,2}. Duplicate-slot upstream data
            # would otherwise pass the count check above and only surface as a
            # pokemon_types PK IntegrityError mid-write — fail loud here instead (AD-7).
            otypes = ordered_types(poke["types"])
            slots = [slot for slot, _ in otypes]
            if slots != [1] and slots != [1, 2]:
                raise ValueError(f"{slug} has non-canonical type slots {slots} — expected [1] or [1,2]")

            rows.append(PokemonRow(
                id=poke["id"],
                slug=slug,
                name=disp_name,
                form_label=label,
                sprite_path=sprite_path_for(slug),
                types=otypes,
                sprite_url=poke["sprites"]["front_default"],
            ))

    rows.sort(key=lambda r: r.id)
    return rows, excluded


def prune_orphan_sprites(rows: list[PokemonRow]) -> list[str]:
    """Delete any sprite PNG whose slug isn't in the current row set. The DB is rebuilt
    clean each run, but SPRITES_DIR is not — without pruning, a form removed/renamed
    between runs leaves an orphaned (committed) PNG, and a stale PNG for a now-null-URL
    slug would let verify_sprites_exist pass on a wrong image. Keeps the skip-existing
    fair-use behavior for in-set sprites. Returns the slugs pruned."""
    if not SPRITES_DIR.exists():
        return []
    valid = {r.slug for r in rows}
    pruned: list[str] = []
    for png in SPRITES_DIR.glob("*.png"):
        if png.stem not in valid:
            png.unlink()
            pruned.append(png.stem)
    return sorted(pruned)


def download_all_sprites(client: PokeApiClient, rows: list[PokemonRow]) -> list[str]:
    """Download every row's sprite. Returns slugs with a null/absent sprite URL (the
    sprite-existence check in write+verify will fail loudly on these)."""
    missing_url: list[str] = []
    for r in rows:
        if not r.sprite_url:
            missing_url.append(r.slug)
            continue
        client.download_sprite(r.sprite_url, REPO_ROOT / r.sprite_path)
    return missing_url


def write_db(rows: list[PokemonRow], chart: list[tuple[str, str, float]]) -> int:
    """Rebuild assets/db/foresight.db from scratch, deterministically. Returns the stamped
    user_version. Does NOT write recent_views (app-only, AD-5)."""
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    if DB_PATH.exists():
        DB_PATH.unlink()  # rebuild clean — stale rows can't survive a re-run

    version = user_version_for_file()  # derived from schema.sql (AD-3), never hard-coded
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.executescript(SCHEMA_SQL.read_text(encoding="utf-8"))

        # Deterministic order: pokemon by id, types by (id, slot), chart by (atk, def).
        conn.executemany(
            "INSERT INTO pokemon(id, slug, name, form_label, sprite_path) VALUES (?,?,?,?,?)",
            [(r.id, r.slug, r.name, r.form_label, r.sprite_path) for r in sorted(rows, key=lambda r: r.id)],
        )
        type_rows = sorted(
            ((r.id, slot, tname) for r in rows for (slot, tname) in r.types),
            key=lambda t: (t[0], t[1]),
        )
        conn.executemany(
            "INSERT INTO pokemon_types(pokemon_id, slot, type_name) VALUES (?,?,?)", type_rows
        )
        conn.executemany(
            "INSERT INTO type_chart(attacking_type, defending_type, multiplier) VALUES (?,?,?)",
            sorted(chart),
        )
        conn.execute(f"PRAGMA user_version = {int(version)}")  # PRAGMA can't bind params
        conn.commit()

        stamped = conn.execute("PRAGMA user_version").fetchone()[0]
        if stamped != version:
            raise ValueError(f"user_version read-back {stamped} != {version}")
    finally:
        conn.close()
    return version


def verify_sprites_exist(rows: list[PokemonRow]) -> list[str]:
    """Build-time existence check (AD-4): every sprite_path must resolve to a real file."""
    return [r.slug for r in rows if not (REPO_ROOT / r.sprite_path).is_file()]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Foresight prebake: PokeAPI -> bundled DB + sprites.")
    parser.add_argument("--limit", type=int, default=None,
                        help="(dev only) process just the first N species for a smoke test.")
    parser.add_argument("--polite-delay", type=float, default=0.0,
                        help="seconds to sleep between live network calls (cache hits never sleep).")
    args = parser.parse_args(argv)

    client = PokeApiClient(polite_delay=args.polite_delay)

    print("[1/4] building dense type chart ...")
    chart = gather_type_chart(client)
    print(f"      {len(chart)} chart rows")

    print("[2/4] gathering pokemon + typing-distinct forms ...")
    rows, excluded = gather_pokemon(client, limit=args.limit)
    print(f"      {len(rows)} pokemon rows ({sum(1 for r in rows if r.form_label)} alt forms)")
    if excluded:
        print(f"      {len(excluded)} typing-distinct forms EXCLUDED (out of v1 scope, Option B):")
        for slug in sorted(excluded):
            print(f"        - {slug}")

    print("[3/4] downloading sprites ...")
    pruned = prune_orphan_sprites(rows)
    if pruned:
        print(f"      pruned {len(pruned)} orphaned sprite(s): {pruned}")
    null_url = download_all_sprites(client, rows)
    if null_url:
        print(f"      WARNING: {len(null_url)} rows have a null sprite URL: {sorted(null_url)}")

    # Verify BEFORE writing the DB: a failed run must not leave a valid-looking,
    # correctly-versioned foresight.db on disk that references missing sprites (AD-4).
    print("[4/4] verifying sprites + writing DB ...")
    missing = verify_sprites_exist(rows)
    if missing:
        print(f"FAIL: {len(missing)} sprite_path(s) do not resolve to a file:", file=sys.stderr)
        for slug in sorted(missing):
            print(f"  - {slug} -> {sprite_path_for(slug)}", file=sys.stderr)
        return 1
    version = write_db(rows, chart)

    print(f"OK: {DB_PATH.relative_to(REPO_ROOT)} written. "
          f"user_version={version}, pokemon={len(rows)}, chart={len(chart)}, "
          f"network_hits={client.network_hits}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
