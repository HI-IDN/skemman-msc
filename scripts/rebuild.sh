#!/usr/bin/env bash
#
# Build the study from Skemman to figures, in four phases.
#
#   scripts/rebuild.sh                    every phase, in order
#   scripts/rebuild.sh --preprocessing    fetch from Skemman: records, file lists, PDFs
#   scripts/rebuild.sh --dataprocessing   derive from what is on disk; no network
#   scripts/rebuild.sh --postprocessing   the population and the views over it
#   scripts/rebuild.sh --visualise        every figure in R/plots/ as PNG, and one PDF
#
# Phases combine: `--dataprocessing --postprocessing` re-derives everything
# from the cache without a single request. Single steps still work:
#
#   scripts/rebuild.sh --only access      one step
#   scripts/rebuild.sh --only metadata,population,disciplines
#                                         several, in pipeline order
#   scripts/rebuild.sh --from population  this step and everything after it
#   scripts/rebuild.sh --dry-run          print the commands, run nothing
#   scripts/rebuild.sh --limit 10         a trial run
#   scripts/rebuild.sh --fresh            move the database aside first
#
# From PowerShell, run it through bash -- `bash scripts/rebuild.sh ...` --
# or it opens in a separate window and its output is lost.
#
# Every network step reads its cache first, so re-running costs only what is
# missing. DuckDB allows one writer at a time: close any IDE database panel.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# THESIS_DB points every step at another database -- a copy, to try a change
# without touching the real one. R/global.R and the book honour it too.
DB="${THESIS_DB:-data/processed/thesis.db}"
CONFIG="config/collections.yaml"

# Every step, in the order they have to run. A phase is a selection from this
# list, so combining phases never reorders anything.
ALL_STEPS=(init oai xoai metadata people files titlepage access parse population disciplines figures)

# Fetching from Skemman. `files` is here as well as in dataprocessing: the
# title-page download needs the PDF URLs that files-load writes, so fetching
# cannot finish without it. It reads the xoai pages already on disk.
PRE=(init oai xoai files titlepage access)
# Deriving from data/raw alone. Nothing here makes a request.
DATA=(init metadata people files parse)
# Defining the population and the study's views over it.
POST=(population disciplines)
# Running the R.
VIS=(figures)

# Put the virtualenv first on PATH rather than trusting whatever is there.
# `skemman` on PATH can belong to a different Python altogether -- on this
# machine it resolves to the global install -- and the run then silently uses a
# different version of the code. A shebang cannot do this: it selects the shell,
# not the Python environment, so it has to happen here.
if [[ -d .venv/Scripts ]]; then
    VENV_BIN="$ROOT/.venv/Scripts"      # Windows layout
elif [[ -d .venv/bin ]]; then
    VENV_BIN="$ROOT/.venv/bin"          # POSIX layout
else
    VENV_BIN=""
    echo "warning: no .venv found, using whatever is on PATH" >&2
fi

if [[ -n "$VENV_BIN" ]]; then
    export PATH="$VENV_BIN:$PATH"
    export VIRTUAL_ENV="$ROOT/.venv"
    # Anything that shells out to `python` gets the virtualenv's interpreter too.
    unset PYTHONHOME
fi

# Invoked by bare name -- PATH above guarantees which one -- so the echoed
# commands stay readable and match the README.
SKEMMAN="skemman"

DRY_RUN=0
FRESH=0
FROM=""
ONLY=""
LIMIT=""
DEGREE_LEVEL="master"
PHASES=()

usage() {
    awk 'NR > 2 && /^#/ { sub(/^# ?/, ""); print; next } NR > 2 { exit }' "${BASH_SOURCE[0]}"
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --preprocessing)  PHASES+=(PRE); shift ;;
        --dataprocessing) PHASES+=(DATA); shift ;;
        --postprocessing) PHASES+=(POST); shift ;;
        --visualise)      PHASES+=(VIS); shift ;;
        --dry-run)        DRY_RUN=1; shift ;;
        --fresh)          FRESH=1; shift ;;
        --from)           FROM="$2"; shift 2 ;;
        --only)           ONLY="${ONLY:+$ONLY,}$2"; shift 2 ;;
        --limit)          LIMIT="$2"; shift 2 ;;
        --degree-level)   DEGREE_LEVEL="$2"; shift 2 ;;
        -h|--help)        usage 0 ;;
        *)                echo "unknown argument: $1" >&2; usage 1 ;;
    esac
