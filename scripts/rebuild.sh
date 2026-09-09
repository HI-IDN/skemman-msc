#!/usr/bin/env bash
#
# Run the whole harvest from nothing, in the order the README describes.
#
# Every step is resumable and caches what it fetches, so this is safe to re-run:
# it only does what is missing. Stopping it and starting it again costs nothing
# but the request that was in flight.
#
#   scripts/rebuild.sh                # all steps, in order
#   scripts/rebuild.sh --dry-run      # print the commands, run nothing
#   scripts/rebuild.sh --from files   # skip ahead
#   scripts/rebuild.sh --only oai     # one step
#   scripts/rebuild.sh --limit 10     # a trial run
#   scripts/rebuild.sh --fresh        # rebuild the database from cache
#   scripts/rebuild.sh --only access  # item pages, for the access status
#
# DuckDB allows one process on the file at a time, so close any IDE database
# panel first.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DB="data/processed/thesis.db"
CONFIG="config/collections.yaml"
STEPS=(init oai metadata files titlepage disciplines)
# `access` exists as a step but is deliberately not in STEPS; see step_access.

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

usage() {
    sed -n '3,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)      DRY_RUN=1; shift ;;
        --fresh)        FRESH=1; shift ;;
        --from)         FROM="$2"; shift 2 ;;
        --only)         ONLY="$2"; shift 2 ;;
        --limit)        LIMIT="$2"; shift 2 ;;
        --degree-level) DEGREE_LEVEL="$2"; shift 2 ;;
        -h|--help)      usage 0 ;;
        *)              echo "unknown argument: $1" >&2; usage 1 ;;
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

step_init() {
    echo "[init] Create the tables. Existing data is left alone -- the SQL is idempotent."
    run_sql scripts/create_thesis_db.sql
}

step_oai() {
    echo "[oai] Harvest the configured handles over OAI-PMH."
    # The only step that decides which theses exist; everything after it works
    # from the rows this produces.
    run "$SKEMMAN" oai-pmh --output "$DB" --config "$CONFIG" $(limit_args)
}

step_metadata() {
    echo "[metadata] Replay the cached OAI XML into the normalized tables. No network."
    run "$SKEMMAN" metadata-load --db "$DB"
    run "$SKEMMAN" clean-people --db "$DB"
}

step_files() {
    echo "[files] Harvest the xoai bundle listing, then read it into thesis_file."
    # xoai is DSpace's own metadata format and it carries every attached file:
    # name, size, type, download URL, and whether DSpace filed it as
    # COMPLETE_TEXT or DECLARATION. That is the repository saying which
    # attachment is the thesis. One paged sweep -- about 66 requests -- where
    # `files-index` reads the same thing off item pages at one request each,
    # 6291 of them.
    #
    # Run before title pages: it is what gives the loader a PDF URL at all, and
    # what lets it tell the thesis from the declaration form.
    run "$SKEMMAN" oai-pmh --metadata-prefix xoai --config "$CONFIG"         --output "$DB" $(limit_args)
    run "$SKEMMAN" files-load --db "$DB"
}

# Run after titlepage. xoai does not carry the access status -- 'Opinn' and
# "Lokadur til dd.mm.yyyy" are stated only on the item page -- so files loaded
# from it have `access` null, and titlepage-load treats unknown as worth trying.
# A thesis that turns out to be closed fails once and is recorded, which is what
# makes this step cheap: the theses worth asking about are exactly the ones that
# failed, a couple of hundred rather than all 6291. It is what puts the embargo
# and its end date in the database, so the closed ones can be counted and their
# release dates read. A later files-load keeps what it finds.
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

step_titlepage() {
    echo "[titlepage] Fetch open PDFs and read what the document itself states."
    # The long one. At the 30-second delay robots.txt asks for, the full
    # master's population is an overnight run.
    run "$SKEMMAN" titlepage-load --db "$DB" --degree-level "$DEGREE_LEVEL" $(limit_args)
}

step_disciplines() {
    echo "[disciplines] Apply this study's keyword-to-discipline mapping and its views."
    run_sql scripts/discipline_map.sql
}

wanted=()
if [[ -n "$ONLY" ]]; then
    wanted=("$ONLY")
elif [[ -n "$FROM" ]]; then
    seen=0
    for s in "${STEPS[@]}"; do
        if [[ "$s" == "$FROM" ]]; then seen=1; fi
        if [[ $seen -eq 1 ]]; then wanted+=("$s"); fi
    done
    if [[ ${#wanted[@]} -eq 0 ]]; then echo "unknown step: $FROM" >&2; exit 1; fi
else
    wanted=("${STEPS[@]}")
fi

echo "Root:     $ROOT"
echo "Command:  $(command -v skemman || echo 'not found')"
echo "Database: $DB"
echo "Steps:    ${wanted[*]}"
echo

if [[ $DRY_RUN -eq 0 ]]; then
    check_lock
fi

# --fresh means the database, not the downloads. data/raw is 324 MB of material
# that cost one polite request each -- 6291 item pages alone -- and every table
# can be rebuilt from it without touching Skemman. The old file is moved aside
# rather than deleted, so a rebuild that goes wrong is one `mv` from undone.
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
