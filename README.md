# Icelandic Thesis Comparison

A study of **master's theses in engineering and technology** published in
[Skemman](https://skemman.is) since 2010, at Háskóli Íslands and Háskólinn í Reykjavík.
The research questions are tracked in
[issue #1](https://github.com/HI-IDN/icelandic-thesis-comparison/issues/1) and answered in
the Quarto book, published at
<https://hi-idn.github.io/icelandic-thesis-comparison>.

The population is master's theses. Bachelor's and doctoral records are collected because
they share the same Skemman collections, but they are outside the analysis.

The repository holds two things: a **scraper** that turns Skemman into a DuckDB database,
and the **analysis** built on top of it.

## The scraper is not specific to this study

`skemman` reads whatever collection you point it at. Nothing about engineering, about these
two universities or about master's theses is baked into it — the handles and year range
live in `config/collections.yaml`, and every command takes the collection, year and degree
level as arguments:

```bash
skemman simple-search --location 1946/1234 --year 2018   # any collection, any year
skemman titlepage-load --degree-level bachelor           # any degree level
```

So it can be reused for a different faculty, a different school or a different question.
What is specific to this study is the analysis: `scripts/discipline_map.sql`, the Quarto
book and the research judgments they encode.

## Workflow

1. **Capture listings** — `simple-search` for each collection handle, year by year.
2. **Load metadata** — fetch each Skemman item page and parse it into normalized tables.
   Cached HTML is reused.
3. **Read title pages** — fetch each thesis PDF, keep the first pages as plain text, and
   read the faculty, credits and degree stated in the document itself.

Every step is resumable and caches what it fetches, so re-running only does what is
missing.

## Install

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

PowerShell activation:

```powershell
.venv\Scripts\activate
```

## Initialize Database

```bash
duckdb data/processed/thesis.db < scripts/create_thesis_db.sql
```

## Step 1: Capture Listings

Run simple search for each handle and year:

```bash
for handle in 1946/2064 1946/6870; do
  for year in $(seq 2010 2026); do
    skemman simple-search --location "$handle" --year "$year" --output data/processed/thesis.db
  done
done
```

PowerShell:

```powershell
$handles = @("1946/2064", "1946/6870")
foreach ($handle in $handles) {
  foreach ($year in 2010..2026) {
    skemman simple-search --location $handle --year $year --output data/processed/thesis.db
  }
}
```

## Step 2: Load Metadata

Load metadata for all thesis IDs that are missing metadata:

```bash
skemman metadata-load --db data/processed/thesis.db
```

For a selected set of IDs:

```bash
skemman metadata-load --db data/processed/thesis.db --ids 4445,25337
```

Raw item HTML is cached under `data/raw/items/`. If `data/raw/items/<thesis_id>.html` exists, the loader reuses it instead of fetching the page again.

Clean already-loaded people rows if old metadata loads left years or parenthesized roles in names:

```bash
skemman clean-people --db data/processed/thesis.db
```

## Step 3: Fetch Theses and Read Their Title Pages

Skemman's subject keywords are a suggestion. The title page states the faculty, the credits
and the degree outright, and carries fields Skemman does not expose at all — notably ECTS
and the length of the thesis.

Load title pages for every master's thesis that does not have one yet:

```bash
skemman titlepage-load --db data/processed/thesis.db
```

For a selected set of IDs, or a trial run:

```bash
skemman titlepage-load --ids 30610,21584
skemman titlepage-load --limit 50
```

Bachelor's and doctoral theses are skipped by default. To include them:

```bash
skemman titlepage-load --degree-level bachelor
```

Results land in `thesis_titlepage`, one row per thesis, separate from `thesis_metadata` so
it stays visible which fields came from Skemman and which from the document.

### What gets stored where

Each PDF is fetched, its first eight pages are extracted as **plain text** to
`data/raw/pdf_text/<thesis_id>.txt`, and the PDF is then deleted. The text is what the
parser reads, so the whole master's population costs roughly 20 MB on disk instead of
about 12 GB of PDFs.

`<thesis_id>` is the Skemman handle suffix throughout, so `data/raw/pdf_text/10688.txt`,
`data/raw/items/10688.html` and <https://skemman.is/handle/1946/10688> are the same thesis.

The first line of each text file is a `%%PAGES<tab><n>` marker holding the PDF's page
count. That means the number of pages survives even though the PDF is gone.

Pass `--keep-pdf` to keep the downloaded files under `data/raw/pdfs/`.

### Re-running

A thesis with a cached text file is skipped, so re-running only fetches what is missing —
the same rule as the item HTML in step 2. Nothing is cached when a PDF cannot be read, so
a truncated download is retried on the next run rather than being skipped forever.

**Improving the parser costs no downloads.** Delete the rows and re-parse from cache:

```bash
duckdb data/processed/thesis.db -c "drop table thesis_titlepage"
skemman titlepage-load
```

Fetching all master's theses takes roughly 90 minutes at the two-second request delay set
in `config/collections.yaml`.

## The analysis

The analysis is a Quarto book, one chapter per research question, written in Icelandic.
The database mapping is documented in its appendix, [schema.qmd](schema.qmd).

Build it locally with:

```bash
quarto render
```

Disconnect `thesis.db` from any IDE database panel first — DuckDB permits one process on
the file at a time.

For ad hoc queries, `scripts/query.R` wraps a connection that opens, reads and closes, so
it works even while a loader is running:

```r
source("scripts/query.R")
q("select university, count(*) as n from thesis_metadata group by 1")
```

Useful SQL checks are in `scripts/useful_queries.sql`.

## Layout

| Path | What it is |
| --- | --- |
| `src/skemman_scraper/` | The scraper. Not specific to this study. |
| `config/collections.yaml` | Which collections and years to fetch. |
| `scripts/discipline_map.sql` | Keyword to discipline mapping. Specific to this study. |
| `index.qmd`, `sections/`, `schema.qmd` | The Quarto book. |
| `data/raw/` | Cached Skemman HTML and extracted PDF text. Not in git. |
| `data/processed/thesis.db` | The DuckDB database. Not in git. |
| `data/db/` | Per-table Parquet snapshot, for version control. |