done

run() {
    echo "  \$ $*"
    if [[ $DRY_RUN -eq 1 ]]; then return 0; fi
    "$@"
}

run_sql() {
    echo "  \$ duckdb $DB < $1"
    if [[ $DRY_RUN -eq 1 ]]; then return 0; fi
    mkdir -p "$(dirname "$DB")"
    duckdb "$DB" < "$1"
}

# Only passed when set, so an empty --limit does not become `--limit ''`.
limit_args() {
    if [[ -n "$LIMIT" ]]; then printf '%s %s' --limit "$LIMIT"; fi
}

# DuckDB allows one writing process on the file. An IDE database panel counts,
# and it can connect halfway through a run: the harvest writes per page, so the
# failure lands after the requests have already been spent. 1698 records were
# fetched and thrown away that way. Fail here instead, before touching Skemman.
check_lock() {
    if [[ ! -f "$DB" ]]; then return 0; fi
    if duckdb "$DB" -c "select 1" >/dev/null 2>&1; then return 0; fi
    cat >&2 <<EOF
error: $DB is open in another process.

  DuckDB permits one writer at a time. The usual cause is an IDE database panel
  -- DataSpell or PyCharm -- holding a connection. Disconnect it there, or close
  the IDE, and run this again.

  Nothing was fetched, so nothing is lost.
EOF
    exit 1
}

# --- Steps -------------------------------------------------------------------

step_init() {
    echo "[init] Create the tables. Existing data is left alone -- the SQL is idempotent."
    run_sql scripts/create_thesis_db.sql
}

step_oai() {
    echo "[oai] Harvest the configured handles over OAI-PMH."
    # The only step that decides which theses exist; everything after it works
    # from the rows this produces. Cached pages are read from disk.
    run "$SKEMMAN" oai-pmh --output "$DB" --config "$CONFIG" $(limit_args)
}

step_xoai() {
    echo "[xoai] Harvest the xoai bundle listing: every attached file, about 66 requests."
    # DSpace's own metadata format. It carries each file's name, size, type,
    # download URL, and whether DSpace filed it as COMPLETE_TEXT or DECLARATION
    # -- the repository saying which attachment is the thesis. files-index reads
    # the same off item pages at one request each, 6291 of them.
    run "$SKEMMAN" oai-pmh --metadata-prefix xoai --config "$CONFIG" \
        --output "$DB" $(limit_args)
}

step_metadata() {
    echo "[metadata] Replay the cached OAI XML into the normalized tables. No network."
    run "$SKEMMAN" metadata-load --db "$DB"
    run "$SKEMMAN" clean-people --db "$DB"
}

step_people() {
    echo "[people] Authors and advisors from the cached xoai pages, while the tables are empty. No network."
    # Nothing else in the pipeline creates these rows, and the advisor tier of the discipline
    # mapping reads them. The xoai pages are the source; where they are not on disk, the
    # committed Parquet snapshot fills in (older, and with some mangled names, but the same
    # shape). Both leave a filled table alone.
    if compgen -G "data/raw/oai/xoai_*.xml" > /dev/null; then
        run "$SKEMMAN" people-load --db "$DB"
    fi
    if [[ -f data/db/people.parquet && -f data/db/thesis_people.parquet ]]; then
        run_sql scripts/load_people.sql
    elif ! compgen -G "data/raw/oai/xoai_*.xml" > /dev/null; then
        echo "warning: no xoai pages in data/raw/oai and no snapshot in data/db -- authors and"              "advisors stay empty" >&2
    fi
}

