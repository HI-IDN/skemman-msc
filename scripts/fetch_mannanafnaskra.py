"""Fetch Þjóðskrá's Mannanafnaskrá (the Icelandic given-name registry) into
data/processed/mannanafnaskra.csv, for a first-name gender fallback where the surname-ending rule
in scripts/licences.sql (v_licence_person.kyn) can't classify someone -- a family name that isn't
a patronymic, or a foreign surname.

Helper script -- needs the network, NOT part of rebuild.sh, like scripts/fetch_engineer_licences.py.
Uses scripts/mannanafnaskra.py, a small vendored copy of a standalone tool kept outside this repo
for reuse elsewhere (see that file's docstring). No personal data: this registry is about NAMES,
not people.

  python scripts/fetch_mannanafnaskra.py
"""
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from mannanafnaskra import fetch_all  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "processed" / "mannanafnaskra.csv"


def main():
    def progress(i, n, letter, count):
        print(f"  [{i}/{n}] {letter!r}: {count} unique so far", file=sys.stderr)

    rows = fetch_all(on_progress=progress)
    rows.sort(key=lambda e: (e["icelandicName"], e["id"]))
    with OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, ["id", "icelandicName", "type", "status", "verdict", "url"])
        w.writeheader()
        for e in rows:
            w.writerow({k: e.get(k) for k in w.fieldnames})
    print(f"{len(rows)} entries written to {OUT.name}", file=sys.stderr)


if __name__ == "__main__":
    main()
