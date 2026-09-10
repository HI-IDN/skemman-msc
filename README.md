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

The project-specific configuration is in `config/collections.yaml`. The full rebuild path is:

```bash
scripts/rebuild.sh --dry-run
scripts/rebuild.sh
```

The rebuild initializes DuckDB, harvests OAI-PMH records, loads file metadata, reads title
pages, and applies the discipline mapping. The resulting database is
`data/processed/thesis.db`.

## Render The Book

```bash
quarto render
```

Disconnect `thesis.db` from IDE database panels before rendering or loading data. DuckDB
allows only one writer/connection pattern safely at a time on Windows.

## Where Details Live

- Harvester commands and crawler behavior: `skemman-harvester/docs/`
- Database mapping: `schema.qmd`
- Book chapters: `docs/` (`index.qmd` stays at the root, where Quarto requires it)
- Study-specific collection and year settings: `config/collections.yaml`
- Discipline mapping: `scripts/discipline_map.sql`

The harvester itself lives in `skemman-harvester/` as a submodule and is not specific to
this study.