step_files() {
    echo "[files] Read the cached xoai pages into thesis_file, and the degree. No network."
    run "$SKEMMAN" files-load --db "$DB"
}

step_titlepage() {
    echo "[titlepage] Fetch open PDFs and keep their first pages as text."
    # The long one. At the 30-second delay robots.txt asks for, the full
    # master's population is an overnight run.
    run "$SKEMMAN" titlepage-load --db "$DB" --degree-level "$DEGREE_LEVEL" $(limit_args)
}

# xoai does not carry the access status -- 'Opinn' and "Lokadur til dd.mm.yyyy"
# are stated only on the item page -- so titlepage treats unknown as worth
# trying, and a closed thesis fails once and is recorded. That is what makes
# this step cheap: the theses worth asking about are exactly those failures, a
# couple of hundred rather than all 6291. It puts the embargo and its end date
# in the database. A later files-load keeps what it finds.
step_access() {
    echo "[access] Fetch item pages for the theses whose PDF could not be opened."
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  \$ skemman files-index --db $DB --ids <permanent failures>"
        return 0
    fi
    local ids
    ids="$(duckdb "$DB" -noheader -list -c "
        select coalesce(string_agg(distinct thesis_id, ','), '')
        from thesis_titlepage_failure where permanent")"
    if [[ -z "$ids" ]]; then
        echo "  nothing to look up: no permanent failures recorded."
        return 0
    fi
    # One more thesis than there are separators between them.
    echo "  $(( $(tr -cd ',' <<< "$ids" | wc -c) + 1 )) theses, one request each"
    run "$SKEMMAN" files-index --db "$DB" --ids "$ids"
}

step_parse() {
    echo "[parse] Re-read every cached title page into thesis_titlepage. No network."
    # The same parser titlepage runs, over the text already on disk. After a
    # parser change this is the whole update: nothing is downloaded again.
    run "$SKEMMAN" titlepage-load --db "$DB" --degree-level "$DEGREE_LEVEL" --cached-only
}

step_population() {
    echo "[population] The study population: master's theses in the analysis years."
    # SQL cannot read YAML, so the years travel from the config's `analysis:`
    # block into scripts/population.sql as environment variables. The config
    # stays the only place they are written.
    local years
    years="$(python -c '
import sys, yaml
a = yaml.safe_load(open(sys.argv[1], encoding="utf-8"))["analysis"]
print(a["year_start"], a["year_end"], a["stable_start"], a["stable_end"])
' "$CONFIG")"
    read -r ANALYSIS_YEAR_START ANALYSIS_YEAR_END ANALYSIS_STABLE_START ANALYSIS_STABLE_END <<< "$years"
    export ANALYSIS_YEAR_START ANALYSIS_YEAR_END ANALYSIS_STABLE_START ANALYSIS_STABLE_END
    echo "  years $ANALYSIS_YEAR_START-$ANALYSIS_YEAR_END, whole years" \
         "$ANALYSIS_STABLE_START-$ANALYSIS_STABLE_END, from $CONFIG"
    run_sql scripts/population.sql
}

step_disciplines() {
    echo "[disciplines] Apply this study's keyword-to-discipline mapping over the population."
    run_sql scripts/discipline_map.sql
    # With no advisors on file the advisor tier of v_thesis_discipline finds nothing, and the
    # theses it would have settled fall back to the generic discipline without any error.
    if [[ $DRY_RUN -eq 0 ]]; then
        local advisors
        advisors="$(duckdb "$DB" -noheader -list             -c "select count(*) from thesis_people where role = 'advisor'" 2>/dev/null || echo 0)"
        if [[ "$advisors" == "0" ]]; then
            echo "warning: thesis_people holds no advisors, so the advisor tier found nothing."                  "Run scripts/rebuild.sh --only people first." >&2
        else
            local n
            n="$(duckdb "$DB" -noheader -list                 -c "select count(*) from v_thesis_discipline where discipline_source = 'advisor'"                 2>/dev/null || echo '?')"
            echo "  advisor tier: $n thesis(es) take their advisor's field"
        fi
    fi
}

