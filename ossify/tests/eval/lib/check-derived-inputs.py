#!/usr/bin/env python3
"""Presence only, for boundary-audit-integrity's seven mechanical input classes.

The derived-inputs table owns every phrase. No synonyms, score interpretation,
or inference of correctness/sufficiency; those remain with the judge. Whitespace
wrapping is ignored, but case and punctuation are literal. Per-repo phrases name
each subject in the contract's repository set; a new set owes a contract update.
"""
from pathlib import Path
import re
import sys

SURFACE = "boundary-audit-integrity"
CLASSES = {"I2", "I4", "I6", "I10", "I23", "I26", "I27"}


def check(eval_dir: Path) -> int:
    contract = (eval_dir / "derived-inputs" / f"{SURFACE}.md").read_text(encoding="utf-8")
    section = contract.split("<!-- presence-contract -->", 1)[1].split(
        "<!-- /presence-contract -->", 1
    )[0]
    subjects_line = next(line for line in section.splitlines() if line.startswith("Repos: "))
    subjects = subjects_line.removeprefix("Repos: ").split("; ")
    if not all(subjects) or len(set(subjects)) != len(subjects):
        raise ValueError("invalid repository subjects")
    rows = {}
    for line in section.splitlines():
        if not re.match(r"\| I\d+ \|", line):
            continue
        key, scope, phrase = (cell.strip() for cell in line.strip("|").split("|"))
        if key in rows or scope not in {"set", "per-repo"} or not phrase:
            raise ValueError(f"invalid contract row {key}")
        if (scope == "per-repo") != ("{repo}" in phrase):
            raise ValueError(f"invalid repository placeholder in {key}")
        rows[key] = (scope, phrase)
    if rows.keys() != CLASSES:
        raise ValueError("contract must declare exactly I2, I4, I6, I10, I23, I26, I27")
    fixtures = sorted((eval_dir / "fixtures" / SURFACE).glob("*.md"))
    if not fixtures:
        raise ValueError("no fixtures found")
    missing = 0
    for fixture in fixtures:
        body = fixture.read_text(encoding="utf-8").removeprefix("\ufeff")
        opener = re.match(r"(?:[ \t]*\n)*---[ \t]*(?:\n|$)", body)
        if opener is not None:
            end = re.search(r"^---[ \t]*$", body[opener.end():], re.MULTILINE)
            if end is None:
                raise ValueError(f"unterminated frontmatter: {fixture.name}")
            body = body[opener.end() + end.end():]
        body = " ".join(body.split())
        for key, (scope, phrase) in rows.items():
            for repo in subjects if scope == "per-repo" else [None]:
                required = phrase.replace("{repo}", repo) if repo else phrase
                if required not in body:
                    label = f"{key} ({repo})" if repo else key
                    print(f"MISSING: {SURFACE}/{fixture.stem} — {label}: {required}")
                    missing += 1
    print(f"Derived-input presence: {len(fixtures)} fixture(s), {missing} missing declaration(s)")
    return int(missing > 0)


if __name__ == "__main__":
    try:
        if len(sys.argv) > 2:
            raise ValueError("usage: check-derived-inputs.py [eval-directory]")
        directory = Path(sys.argv[1]) if len(sys.argv) == 2 else Path(__file__).resolve().parent.parent
        sys.exit(check(directory))
    except (OSError, ValueError, IndexError, StopIteration) as error:
        print(f"PRESENCE-CHECK UNAVAILABLE: {error}", file=sys.stderr)
        sys.exit(2)
