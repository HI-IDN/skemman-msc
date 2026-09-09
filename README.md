# skemman-msc

A study of **master's theses in engineering and technology** published in
[Skemman](https://skemman.is) since 2010, at Háskóli Íslands and Háskólinn í Reykjavík.
The research questions are tracked in
[issue #1](https://github.com/HI-IDN/skemman-msc/issues/1) and answered in
the Quarto book, published at
<https://hi-idn.github.io/skemman-msc>.

The population is master's theses. Bachelor's and doctoral records are collected because
they share the same Skemman collections, but they are outside the analysis.

This repository is the **analysis**. Data harvesting is handled by
[skemman-harvester](https://github.com/HI-IDN/skemman-harvester), vendored here as the
`skemman-harvester/` submodule and installed by `requirements.txt` in editable mode. The
harvester knows nothing about engineering, these two universities or master's theses, so
it can be pointed at any Skemman collection.

What is specific to this study stays here: `config/collections.yaml`,
`scripts/discipline_map.sql`, the Quarto book, and the research judgments they encode.

## Workflow

1. **Capture OAI records** — `skemman oai-pmh` for each collection handle, including
   OAI-provided keywords and abstracts.
2. **Load item-page metadata** — `skemman metadata-load` fetches each Skemman item page
   for details not exposed by OAI-PMH. Cached HTML is reused.
3. **Index files** — `skemman files-index` reads each cached item page's file table into
   `thesis_file`, including access status and size. This step does not use the network.
4. **Read title pages** — `skemman titlepage-load` fetches open thesis PDFs, keeps the
   first pages as plain text, and reads the faculty, credits and degree stated in the
   document itself.

Every step is resumable and caches what it fetches, so re-running only does what is
missing.

## Install

```bash
git clone --recurse-submodules git@github.com:HI-IDN/skemman-msc.git
cd skemman-msc

python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt   # installs the harvester submodule, editable
```

If you cloned without `--recurse-submodules`:

```bash
git submodule update --init
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

Harvest the configured handles and years through Skemman's OAI-PMH endpoint:

```bash
skemman oai-pmh --output data/processed/thesis.db
```

Handles are mapped to Skemman's OAI-PMH community sets, so `1946/2064` becomes
`com_1946_2064` and `1946/6870` becomes `com_1946_6870`. Use `--set` directly if you
want to harvest a specific OAI-PMH set. The default handles, year range and optional test
limit are read from `config/collections.yaml`. OAI `dc:subject` values are loaded as
keywords, and `dc:description` values are loaded as abstracts where possible.

## Step 2: Load Metadata

Load item-page metadata for all thesis IDs that are missing page-only details:

```bash
skemman metadata-load --db data/processed/thesis.db
```

For a selected set of IDs:

```bash
skemman metadata-load --db data/processed/thesis.db --ids 4445,25337
```

Raw item HTML is cached under `data/raw/items/`. If `data/raw/items/<thesis_id>.html`
exists, the loader reuses it instead of fetching the page again. This cache is still
needed for fields OAI-PMH does not include, especially PDF URLs, file-table access status,
breadcrumbs and advisor metadata.

Clean already-loaded people rows if old metadata loads left years or parenthesized roles in names:

```bash
skemman clean-people --db data/processed/thesis.db
```

## Step 3: Index Attached Files

Read the file table from the cached item HTML:

```bash
skemman files-index --db data/processed/thesis.db
```

This fills `thesis_file` with filename, size, access status and type. Run it before
loading title pages: it lets the harvester skip closed files and take smaller PDFs first.

Because this step reads `data/raw/items/`, it does not make network requests.

## Step 4: Fetch Theses and Read Their Title Pages

Skemman's subject keywords are a suggestion. The title page states the faculty, the credits
and the degree outright, and carries fields Skemman does not expose at all — notably ECTS
and the length of the thesis.

Load title pages for every master's thesis that does not have one yet:

```bash
skemman titlepage-load --db data/processed/thesis.db --degree-level master
```

For a selected set of IDs, or a trial run:

```bash
skemman titlepage-load --db data/processed/thesis.db --ids 30610,21584
skemman titlepage-load --db data/processed/thesis.db --limit 50
```

Bachelor's and doctoral theses are skipped by default. To include them:

```bash
skemman titlepage-load --db data/processed/thesis.db --degree-level bachelor
```

Results land in `thesis_titlepage`, one row per thesis, separate from `thesis_metadata` so
it stays visible which fields came from Skemman and which from the document.

### What gets stored where

Each PDF is fetched, its first eight pages are extracted as **plain text** to
`data/raw/pdf_text/<thesis_id>.txt`, and the PDF is then deleted. The text is what the
parser reads, so the whole master's population costs roughly 20 MB on disk instead of
about 12 GB of PDFs.

The number of PDF pages kept as text is controlled by `titlepage_pages` in
`config/collections.yaml`. Leave it blank to extract the whole PDF.

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
skemman titlepage-load --db data/processed/thesis.db --degree-level master
```

Fetching all master's theses takes a long overnight run at the 30-second request delay set
in `config/collections.yaml`, which follows Skemman's robots.txt crawl-delay.

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
| `skemman-harvester/` | The harvester, as a submodule. Not specific to this study. |
| `config/collections.yaml` | Which collections and years to fetch. |
| `scripts/discipline_map.sql` | Keyword to discipline mapping. Specific to this study. |
| `index.qmd`, `sections/`, `schema.qmd` | The Quarto book. |
| `data/raw/` | Cached Skemman HTML and extracted PDF text. Not in git. |
| `data/processed/thesis.db` | The DuckDB database. Not in git. |
| `data/db/` | Per-table Parquet snapshot, for version control. |
