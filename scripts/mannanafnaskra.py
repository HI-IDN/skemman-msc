"""A small, portable client for Þjóðskrá's Mannanafnaskrá (the Icelandic given/middle-name
registry), via the persisted GraphQL search behind island.is/leit-i-mannanafnaskra.

Vendored here (verbatim, no icelandic-thesis-comparison-specific code) from a standalone tool kept
outside this repo for reuse in other projects. If you change this file, port the change back there
too. Used by scripts/fetch_mannanafnaskra.py, which is the project-specific part (writes into
data/processed/, not part of rebuild.sh -- needs the network, run by hand like the other fetch_*
scripts).

There is no documented public API or bulk-download dataset for this registry. The search page
itself is a client-rendered app, but its search box calls a stable, unauthenticated GraphQL
endpoint that is easy to call directly with plain HTTP -- no browser, no Playwright, just
`requests` and a few headers CloudFront and Apollo's CSRF guard both require. Found by watching
the network tab of that search page under a real browser's User-Agent (Playwright's default
headless fingerprint gets a CloudFront 403).

Usage:
    # One name:
    python mannanafnaskra.py Guðmundur

    # The whole registry (every entry, ~30 substring queries, one per Icelandic letter, deduped
    # by id -- takes under a minute):
    python mannanafnaskra.py --all -o icelandic_given_names.csv

As a library:
    from mannanafnaskra import search, fetch_all, gender_of

    search("Guðrún")                 # -> list[dict], raw API entries
    fetch_all()                      # -> list[dict], the whole registry, deduped
    gender_of("Guðmundur", fetch_all())  # -> "male" | "female" | "unisex" | "unknown"

Response shape (one entry): {"id": int, "icelandicName": str (lowercase), "type": str,
"status": "Sam"|"Haf", "verdict": "dd.mm.yyyy"|None, "visible": bool, "description": str|None,
"url": str|None}.

`type` says who the name is registered for: "DR"/"RDR" = drengjanafn, a boy's given name
("RDR" appears on some compound/two-part entries); "ST"/"RST" = stúlknanafn, a girl's given
name; anything else (e.g. "MI") is a millinafn (a gender-neutral middle name) or something not
usefully gendered. `status`: "Sam" = samþykkt (approved), "Haf" = hafnað (rejected) -- a
rejected name is very often still clear evidence of the *intended* gender (a mis-spelling of an
approved name, say), so this module does not filter status by default; pass approved_only=True
if you want only currently-legal names.

Some names are registered on BOTH lists (e.g. "Alex" is both a "DR" and a "ST" entry) -- a name
like that is genuinely unisex in the registry and gender_of() returns "unisex" for it, not a
guess at which is more common.

PRIVACY: this registry is about NAMES, not people -- it carries no personal data, and nothing
here ever sends a person's name anywhere without the caller choosing to (search() takes whatever
string you give it, no data set into this module).
"""
from __future__ import annotations

import argparse
import csv
import sys
import time
import urllib.parse
from dataclasses import dataclass

import requests

ENDPOINT = "https://island.is/api/graphql"
REFERER = "https://island.is/leit-i-mannanafnaskra"
OPERATION = "GetIcelandicNameBySearch"
# A persisted-query hash the search page itself sends; stable as long as island.is doesn't change
# the query text server-side. If every search starts failing with a "PersistedQueryNotFound"
# error, re-derive this by watching the network tab of REFERER for the same operationName.
PERSISTED_SHA256 = "9ad0fe7dfad99b8acf592ad0ed4c9052d431e3a10fce79979d113c3b22f5bd73"

HEADERS = {
    # CloudFront in front of island.is blocks requests without a browser-shaped User-Agent.
    "User-Agent": ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                   "(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36"),
    "Accept": "*/*",
    # Apollo Server's CSRF guard rejects a request that looks like a simple cross-site GET unless
    # one of these (or a non-form Content-Type) is present -- it never actually reads the body.
    "Content-Type": "application/json",
    "apollo-require-preflight": "true",
    "apollographql-client-name": "cms-web-client",
    "apollographql-client-version": "0.1",
    "Referer": REFERER,
}

MALE_TYPES = {"DR", "RDR"}
FEMALE_TYPES = {"ST", "RST"}


