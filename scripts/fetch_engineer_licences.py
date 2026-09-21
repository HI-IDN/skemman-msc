"""Fetch the government lists of licensed engineers (verkfræðingar) and technologists
(tæknifræðingar) and keep only what the analysis needs.

Helper script -- needs the network, NOT part of rebuild.sh. Writes
data/processed/engineer_licences.csv with: name, birth_year, licence_year, licence_date,
list ('verkfraedingur' | 'taeknifraedingur'), raw_date.

PRIVACY: each entry on the source page carries the person's kennitala. It is parsed in
memory only to get the birth year and is never written out. Analyses report aggregates.

Sources (one <p> per person, "Name, kennitala|f. dd.mm.yy, title. Fær leyfi <date>."):
  https://www.stjornarradid.is/verkefni/atvinnuvegir/starfsrettindi/verkfraedingar/
  https://www.stjornarradid.is/verkefni/atvinnuvegir/starfsrettindi/taeknifraedingar/

  python scripts/fetch_engineer_licences.py
"""
import csv
import html
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "processed" / "engineer_licences.csv"
BASE = "https://www.stjornarradid.is/verkefni/atvinnuvegir/starfsrettindi/"
LISTS = {"verkfraedingur": BASE + "verkfraedingar/", "taeknifraedingur": BASE + "taeknifraedingar/"}
UA = "Mozilla/5.0 (research; icelandic-thesis-comparison; contact via repo owner)"
MONTHS = {"janúar": 1, "febrúar": 2, "mars": 3, "apríl": 4, "maí": 5, "júní": 6, "júlí": 7,
          "ágúst": 8, "september": 9, "október": 10, "nóvember": 11, "desember": 12}
# The source is hand-typed: separators, "kt.", "f." and title spellings vary. Find the id
# (kennitala or old-style birth date) anywhere; the name is whatever precedes it.
ID = re.compile(r"(?<!\d)(\d{6}[-.\s]?\d{4})(?!\d)|f\.\s*(\d{1,2}\.\d{1,2}\.\d{2,4})")
DATE = re.compile(r"Fær leyfi\s*(.*?)\.?\s*$")


def parse_entry(text):
    idm, dm = ID.search(text), DATE.search(text)
    if not idm or not dm:
        return None
    ident = idm.group(1) or "f. " + idm.group(2)
    if idm.group(1):
        digits = re.sub(r"\D", "", idm.group(1))
        ident = digits[:6] + "-" + digits[6:]
    name = re.sub(r"[\s,.]*(?:f\.|kt\.?)?[\s,.]*$", "", text[:idm.start()]).strip()
    return {"name": name, "id": ident, "date": dm.group(1)} if name else None


def year2(yy):
    """Two-digit year -> full year; licences start in 1937, so 27..99 -> 19xx else 20xx."""
    return 1900 + yy if yy > 26 else 2000 + yy


def birth_year(ident):
    if "-" in ident:  # ddmmyy-xxxx, last digit is the century (9 -> 1900s, 0 -> 2000s, 8 -> 1800s)
        yy, c = int(ident[4:6]), ident[-1]
        return {"9": 1900, "0": 2000, "8": 1800}.get(c, 1900) + yy
    m = re.search(r"\.(\d{2,4})$", ident)
    y = int(m.group(1))
    return y if y > 999 else 1900 + y


def licence_date(raw):
    """Return (year, iso-ish date or ''), tolerating 06.07.18 / 1.júní 2026 / 4.10.2001 / 1975."""
    raw = raw.strip().rstrip(".")
    m = re.match(r"(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{2,4})$", raw)
    if m:
        d, mo, y = int(m[1]), int(m[2]), int(m[3])
        y = y if y > 999 else year2(y)
        return y, f"{y:04d}-{mo:02d}-{d:02d}"
    m = re.match(r"(\d{1,2})\.\s*([a-záéíóúýþæö]+)\s*(\d{4})$", raw, re.I)
    if m and m[2].lower() in MONTHS:
        return int(m[3]), f"{int(m[3]):04d}-{MONTHS[m[2].lower()]:02d}-{int(m[1]):02d}"
    m = re.search(r"(\d{4})", raw)
    return (int(m[1]), "") if m else (None, "")


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8", "replace")


def main():
    rows, bad = [], []
    for lst, url in LISTS.items():
        page = fetch(url)
        for p in re.findall(r"<p>(.*?)</p>", page, re.S):
            text = html.unescape(re.sub(r"<[^>]+>", "", p)).replace("\xa0", " ").strip()
            if "Fær leyfi" not in text:
                continue
            m = parse_entry(re.sub(r"\s+", " ", text))
            if not m or not 1880 <= birth_year(m["id"]) <= 2010:
                bad.append(re.sub(r"\d[\d.\-/\s]{5,}\d", "<id>", text)[:80])  # never log a kennitala
                continue
            year, iso = licence_date(m["date"])
            if year is not None and not 1937 <= year <= 2026:  # typos in the source
                year, iso = None, ""
            rows.append({"name": m["name"].strip(), "birth_year": birth_year(m["id"]),
                         "licence_year": year, "licence_date": iso, "list": lst,
                         "raw_date": m["date"].strip()})
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, ["name", "birth_year", "licence_year", "licence_date", "list", "raw_date"])
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)} entries written to {OUT.name}; {len(bad)} unparsed", file=sys.stderr)
    for b in bad[:15]:
        print("  unparsed:", b, file=sys.stderr)


if __name__ == "__main__":
    main()