step_figures() {
    echo "[figures] Every figure in R/plots/ to outputs/figures/*.png and outputs/figures.pdf."
    local rscript
    rscript="$(command -v Rscript || true)"
    if [[ -z "$rscript" ]]; then
        # R's Windows installer does not put itself on PATH.
        rscript="$(ls -d /c/Program\ Files/R/R-*/bin/Rscript.exe 2>/dev/null | sort -V | tail -1 || true)"
    fi
    if [[ -z "$rscript" ]]; then
        echo "error: Rscript is neither on PATH nor under C:/Program Files/R" >&2
        exit 1
    fi
    if [[ $DRY_RUN -eq 0 ]]; then mkdir -p outputs; fi
    # One -e per statement. A single -e holding several lines reaches R intact
    # on Linux but not on Windows, where only the first line arrives: the PDF
    # was opened, nothing was drawn into it, and the run still said it worked.
    #
    # save_figures() is in R/global.R: one PNG per script, named after it, and
    # every figure again in a single PDF. What a script skips, and why, is
    # reported on stderr.
    run "$rscript"         -e 'source("R/global.R")'         -e 'save_figures()'
}

# --- Which steps ---------------------------------------------------------------

contains() {
    local needle="$1"; shift
    local s
    for s in "$@"; do [[ "$s" == "$needle" ]] && return 0; done
    return 1
}

wanted=()
if [[ -n "$ONLY" ]]; then
    # A comma list, or --only given more than once. The steps run in pipeline
    # order whatever order they were named in.
    IFS=',' read -r -a named <<< "$ONLY"
    for s in "${named[@]}"; do
        if ! contains "$s" "${ALL_STEPS[@]}"; then echo "unknown step: $s" >&2; exit 1; fi
    done
    for s in "${ALL_STEPS[@]}"; do
        if contains "$s" "${named[@]}"; then wanted+=("$s"); fi
    done
elif [[ -n "$FROM" ]]; then
    seen=0
    for s in "${ALL_STEPS[@]}"; do
        if [[ "$s" == "$FROM" ]]; then seen=1; fi
        if [[ $seen -eq 1 ]]; then wanted+=("$s"); fi
    done
    if [[ ${#wanted[@]} -eq 0 ]]; then echo "unknown step: $FROM" >&2; exit 1; fi
elif [[ ${#PHASES[@]} -gt 0 ]]; then
    selected=()
    for phase in "${PHASES[@]}"; do
        declare -n members="$phase"
        selected+=("${members[@]}")
        unset -n members
    done
    for s in "${ALL_STEPS[@]}"; do
        if contains "$s" "${selected[@]}"; then wanted+=("$s"); fi
    done
else
    wanted=("${ALL_STEPS[@]}")
fi

echo "Root:     $ROOT"
echo "Command:  $(command -v skemman || echo 'not found')"
echo "Database: $DB"
echo "Steps:    ${wanted[*]}"
echo

if [[ $DRY_RUN -eq 0 ]]; then
    check_lock
fi

# --fresh means the database, not the downloads. data/raw is material that cost
# one polite request each, and every table can be rebuilt from it without
# touching Skemman. The old file is moved aside rather than deleted, so a
# rebuild that goes wrong is one `mv` from undone.
if [[ $FRESH -eq 1 && $DRY_RUN -eq 0 && -f "$DB" ]]; then
    stamp="$(date +%Y%m%d-%H%M%S)"
    for f in "$DB" "$DB.wal"; do
        if [[ -f "$f" ]]; then
            mv "$f" "$f.$stamp.bak"
            echo "moved aside: $f -> $f.$stamp.bak"
        fi
    done
    echo
fi

started=$SECONDS
for step in "${wanted[@]}"; do
    if ! declare -F "step_$step" >/dev/null; then
        echo "unknown step: $step" >&2
        exit 1
    fi
    "step_$step"
    echo
done

if [[ $DRY_RUN -eq 0 ]]; then
    echo "Done in $((SECONDS - started))s."
fi
