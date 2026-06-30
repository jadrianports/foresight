"""Canonical schema-version routine (AD-3).

`prebake/schema.sql` is the single source of truth for DB shape. `PRAGMA user_version`
is DERIVED from a hash of this file's *normalized* contents — the prebake stamps it
(Story 1.3) and the Flutter app re-computes the same value and asserts equality on open
(Story 1.4). This module is the AUTHORITATIVE definition of that routine; the Dart side
must mirror it byte-for-byte.

ALGORITHM (reproduce exactly in any language):

  1. Input is the UTF-8 text of `schema.sql` (no BOM).
  2. normalize(text):
       a. remove /* ... */ block comments
       b. remove `--` line comments (to end of line)
       c. collapse every run of whitespace (spaces, tabs, newlines) to a single space
       d. strip leading/trailing whitespace
     We deliberately do NOT lowercase — identifiers and values are case-significant.
     Normalizing makes user_version track DB *shape*, not formatting (comment edits,
     CRLF vs LF on Windows, indentation) — so cosmetic diffs don't force a needless
     re-copy / assert failure, while any real shape change does.
  3. digest = SHA-256(normalized.encode('utf-8'))
  4. user_version = int.from_bytes(digest[:4], 'big') & 0x7FFFFFFF
     (first 4 bytes, big-endian, masked to 31 bits so it fits SQLite's signed-32-bit
     PRAGMA user_version and stays positive.)
"""

from __future__ import annotations

import hashlib
import re
from pathlib import Path

_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_LINE_COMMENT = re.compile(r"--[^\n]*")
_WHITESPACE = re.compile(r"\s+")

SCHEMA_PATH = Path(__file__).with_name("schema.sql")


def normalize(schema_text: str) -> str:
    """Strip comments, collapse whitespace, trim. See module docstring for the spec."""
    text = _BLOCK_COMMENT.sub(" ", schema_text)
    text = _LINE_COMMENT.sub(" ", text)
    text = _WHITESPACE.sub(" ", text)
    return text.strip()


def compute_user_version(schema_text: str) -> int:
    """Map normalized schema text -> the signed-32-bit-safe PRAGMA user_version."""
    digest = hashlib.sha256(normalize(schema_text).encode("utf-8")).digest()
    return int.from_bytes(digest[:4], "big") & 0x7FFFFFFF


def user_version_for_file(path: Path = SCHEMA_PATH) -> int:
    return compute_user_version(path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    raw = SCHEMA_PATH.read_text(encoding="utf-8")
    version = compute_user_version(raw)
    print(f"schema.sql user_version = {version}")

    # Idempotence: computing twice yields the same value.
    assert compute_user_version(raw) == version, "non-deterministic hash"

    # Whitespace/comment-insensitivity: a cosmetic edit must NOT change the version.
    cosmetic = "/* banner */\n\n" + raw.replace("\n", "\n   ") + "\n-- trailing note\n"
    assert compute_user_version(cosmetic) == version, "normalization not whitespace-stable"

    # A real shape change MUST change the version (guards against an over-eager normalize).
    shape_change = raw.replace("viewed_at  INTEGER NOT NULL", "viewed_at INTEGER")
    assert compute_user_version(shape_change) != version, "shape change did not move version"

    print("self-check OK: deterministic, whitespace-stable, shape-sensitive")
