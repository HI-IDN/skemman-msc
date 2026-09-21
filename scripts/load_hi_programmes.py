"""Load HI's MS programme catalogue (config/hi_ms_programmes.yaml) into the database.

SQL cannot read YAML, so this step turns the catalogue into a table, hi_programme, one row per
programme and one per (programme, track), which scripts/discipline_map.sql then joins against.
The YAML stays the only place the catalogue is written -- like the analysis years in
config/collections.yaml.

  python scripts/load_hi_programmes.py [--db data/processed/thesis.db]
"""
import argparse
from pathlib import Path

import duckdb
import yaml

ROOT = Path(__file__).resolve().parent.parent


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "data" / "processed" / "thesis.db"))
    ap.add_argument("--catalogue", default=str(ROOT / "config" / "hi_ms_programmes.yaml"))
    args = ap.parse_args()

    programmes = yaml.safe_load(open(args.catalogue, encoding="utf-8"))["programmes"]
    rows = []
    for p in programmes:
        rows.append((p["name"], p.get("deild"), None, 0))
        for i, track in enumerate(p.get("tracks") or [], 1):
            rows.append((p["name"], p.get("deild"), track, i))

    with duckdb.connect(args.db) as con:
        con.execute("create or replace table hi_programme "
                    "(programme varchar, deild varchar, track varchar, track_no integer)")
        con.executemany("insert into hi_programme values (?, ?, ?, ?)", rows)
    n_prog = len(programmes)
    print(f"{n_prog} programmes, {len(rows) - n_prog} tracks loaded into hi_programme.")


if __name__ == "__main__":
    main()
