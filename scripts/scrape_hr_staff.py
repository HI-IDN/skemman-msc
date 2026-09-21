"""Look up the department (deild) of each HR thesis advisor on ru.is's staff directory.

Helper script -- needs the network and a headless browser, so it is NOT part of rebuild.sh.
Independent of scrape_hi_staff.py (its HI counterpart). Writes:
  data/processed/hr_staff_directory.csv  every card on https://www.ru.is/starfsfolk
  data/processed/hr_staff_units.csv      one row per HR advisor, matched by name

  python scripts/scrape_hr_staff.py [--refresh] [--delay SECONDS]

How it works:
  * The directory renders client-side, paginated ("Næsta síða" = next page), one card per
    person: name, job title, department. The script clicks through every page once and
    caches the cards; --refresh re-crawls instead of reusing the cache.
  * Advisors are matched by name (accent/case-insensitive, "Last, First" flipped). Exactly
    one card -> 'ok'; several cards with the same name -> 'ambiguous' (a human picks);
    none -> 'not_found' (e.g. departed staff, external supervisors).
  * robots.txt disallows /api/ -- this script only loads the public directory page.
"""
import argparse
import csv
import re
import sys
import time
import unicodedata
from datetime import date
from pathlib import Path

import duckdb
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "processed" / "thesis.db"
DIRECTORY = ROOT / "data" / "processed" / "hr_staff_directory.csv"
OUT = ROOT / "data" / "processed" / "hr_staff_units.csv"
URL = "https://www.ru.is/starfsfolk"
UA = "Mozilla/5.0 (research; icelandic-thesis-comparison; contact via repo owner)"
DIR_FIELDS = ["name", "title", "unit", "url"]
FIELDS = ["person_id", "name", "n_theses", "status", "profile_name", "title", "unit", "url",
          "n_candidates", "fetched"]
CARDS_JS = """() => [...document.querySelectorAll('.wp-block-kaktus-blocks-contact-profile__content')]
  .map(c => {
    const t = s => (c.querySelector('.wp-block-kaktus-blocks-contact-profile__content__' + s)
                    || {innerText: ''}).innerText.trim();
    const a = c.querySelector("a[href*='/starfsfolk/']");
    return {name: t('name'), title: t('job'), unit: t('department'), url: a ? a.href : ''};
  })"""


def norm(s):
    s = unicodedata.normalize("NFKD", s.casefold().replace("ð", "d").replace("þ", "th"))
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z ]", "", s.replace("-", " ")).split()


def flip(name):
    if "," in name:  # "Last, First" -> "First Last"
        last, first = name.split(",", 1)
        return f"{first.strip()} {last.strip()}"
    return name


def crawl_directory(delay):
    seen, cards = set(), []
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(user_agent=UA)
        page.goto(URL, wait_until="networkidle", timeout=60000)
        pageno = 1
        while True:
            new = 0
            for c in page.evaluate(CARDS_JS):
                key = c["url"] or c["name"]
                if key not in seen:
                    seen.add(key)
                    cards.append(c)
                    new += 1
            print(f"page {pageno}: {new} new cards ({len(cards)} total)", file=sys.stderr)
            nxt = page.query_selector("text=Næsta síða")
            if new == 0 or not nxt:
                break
            nxt.evaluate("e => (e.closest('button,a') || e).click()")  # JS click: cookie bar
            page.wait_for_timeout(int(delay * 1000) + 1500)
            pageno += 1
        browser.close()
    with DIRECTORY.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, DIR_FIELDS)
        w.writeheader()
        w.writerows(cards)
    return cards


def advisors():
    con = duckdb.connect(str(DB), read_only=True)
    p = ROOT / "data" / "db"
    return con.execute(f"""
        select tp.person_id, pe.name, count(distinct tp.thesis_id) as n
        from read_parquet('{p / 'thesis_people.parquet'}') tp
        join read_parquet('{p / 'people.parquet'}') pe on pe.id = tp.person_id
        join v_thesis_discipline d on d.thesis_id = tp.thesis_id
        where tp.role = 'advisor' and d.university = 'Háskólinn í Reykjavík' and d.in_scope_broad
        group by 1, 2 order by n desc, 2
    """).fetchall()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--refresh", action="store_true")
    ap.add_argument("--delay", type=float, default=1.0)
    args = ap.parse_args()

    if DIRECTORY.exists() and not args.refresh:
        with DIRECTORY.open(encoding="utf-8", newline="") as f:
            cards = list(csv.DictReader(f))
        print(f"using cached directory ({len(cards)} cards)", file=sys.stderr)
    else:
        cards = crawl_directory(args.delay)

    by_name = {}
    for c in cards:
        by_name.setdefault(tuple(norm(c["name"])), []).append(c)

    rows = []
    for pid, name, n in advisors():
        hits = by_name.get(tuple(norm(flip(name))), [])
        row = {k: "" for k in FIELDS}
        row.update(person_id=pid, name=name, n_theses=n, n_candidates=len(hits),
                   fetched=date.today().isoformat())
        if len(hits) == 1:
            row.update(status="ok", profile_name=hits[0]["name"], title=hits[0]["title"],
                       unit=hits[0]["unit"], url=hits[0]["url"])
        elif hits:
            row.update(status="ambiguous", profile_name=hits[0]["name"],
                       unit=";".join(sorted({h["unit"] for h in hits})),
                       url=";".join(h["url"] for h in hits))
        else:
            row["status"] = "not_found"
        rows.append(row)
    with OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, FIELDS)
        w.writeheader()
        w.writerows(rows)
    from collections import Counter
    print(dict(Counter(r["status"] for r in rows)), file=sys.stderr)


if __name__ == "__main__":
    main()
