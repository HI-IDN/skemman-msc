"""Look up the department (deild) of each HI thesis advisor on the university's staff pages.

Helper script -- needs the network and a headless browser, so it is NOT part of rebuild.sh.
Writes data/processed/hi_staff_units.csv; re-running skips advisors already in the file
(pass --retry to redo the not_found/ambiguous/error ones).

  python scripts/scrape_hi_staff.py [--limit N] [--retry] [--delay SECONDS]

How it works:
  * https://hi.is/leita?search_api_fulltext=<name> renders its results client-side, so the
    search runs in headless Chromium (Playwright) and collects the /starfsfolk/<username>
    links it lists.
  * Each profile page (https://hi.is/starfsfolk/<username>) is static HTML: name, title,
    school (svid) and department (deild). Fetched with plain HTTP.
  * A profile counts as a match when its name equals the advisor's name (accent- and
    case-insensitive). Exactly one match -> status 'ok'; several -> 'ambiguous' (a human
    picks); none -> 'not_found' (advisors who are not HI staff, e.g. HR or foreign supervisors).
    Retired staff do have profiles (title 'Fyrrverandi kennari'/'... emeritus', sometimes no
    department line -> empty `unit`).

The advisor list is read from data/processed/thesis.db, plus data/db/*.parquet for the
people tables (they are empty in a freshly rebuilt local database).
"""
import argparse
import csv
import html
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

import duckdb
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "data" / "processed" / "thesis.db"
OUT = ROOT / "data" / "processed" / "hi_staff_units.csv"
UA = "Mozilla/5.0 (research; icelandic-thesis-comparison; contact via repo owner)"
FIELDS = ["person_id", "name", "n_theses", "status", "username", "profile_name",
          "title", "school", "unit", "url", "n_candidates", "fetched"]


def norm(s):
    s = unicodedata.normalize("NFKD", s.casefold().replace("ð", "d").replace("þ", "th"))
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z ]", "", s.replace("-", " ")).split()


def advisors():
    con = duckdb.connect(str(DB), read_only=True)
    p = ROOT / "data" / "db"
    return con.execute(f"""
        select tp.person_id, pe.name, count(distinct tp.thesis_id) as n
        from read_parquet('{p / 'thesis_people.parquet'}') tp
        join read_parquet('{p / 'people.parquet'}') pe on pe.id = tp.person_id
        join v_thesis_discipline d on d.thesis_id = tp.thesis_id
        where tp.role = 'advisor' and d.university = 'Háskóli Íslands' and d.in_scope_broad
        group by 1, 2 order by n desc, 2
    """).fetchall()


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")


def parse_profile(page_html):
    h = re.sub(r"<(script|style)[\s\S]*?</\1>", "", page_html)
    h = h[h.find("<main"):]
    lines = [html.unescape(l).replace("\xa0", " ").strip()
             for l in re.sub(r"<[^>]+>", "\n", h).split("\n")]
    lines = [l for l in lines if l]
    if not lines:
        return None
    name, title, school, unit = lines[0], lines[1] if len(lines) > 1 else "", "", ""
    for i, l in enumerate(lines[:12]):
        if re.search(r"svið\s*$", l):
            school = l
            unit = lines[i + 1] if i + 1 < len(lines) else ""
            if unit in ("Tölvupóstur", "Email"):  # no department line (e.g. emeritus)
                unit = ""
            break
    return {"profile_name": name, "title": title, "school": school, "unit": unit}


def search_usernames(page, name):
    page.goto("https://hi.is/leita?search_api_fulltext=" + urllib.parse.quote(name),
              wait_until="networkidle", timeout=60000)
    hrefs = page.eval_on_selector_all(
        "a", "els => els.map(e => e.href).filter(h => h.includes('/starfsfolk/'))")
    out = []
    for h in hrefs:
        m = re.search(r"/starfsfolk/([a-z0-9]+)/?$", h)
        if m and m.group(1) not in out:
            out.append(m.group(1))
    return out


def lookup(page, name):
    """Return a result dict (status + profile fields) for one advisor name."""
    if "," in name:  # "Last, First" -> "First Last"
        last, first = name.split(",", 1)
        name = f"{first.strip()} {last.strip()}"
    want = norm(name)
    matches, n_cand = [], 0
    for user in search_usernames(page, name):
        n_cand += 1
        prof = parse_profile(get(f"https://hi.is/starfsfolk/{user}"))
        if prof and norm(prof["profile_name"]) == want:
            matches.append({**prof, "username": user})
        time.sleep(0.5)
    if len(matches) == 1:
        return {"status": "ok", **matches[0], "n_candidates": n_cand}
    if len(matches) > 1:
        return {"status": "ambiguous", "username": ";".join(m["username"] for m in matches),
                "unit": ";".join(sorted({m["unit"] for m in matches})),
                "n_candidates": n_cand}
    return {"status": "not_found", "n_candidates": n_cand}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int)
    ap.add_argument("--retry", action="store_true")
    ap.add_argument("--delay", type=float, default=1.0)
    args = ap.parse_args()

    done = {}
    if OUT.exists():
        with OUT.open(encoding="utf-8", newline="") as f:
            done = {int(r["person_id"]): r for r in csv.DictReader(f)}
    todo = [a for a in advisors()
            if a[0] not in done or (args.retry and done[a[0]]["status"] != "ok")]
    if args.limit:
        todo = todo[:args.limit]
    print(f"{len(todo)} advisors to look up ({len(done)} already in {OUT.name})", file=sys.stderr)

    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(user_agent=UA)
        for i, (pid, name, n) in enumerate(todo, 1):
            try:
                res = lookup(page, name)
            except Exception as e:  # keep going; --retry picks these up
                res = {"status": "error", "title": str(e)[:100]}
            row = {k: "" for k in FIELDS}
            row.update(person_id=pid, name=name, n_theses=n, fetched=date.today().isoformat(),
                       url=f"https://hi.is/starfsfolk/{res['username']}" if res.get("username")
                       and ";" not in res["username"] else "", **res)
            done[pid] = row
            print(f"[{i}/{len(todo)}] {name}: {row['status']} {row['unit']}", file=sys.stderr)
            with OUT.open("w", encoding="utf-8", newline="") as f:
                w = csv.DictWriter(f, FIELDS)
                w.writeheader()
                w.writerows(done.values())
            time.sleep(args.delay)
        browser.close()


if __name__ == "__main__":
    main()
