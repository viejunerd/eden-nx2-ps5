#!/usr/bin/env python3
"""Rebrand the ProsperoEden frontend as Eglantine: what the user sees, and where data lives.

    brand.py <ProsperoEden checkout> [--dry-run]

Changes (idempotent, so it can be re-run after merging a newer ProsperoEden):
  * the word ProsperoEden inside double-quoted string literals of the C++ sources, the .po/.pot
    catalogs (msgids and translations alike, so lookups keep matching) and tools/launcher/strings.py;
  * /data/prosperoeden -> /data/eglantine and prosperoeden.json -> eglantine.json;
  * sce_sys/param.json titleName.
Left alone on purpose: identifiers and file names (SelectProsperoEdenGame, headless/prosperoeden/),
URLs, and any string that credits BlackBearReloaded, so the attribution stays true.
"""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
dry = "--dry-run" in sys.argv

NAME_OLD, NAME_NEW = "ProsperoEden", "Eglantine"
PATH_SWAPS = [("/data/prosperoeden", "/data/eglantine"), ("prosperoeden.json", "eglantine.json")]
KEEP = ("github.com", "http", "blackbear", "mrggbond", "swordpdf")
LITERAL = re.compile(r'"(?:[^"\\\n]|\\.)*"')
WORD = re.compile(r"\bProsperoEden\b")

SOURCE_EXT = {".cpp", ".h", ".hpp", ".c", ".po", ".pot"}
PATH_EXT = SOURCE_EXT | {".inc", ".py", ".sh", ".cmake", ".txt", ".json"}


def rename_literal(m):
    lit = m.group(0)
    if any(k in lit.lower() for k in KEEP):
        return lit
    return WORD.sub(NAME_NEW, lit)


def files_under(*parts):
    for p in parts:
        base = root / p
        if base.is_file():
            yield base
        elif base.is_dir():
            yield from (f for f in base.rglob("*") if f.is_file())


changed = {}


def write(path, text, original, kind):
    if text != original:
        changed.setdefault(kind, []).append(str(path.relative_to(root)))
        if not dry:
            path.write_text(text)


# 1. Display strings
for f in list(files_under("headless")) + [root / "tools/launcher/strings.py"]:
    if f.suffix not in SOURCE_EXT and f.name != "strings.py":
        continue
    try:
        text = f.read_text()
    except (UnicodeDecodeError, FileNotFoundError):
        continue
    write(f, LITERAL.sub(rename_literal, text), text, "names")

# 2. Data folder and config file name
for f in list(files_under("headless", "tools", "Makefile")):
    if f.suffix not in PATH_EXT and f.name != "Makefile":
        continue
    try:
        text = f.read_text()
    except UnicodeDecodeError:
        continue
    new = text
    for old, repl in PATH_SWAPS:
        new = new.replace(old, repl)
    write(f, new, text, "paths")

# 3. Package metadata
param = root / "sce_sys/param.json"
if param.exists():
    text = param.read_text()
    write(param, re.sub(r'("titleName"\s*:\s*")ProsperoEden(")', rf"\g<1>{NAME_NEW}\g<2>", text), text, "param")

for kind, names in changed.items():
    print(f"{kind}: {len(names)} files")
if not changed:
    print("nothing to change (already branded)")
if dry:
    print("(dry run, nothing written)")
