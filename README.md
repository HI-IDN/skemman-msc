# skemman-msc

A Quarto book analyzing master's theses in engineering and technology published in
[Skemman](https://skemman.is) since 2010, covering Háskóli Íslands and Háskólinn í
Reykjavík.

The published book is at <https://hi-idn.github.io/skemman-msc>. Research questions are
tracked in [issue #1](https://github.com/HI-IDN/skemman-msc/issues/1).

## Quick Start

Clone with the harvester submodule:

```bash
git clone --recurse-submodules git@github.com:HI-IDN/skemman-msc.git
cd skemman-msc
```

Create and activate a Python environment:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

PowerShell activation:

```powershell
.venv\Scripts\activate
```

If the submodule is missing:

```bash
git submodule update --init
```

## Rebuild Data

The project-specific configuration is in `config/collections.yaml`. `scripts/rebuild.sh`
builds the study from Skemman to figures in four phases; with no flag it runs all of them:

```bash
bash scripts/rebuild.sh --dry-run          # print the steps, run nothing
bash scripts/rebuild.sh                    # everything, in order
bash scripts/rebuild.sh --preprocessing    # fetch from Skemman: records, file lists, PDFs
bash scripts/rebuild.sh --dataprocessing   # derive from data/raw; no network
bash scripts/rebuild.sh --postprocessing   # the population and the views over it
bash scripts/rebuild.sh --visualise        # every figure as outputs/figures/*.png, and one PDF
```

Phases combine, so `--dataprocessing --postprocessing` re-derives the whole database from
the cache without a single request. From PowerShell keep the `bash` in front, or the script
opens in its own window and its output is lost.

The population is defined once, in `scripts/population.sql`: `v_thesis_msc` holds the
master's theses in the years set under `analysis:` in the config. Everything downstream
reads it rather than `thesis`, which also holds bachelor's theses, diplomas and years
outside the study. The database is `data/processed/thesis.db`; set `THESIS_DB` to point
the rebuild, the R scripts and the book at a copy instead.

## Render The Book

```bash
quarto render
```

The site is written to `site/`, which is gitignored. Every chunk reads its code from a
script in `R/`, so a single figure or table can be looked at without rendering:

```r
source("R/global.R")
source("R/plots/rq1-ggplot.R")
```

Disconnect `thesis.db` from IDE database panels before rendering or loading data. DuckDB
allows only one writer/connection pattern safely at a time on Windows.

## Where Details Live

- Harvester commands and crawler behavior: `skemman-harvester/docs/`
- Database mapping: `docs/schema.qmd`
- Book chapters: `docs/` (`index.qmd` stays at the root, where Quarto requires it)
- Study-specific collection and year settings: `config/collections.yaml`
- Discipline mapping: `scripts/discipline_map.sql`

The harvester itself lives in `skemman-harvester/` as a submodule and is not specific to
this study.