@dataclass
class NameEntry:
    id: int
    name: str
    type: str
    status: str
    verdict: str | None
    url: str | None


def search(query: str, *, session: requests.Session | None = None, timeout: float = 20) -> list[dict]:
    """One search, as the site's own search box makes it. Substring match, case-insensitive,
    accent-sensitive ("Gudmundur" without the ð finds nothing; "Guðmundur" does)."""
    variables = {"input": {"q": query}}
    extensions = {"persistedQuery": {"version": 1, "sha256Hash": PERSISTED_SHA256}}
    params = {
        "operationName": OPERATION,
        "variables": _json_compact(variables),
        "extensions": _json_compact(extensions),
    }
    http = session or requests
    r = http.get(ENDPOINT, params=params, headers=HEADERS, timeout=timeout)
    r.raise_for_status()
    body = r.json()
    if "errors" in body:
        raise RuntimeError(f"Mannanafnaskrá query failed for {query!r}: {body['errors']}")
    return body["data"]["getIcelandicNameBySearch"]


def _json_compact(obj) -> str:
    import json
    return json.dumps(obj, separators=(",", ":"))


# The Icelandic alphabet. A single letter is a substring query, so it returns every name
# containing that letter -- overlapping a lot between letters, which is exactly why fetch_all()
# dedupes by id. c/q/w/z are rare in native Icelandic names but appear in some approved
# loanwords/millinöfn, so they are included too.
ALPHABET = list("aábcdðeéfghiíjklmnoópqrstuúvwxyýzþæö")


def fetch_all(*, delay: float = 0.15, on_progress=None) -> list[dict]:
    """The whole registry: one query per letter, deduped by id. ~30 requests, polite delay
    between them. Takes well under a minute."""
    seen: dict[int, dict] = {}
    with requests.Session() as s:
        for i, letter in enumerate(ALPHABET, 1):
            for entry in search(letter, session=s):
                seen[entry["id"]] = entry
            if on_progress:
                on_progress(i, len(ALPHABET), letter, len(seen))
            if delay:
                time.sleep(delay)
    return list(seen.values())


def gender_of(first_name: str, registry: list[dict], *, approved_only: bool = False) -> str:
    """Classify a first (given) name using an already-fetched registry (fetch_all()). Matches the
    registry's own normalised (lowercase) form. Returns "male", "female", "unisex" (registered as
    both), or "unknown" (not found, or found only as a millinafn/unclassifiable type)."""
    key = first_name.strip().lower()
    hits = [e for e in registry if e["icelandicName"] == key
            and (not approved_only or e["status"] == "Sam")]
    is_male = any(e["type"] in MALE_TYPES for e in hits)
    is_female = any(e["type"] in FEMALE_TYPES for e in hits)
    if is_male and is_female:
        return "unisex"
    if is_male:
        return "male"
    if is_female:
        return "female"
    return "unknown"


def _main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("name", nargs="?", help="Look up one name and print its entries.")
    ap.add_argument("--all", action="store_true", help="Fetch the whole registry instead.")
    ap.add_argument("-o", "--out", help="Write the whole registry to this CSV (implies --all).")
    args = ap.parse_args()

    if args.out:
        args.all = True
    if not args.all and not args.name:
        ap.error("give a name to look up, or pass --all / -o to fetch the whole registry")

    if args.all:
        def progress(i, n, letter, count):
            print(f"  [{i}/{n}] {letter!r}: {count} unique so far", file=sys.stderr)

        rows = fetch_all(on_progress=progress)
        rows.sort(key=lambda e: (e["icelandicName"], e["id"]))
        print(f"{len(rows)} entries", file=sys.stderr)
        if args.out:
            with open(args.out, "w", newline="", encoding="utf-8") as f:
                w = csv.DictWriter(f, ["id", "icelandicName", "type", "status", "verdict", "url"])
                w.writeheader()
                for e in rows:
                    w.writerow({k: e.get(k) for k in w.fieldnames})
            print(f"wrote {args.out}", file=sys.stderr)
        else:
            for e in rows:
                print(e)
    else:
        for e in search(args.name):
            print(e)


if __name__ == "__main__":
    _main()
