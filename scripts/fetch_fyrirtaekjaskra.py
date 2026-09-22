"""Look up the organisations in config/organisations.yaml in Iceland's company register.

Issue #11, step 5a. For every gazetteer entry with a `kennitala:`, fetches its record from
Skatturinn's Company Registry Public Api (v2.1) and keeps the raw JSON, one file per
kennitala, in data/raw/fyrirtaekjaskra/ -- gitignored, like every other raw source. Then it
loads what the analysis needs into the database:

  organisation_registry   one row per organisation: legal form (rekstrarform), status, and
                          registered address with its municipality
  organisation_activity   its ÍSAT activity codes, one row each

What the register gives and what it does not: `legalForm` is the legal form, not the owner.
"D4 Hlutafélög - opinber" (ohf.) is publicly owned, but Landsvirkjun is an sf. and
Landsbankinn an hf., both state-owned -- `sector` in the YAML stays the word on ownership.
The registered municipality is where the head office is, not where the work happens.

TERMS: the API key is personal (section 3 of Skatturinn's terms), read from .env and never
written anywhere else. Bulk extraction and passing the data on are not allowed (section 5):
this looks up only the organisations the theses name, a few seconds apart, and the raw
records stay local. Board members and other people in `relationships` are not loaded at all.

  python scripts/fetch_fyrirtaekjaskra.py                 fetch what is missing, then load
  python scripts/fetch_fyrirtaekjaskra.py --cached-only   load from data/raw only, no network

The rebuild step `collaboration` runs it with --cached-only. Fetching is by hand.
"""
import argparse
import json
import os
import sys
import time
from pathlib import Path

import duckdb
import pandas as pd
import requests
import yaml

ROOT = Path(__file__).resolve().parent.parent
API = "https://api.skattur.cloud/legalentities/v2.1"
CACHE = ROOT / "data" / "raw" / "fyrirtaekjaskra"
# The free plan allows 60 calls a minute; there is no reason to go near that.
DELAY_SECONDS = 3


def api_key() -> str | None:
    """SKATTURINN_API_KEY from the environment, or from .env in the repository root."""
    key = os.environ.get("SKATTURINN_API_KEY")
    env = ROOT / ".env"
    if not key and env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            name, sep, value = line.partition("=")
            if sep and name.strip() == "SKATTURINN_API_KEY":
                key = value.strip().strip("'\"")
    return key or None


def is_legal_entity(kennitala: str) -> bool:
    """A company's kennitala adds 40 to the day of the month; a person's does not."""
    return kennitala[:1] in "4567"


def fetch(kennitala: str, key: str) -> dict | None:
    r = requests.get(
        f"{API}/{kennitala}",
        params={"language": "is"},
        headers={"Ocp-Apim-Subscription-Key": key},
        timeout=60,
    )
    if r.status_code == 404:
        return None
    r.raise_for_status()
    return r.json()


def rows_from(org_key: str, kennitala: str, record: dict) -> tuple[tuple, list[tuple]]:
    legal = record.get("legalForm") or {}
    dereg = record.get("deregistration") or {}
    # The legal address when there is one; otherwise whatever address is listed first.
    addresses = record.get("addresses") or []
    addr = next((a for a in addresses if "lögheimili" in (a.get("type") or "").lower()),
                addresses[0] if addresses else {})
    registry = (
        org_key, kennitala, record.get("name"), record.get("status"),
        legal.get("id"), legal.get("name"),
        bool(dereg.get("deregistered")), bool(dereg.get("bankrupcy")),
        addr.get("postcode"), addr.get("city"), addr.get("municipality"),
        addr.get("municipalityId"),
    )
    activities = [
        (org_key, kennitala, a.get("codeSystem"), a.get("type"), a.get("id"), a.get("name"))
        for a in record.get("activityCode") or []
    ]
    return registry, activities


def write_table(con: duckdb.DuckDBPyConnection, name: str, columns: str, rows: list) -> None:
    con.execute(f"create or replace table {name} ({columns})")
    if rows:
        df = pd.DataFrame(rows, columns=[c.split()[0] for c in columns.split(",")])
        con.register("_rows", df)
        con.execute(f"insert into {name} select * from _rows")
        con.unregister("_rows")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "data" / "processed" / "thesis.db"))
    ap.add_argument("--organisations", default=str(ROOT / "config" / "organisations.yaml"))
    ap.add_argument("--cached-only", action="store_true",
                    help="load from data/raw/fyrirtaekjaskra only; make no requests")
    ap.add_argument("--refresh", action="store_true",
                    help="fetch again even when a record is cached")
    args = ap.parse_args()

    orgs = yaml.safe_load(Path(args.organisations).read_text(encoding="utf-8"))["organisations"]
    wanted = []
    for o in orgs:
        kt = str(o.get("kennitala") or "").replace("-", "").strip()
        if not kt:
            continue
        if len(kt) != 10 or not kt.isdigit() or not is_legal_entity(kt):
            sys.exit(f"{o['key']}: '{o['kennitala']}' is not an organisation's kennitala")
        wanted.append((o["key"], kt))

    key = None if args.cached_only else api_key()
    if not args.cached_only and not key:
        print("No SKATTURINN_API_KEY in the environment or .env: loading cached records only.",
              file=sys.stderr)

    CACHE.mkdir(parents=True, exist_ok=True)
    fetched = missing = not_found = 0
    for org_key, kt in wanted:
        path = CACHE / f"{kt}.json"
        if path.exists() and not args.refresh:
            continue
        if not key:
            missing += 1
            continue
        record = fetch(kt, key)
        if record is None:
            print(f"  {org_key}: {kt} not in the register", file=sys.stderr)
            not_found += 1
        else:
            path.write_text(json.dumps(record, ensure_ascii=False, indent=1), encoding="utf-8")
            fetched += 1
        time.sleep(DELAY_SECONDS)

    registry, activities = [], []
    for org_key, kt in wanted:
        path = CACHE / f"{kt}.json"
        if path.exists():
            r, a = rows_from(org_key, kt, json.loads(path.read_text(encoding="utf-8")))
            registry.append(r)
            activities += a

    with duckdb.connect(args.db) as con:
        write_table(con, "organisation_registry",
                    "org_key varchar, kennitala varchar, registered_name varchar, "
                    "status varchar, legal_form_id varchar, legal_form varchar, "
                    "deregistered boolean, bankrupt boolean, postcode varchar, city varchar, "
                    "municipality varchar, municipality_id varchar", registry)
        write_table(con, "organisation_activity",
                    "org_key varchar, kennitala varchar, code_system varchar, type varchar, "
                    "isat_id varchar, isat_name varchar", activities)
        con.execute("checkpoint")

    print(f"{len(wanted)} organisations with a kennitala: {fetched} fetched, "
          f"{len(registry)} loaded, {missing} missing (no key), {not_found} not in the register.")


if __name__ == "__main__":
    main()
