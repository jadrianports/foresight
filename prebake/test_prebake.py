"""Unit tests for the prebake's PURE helpers (no network, no DB).

Match-effort-to-risk (project-context): the prebake's correctness risk is in the chart
math and the form-selection/badge logic — the parts that would ship silently-wrong data.
Those are pure functions here and are tested with fixture JSON. The network + DB write are
verified by actually running the prebake (Story Task 8), not mocked here.

Run:  python -m pytest prebake/test_prebake.py -q   (from repo root)
"""

import pytest

from prebake import (
    BATTLE_TYPES,
    build_type_chart,
    english_name,
    form_label_for,
    form_suffix,
    multiplier_from_damage_relations,
    ordered_types,
    sprite_path_for,
    types_key,
)


def _ref(*names):
    return [{"name": n} for n in names]


def _full_damage_relations():
    """A minimal-but-complete {attacking: damage_relations} for all 18 battle types.
    Only `fire` carries real deviations; the rest are all-1x (empty arrays). Enough to
    prove the dense-fill + 324 invariant without reproducing the whole real chart."""
    drs = {t: {"double_damage_to": [], "half_damage_to": [], "no_damage_to": []}
           for t in BATTLE_TYPES}
    drs["fire"] = {
        "double_damage_to": _ref("bug", "steel", "grass", "ice"),
        "half_damage_to": _ref("rock", "fire", "water", "dragon"),
        "no_damage_to": [],
    }
    return drs


# --- multiplier_from_damage_relations ------------------------------------------------

def test_multiplier_maps_three_buckets():
    dr = {
        "double_damage_to": _ref("bug", "grass"),
        "half_damage_to": _ref("water"),
        "no_damage_to": _ref("dragon"),
    }
    out = multiplier_from_damage_relations(dr)
    assert out == {"bug": 2.0, "grass": 2.0, "water": 0.5, "dragon": 0.0}


def test_multiplier_handles_missing_keys():
    assert multiplier_from_damage_relations({}) == {}


# --- build_type_chart ----------------------------------------------------------------

def test_chart_is_dense_324_rows():
    rows = build_type_chart(_full_damage_relations())
    assert len(rows) == 324
    assert len({(a, d) for a, d, _ in rows}) == 324  # no duplicate pairs


def test_chart_multipliers_are_legal_and_deviations_applied():
    rows = build_type_chart(_full_damage_relations())
    m = {(a, d): mult for a, d, mult in rows}
    assert all(v in (0.0, 0.5, 1.0, 2.0) for v in m.values())
    # fire deviations
    assert m[("fire", "grass")] == 2.0
    assert m[("fire", "water")] == 0.5
    # un-named pair defaults to dense 1x (explicit row, not a missing lookup)
    assert m[("fire", "normal")] == 1.0
    assert m[("normal", "normal")] == 1.0


def test_chart_is_sorted_for_determinism():
    rows = build_type_chart(_full_damage_relations())
    assert rows == sorted(rows)


def test_chart_rejects_wrong_type_set():
    drs = _full_damage_relations()
    del drs["fairy"]
    with pytest.raises(ValueError, match="missing"):
        build_type_chart(drs)


def test_chart_rejects_non_battle_type_in_relations():
    drs = _full_damage_relations()
    drs["fire"]["double_damage_to"].append({"name": "stellar"})
    with pytest.raises(ValueError, match="non-battle"):
        build_type_chart(drs)


# --- typing helpers ------------------------------------------------------------------

def test_types_key_is_slot_order_insensitive():
    a = [{"slot": 1, "type": {"name": "ice"}}, {"slot": 2, "type": {"name": "fairy"}}]
    b = [{"slot": 1, "type": {"name": "fairy"}}, {"slot": 2, "type": {"name": "ice"}}]
    assert types_key(a) == types_key(b)


def test_ordered_types_sorts_by_slot():
    t = [{"slot": 2, "type": {"name": "flying"}}, {"slot": 1, "type": {"name": "fire"}}]
    assert ordered_types(t) == [(1, "fire"), (2, "flying")]


# --- form suffix + label -------------------------------------------------------------

def test_form_suffix_basic_and_hyphenated_species():
    assert form_suffix("charizard-mega-x", "charizard") == "mega-x"
    assert form_suffix("mr-mime-galar", "mr-mime") == "galar"
    assert form_suffix("tauros-paldea-combat-breed", "tauros") == "paldea-combat-breed"
    assert form_suffix("ninetales", "ninetales") is None  # not a '{species}-...' form


@pytest.mark.parametrize("slug,species,is_default,expected", [
    ("ninetales", "ninetales", True, (True, None)),            # base
    ("ninetales-alola", "ninetales", False, (True, "Alola")),
    ("meowth-galar", "meowth", False, (True, "Galar")),
    ("growlithe-hisui", "growlithe", False, (True, "Hisui")),
    ("kyogre-primal", "kyogre", False, (True, "Primal")),
    ("venusaur-mega", "venusaur", False, (True, "Mega")),
    ("charizard-mega-x", "charizard", False, (True, "Mega X")),
    ("charizard-mega-y", "charizard", False, (True, "Mega Y")),
    ("tauros-paldea-combat-breed", "tauros", False, (True, "Paldea")),
    ("mr-mime-galar", "mr-mime", False, (True, "Galar")),
    ("darmanitan-galar-standard", "darmanitan", False, (True, "Galar")),  # compound regional base
])
def test_form_label_in_scope(slug, species, is_default, expected):
    assert form_label_for(slug, species, is_default) == expected


@pytest.mark.parametrize("slug,species", [
    ("darmanitan-zen", "darmanitan"),         # mid-battle transform, not a lead form
    ("darmanitan-galar-zen", "darmanitan"),   # Galarian Zen transform — still excluded
])
def test_zen_transform_states_excluded(slug, species):
    assert form_label_for(slug, species, False) == (False, None)


@pytest.mark.parametrize("slug,species", [
    ("rotom-wash", "rotom"),
    ("wormadam-trash", "wormadam"),
    ("darmanitan-galar-zen", "darmanitan"),
    ("necrozma-dusk", "necrozma"),
    ("charizard-gmax", "charizard"),
])
def test_form_label_out_of_scope_is_excluded_not_misbadged(slug, species):
    # Out-of-scope typing-distinct forms: in_scope False, no (wrong) badge emitted.
    assert form_label_for(slug, species, False) == (False, None)


def test_mega_x_never_collides_with_mega():
    # The exact-remainder match is what prevents "-mega-x" -> "Mega".
    assert form_label_for("charizard-mega-x", "charizard", False) == (True, "Mega X")
    assert form_label_for("venusaur-mega", "venusaur", False) == (True, "Mega")


# --- sprite path (Windows forward-slash trap) ----------------------------------------

def test_sprite_path_is_forward_slash_assets_rooted():
    assert sprite_path_for("ninetales-alola") == "assets/sprites/ninetales-alola.png"
    assert "\\" not in sprite_path_for("charizard-mega-x")  # never a Windows backslash


# --- english_name --------------------------------------------------------------------

def test_english_name_prefers_en_entry():
    species = {"name": "mr-mime", "names": [
        {"language": {"name": "ja"}, "name": "バリヤード"},
        {"language": {"name": "en"}, "name": "Mr. Mime"},
    ]}
    assert english_name(species) == "Mr. Mime"


def test_english_name_falls_back_to_slug():
    assert english_name({"name": "ho-oh", "names": []}) == "Ho Oh"
