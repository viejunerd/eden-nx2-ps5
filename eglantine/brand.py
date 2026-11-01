#!/usr/bin/env python3
"""Rebrand the ProsperoEden frontend as Eglantine, visually only.

    brand.py <ProsperoEden checkout> [--dry-run]

Changes the word ProsperoEden inside double-quoted string literals of the C++ sources, the
.po/.pot catalogs (msgids and translations alike, so lookups keep matching) and
tools/launcher/strings.py, plus sce_sys/param.json titleName. Idempotent, so it can be re-run
after merging a newer ProsperoEden.

Deliberately NOT touched, so Eglantine and ProsperoEden can sit side by side on one console and
share /data/prosperoeden (keys, firmware, roms, config):
  * paths and file names (/data/prosperoeden, prosperoeden.json, headless/prosperoeden/);
  * identifiers (SelectProsperoEdenGame) and URLs;
  * log lines and the crash report header ("[ProsperoEden] ...", fprintf(stderr, ...), Report(...));
  * the HTTP user agent and the RomM client name;
  * anything that credits BlackBearReloaded, so the attribution stays true.
"""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
dry = "--dry-run" in sys.argv

NAME_NEW = "Eglantine"
KEEP_LITERAL = ("github.com", "http", "blackbear", "mrggbond", "swordpdf", "/data/", ".json", "crash report")
KEEP_LINE = ("fprintf(stderr", "DebugOutText", "Report(", "CURLOPT_USERAGENT", '"client"', "(PS5)", "snprintf(line", "fputs(")
LITERAL = re.compile(r'"(?:[^"\\\n]|\\.)*"')
WORD = re.compile(r"\bProsperoEden\b")
SOURCE_EXT = {".cpp", ".h", ".hpp", ".c", ".po", ".pot"}


def rename_literal(m):
    lit = m.group(0)
    low = lit.lower()
    if lit.startswith('"[') or any(k in low for k in KEEP_LITERAL):
        return lit
    return WORD.sub(NAME_NEW, lit)


def rename_line(line):
    if any(k in line for k in KEEP_LINE):
        return line
    return LITERAL.sub(rename_literal, line)


changed = []


def process(path):
    try:
        text = path.read_text()
    except (UnicodeDecodeError, FileNotFoundError):
        return
    new = "".join(rename_line(l) for l in text.splitlines(keepends=True))
    if new != text:
        changed.append(str(path.relative_to(root)))
        if not dry:
            path.write_text(new)


for f in (root / "headless").rglob("*"):
    if f.is_file() and f.suffix in SOURCE_EXT:
        process(f)
process(root / "tools/launcher/strings.py")

param = root / "sce_sys/param.json"
if param.exists():
    text = param.read_text()
    new = re.sub(r'("titleName"\s*:\s*")ProsperoEden(")', rf"\g<1>{NAME_NEW}\g<2>", text)
    if new != text:
        changed.append("sce_sys/param.json")
        if not dry:
            param.write_text(new)

print(f"changed: {len(changed)} files" if changed else "nothing to change (already branded)")
if dry:
    print("(dry run, nothing written)")
