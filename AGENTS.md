# AGENTS.md

Guidance for AI/code agents working on this project.

## Project

A data analysis of master's theses in engineering and technology published in
[Skemman](https://skemman.is) since 2010, covering Háskóli Íslands (HÍ) and Háskólinn í
Reykjavík (HR). The research questions are tracked in
[issue #1](https://github.com/HI-IDN/icelandic-thesis-comparison/issues/1); each has its
own chapter.

The deliverable is a Quarto book. `index.qmd` is the landing page, chapters live under
`sections/`, the database mapping is an appendix in `schema.qmd`, and the rendered site is
written to `docs/` (gitignored — see *Publishing*).

## Workflow

The pipeline has two passes, both driven by the `skemman` CLI:

1. Initialize DuckDB with `scripts/create_thesis_db.sql`.
2. `skemman simple-search` for the HÍ and HR handles, year by year over 2010–2026.
3. `skemman metadata-load` to fetch and parse item pages.
4. Analyze the resulting database in the Quarto book.

Prefer the `skemman` CLI for scraper actions. Do not add duplicate one-off Python scripts
when a CLI command is the intended interface. Raw item HTML is cached under
`data/raw/items/`; the loader reuses it rather than refetching.

Re-running `simple-search` for the current year picks up newly published theses. Follow it
with `metadata-load`, which processes everything still missing metadata.

## The database lock

**DuckDB permits one process to open the file at a time**, and on Windows the lock is
exclusive enough to block even copying the file. This bites constantly:

- Disconnect `thesis.db` in DataSpell's Data panel before rendering the book or running
  any script against it.
- Closing an IDE tab does not release the connection; the data source must be disconnected
  or the IDE quit.
- After any write, run `CHECKPOINT;` so the `.wal` folds back into `thesis.db`.

`data/processed/` is gitignored. The database is not in the repository and cannot be
assumed present.

## Environment

- **Python**: `.venv\Scripts\python.exe`, Python 3.12.10, with `duckdb` 1.5.5 and
  `skemman-scraper` installed editable.
- **R**: 4.5.3, with `duckdb` 1.5.2, `ggplot2` 4.0.2, `knitr`, `rmarkdown`, `tidyr`.
- **Quarto**: 1.9.38.

Note that the Python and R DuckDB versions differ (1.5.5 vs 1.5.2). Both can read the
database; it matters only for extension installs, which are keyed by DuckDB version.

## Quarto structure

This is a Quarto book, not a single article. Keep `index.qmd` as the welcome page. Chapter
order is controlled by `_quarto.yml`.

Chapters with R code source the shared setup file:

```r
#| include: false
source("../scripts/report_setup.R")
```

`scripts/report_setup.R` loads packages, opens `thesis.db` read-only, loads the ggsql
extension, defines `hi_colors`, sets the ggplot theme, and loads the `masters` and
`masters_by_year` tables used across chapters.

Chapter files start with a single `#` heading and need no YAML header. Current sections:

- `01-rq1-volume.qmd` — volume over time
- `02-rq2-disciplines.qmd` — disciplines
- `03-rq3-comparison.qmd` — HÍ vs HR
- `04-rq4-collaboration.qmd` — industry collaboration
- `05-rq5-partners.qmd` — who the partners are
- `06-rq6-themes.qmd` — research themes
- `07-rq7-knowledge-transfer.qmd` — knowledge transfer

## Language and tone

**Code is in English. The book is in Icelandic.**

- English: file names, variable and function names, SQL, code comments, commit messages,
  `README.md`, and this file.
- Icelandic: everything the reader sees — `index.qmd`, all chapters, `schema.qmd`,
  headings, callout titles, figure captions, and table captions.

Identifiers stay in English even inside Icelandic prose: column names, table names, Skemman
field names, and CLI commands are code and are never translated. Write around them rather
than translating them.

Write plainly and lead with evidence. This is research output, not marketing. Avoid
overclaiming: where the data is descriptive, say so, and where a trend is an artifact of
cataloguing practice rather than reality, say that too.

## Data and claims

The database does the heavy lifting. Derive values from `thesis.db` rather than hardcoding
numbers in prose. If prose mentions counts, averages, or crossover years, calculate them in
a hidden chunk and interpolate.

A claim should be supported by a figure, a table, a calculation, or a clearly labelled
limitation.

**If the database cannot answer a question, say so plainly and park it.** Do not invent
values or stretch a weak signal. Several chapters are currently parked; each states what is
missing and what would unblock it. That is the intended pattern, not a placeholder to be
filled with speculation.

Three caveats apply throughout and are stated once in `index.qmd` rather than repeated:

- The population is broader than the research plan specifies — `faculty` is empty and HÍ's
  `school` mixes natural sciences into engineering.
- HR's 2010 count reflects when the school began depositing in Skemman, not real output.
- The final year is incomplete.

## ggsql

Charts can be drawn with [ggsql](https://ggsql.org), a grammar-of-graphics SQL extension
for DuckDB, alongside ggplot2. Hard-won details:

- **Builds exist only for DuckDB ≥ 1.5.2.** 1.5.0 and 1.5.1 return 404 from the community
  extension repo.
- **It cannot work in DataGrip or DataSpell's SQL console.** The newest DuckDB JDBC driver
  on Maven Central is 1.3.1.0, two minor versions below the floor. This is not fixable by
  configuration. Use R or Python.
- `VISUALISE` requires explicit `AS x` / `AS y`; positional mapping is not inferred.
- `ggsql_output` defaults to `silent`, which **opens a browser** and returns no rows. Use
  `spec` (Vega-Lite JSON, ~9 KB) for embedding in the book. `html` returns a standalone
  ~850 KB document that cannot nest inside a rendered page.

`ggsql_plot()` in `scripts/report_setup.R` handles the spec-mode dance. It emits three
`<script src>` tags to a CDN, so ggsql figures need network access to display; ggplot2
figures are inlined PNGs and do not.

ggsql is alpha and has no theming. Prefer **ggplot2 for figures that matter**, and use
ggsql where the SQL-native expression is genuinely clearer.

## Figures

Use `hi_colors` from `scripts/report_setup.R` for university series so colours stay
consistent across chapters. The HÍ palette in `styles/hi-book.scss` is for site chrome;
do not restyle analysis figures with it beyond the university scale.

Figures should answer a concrete question, with captions explaining why the figure matters
and noting any caveat that affects reading it.

## Website styling

Copied from the sibling `ttr-legacy-analysis` book: `styles/hi-book.scss`,
`partials/header-includes.inc`, `partials/breadcrumb.inc`, and HÍ logos under `img/hi/`.

Both partials contain project-specific strings — the browser-tab title and the sidebar
label for the index page. If these are re-copied from another book, update them.

## Publishing

`.github/workflows/publish.yml` renders the book and deploys to GitHub Pages.

**The Action has no database and no R.** Every chunk is served from `_freeze/`, which is
committed (a few hundred KB). This is what makes publishing possible without shipping
`thesis.db`.

The consequence: **rendering locally and committing `_freeze/` is part of any change that
touches computed output.** A chapter edited without a local render will publish stale
results. The workflow fails early with an explicit message if `_freeze/` is missing.

`docs/` is rendered output and is gitignored. Do not commit it; the Action uploads it as a
Pages artifact.

## Git hygiene

Commit regularly in coherent, self-contained chunks — group by intent, not by file type.
Do not accumulate a large working tree and commit once at the end.

- After a related set of changes is made and verified, commit those files.
- Do not sweep unrelated dirty files into a commit.
- If the user says a change is OK or asks for a change to be made, treat that as permission
  to commit the related files once verification passes.
- Do not commit `.idea/`.
- Check `git status --short` before committing.

History is direct to `main`.
