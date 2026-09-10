#' Shared setup for the figures in R/plots/.
#'
#' Source this once, then source whichever figure you want to look at:
#'
#'   source("R/global.R")
#'   source("R/plots/rq1-ggplot.R")    # draws it; p_rq1_volume holds the plot
#'
#' Each file in R/plots/ is a plain script named after the Quarto chunk it
#' corresponds to. It draws its figure and leaves two objects behind: the plot
#' (p_*) to modify, and the data behind it (d_*) to check a number without
#' re-typing the query. A figure file sources this one itself if it has not been
#' sourced yet, so it also runs on its own.
#'
#' Data is queried when a figure is sourced, so sourcing it again after a
#' loader has written more rows shows the new ones.

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
})

# --- Project root ----------------------------------------------------------
#
# `source()` gives no reliable way to ask where the sourced file is, so walk up
# to the project marker instead, the same way scripts/query.R does.

.root <- local({
  d <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  while (!file.exists(file.path(d, "_quarto.yml"))) {
    parent <- dirname(d)
    if (parent == d) {
      stop("could not locate project root (no _quarto.yml above ", getwd(), ")")
    }
    d <- parent
  }
  d
})

# q() opens a connection, runs one statement and closes it, falling back to the
# Parquet snapshot in data/db/ when the database is locked. That fallback is why
# the figures can be drawn while a harvest is running.
source(file.path(.root, "scripts", "query.R"))

# --- Look -------------------------------------------------------------------

# HÍ palette, matching styles/hi-book.scss.
hi_colors <- c(
  "Háskóli Íslands"       = "#10099F",
  "Háskólinn í Reykjavík" = "#d61f69"
)

# Engineering against the natural sciences, for the appendix breakdown.
field_colors <- c(
  "Verkfræði"      = "#10099F",
  "Náttúruvísindi" = "#2DD2C0"
)

theme_set(
  theme_minimal(base_size = 13) +
    theme(
      legend.position = "bottom",
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold")
    )
)

# Abbreviated Icelandic months. Built by hand rather than via format(), which
# depends on the machine locale and silently falls back to English on CI.
MONTHS_IS <- c("jan", "feb", "mar", "apr", "maí", "jún",
               "júl", "ágú", "sep", "okt", "nóv", "des")

# --- Years ------------------------------------------------------------------
#
# Read from the `analysis:` block of config/collections.yaml, the same file the
# harvester reads. It is separate from the top-level year_start and year_end on
# purpose: those filter what is harvested, and a figure should never be able
# to narrow the next harvest.

.analysis <- yaml::read_yaml(file.path(.root, "config", "collections.yaml"))$analysis
if (is.null(.analysis)) {
  stop("config/collections.yaml has no `analysis:` block with year_start, ",
       "year_end, stable_start and stable_end.", call. = FALSE)
}

YEAR_FROM   <- as.integer(.analysis$year_start)
YEAR_TO     <- as.integer(.analysis$year_end)
STABLE_FROM <- as.integer(.analysis$stable_start)
STABLE_TO   <- as.integer(.analysis$stable_end)

#' Axis breaks across the analysis years.
year_breaks <- function(by = 2) seq(YEAR_FROM, YEAR_TO, by)

# --- Shared data ------------------------------------------------------------

#' Master's theses in scope, one row per thesis.
#'
#' NOTE: this is not yet the population defined in the research plan. It is
#' every master's thesis in the two collections; narrowing it to engineering is
#' what the discipline mapping does.
masters <- function(from = YEAR_FROM, to = YEAR_TO) {
  q(sprintf("
    select t.id,
           year(t.date_accepted)  as yr,
           month(t.date_accepted) as man,
           m.university           as uni,
           m.sponsor              as sponsor
    from thesis t
    join thesis_metadata m on m.thesis_id = t.id
    where m.degree_level = 'master'
      and year(t.date_accepted) between %d and %d
  ", from, to), quiet = TRUE)
}

#' Theses per year and school.
masters_by_year <- function(...) {
  masters(...) |>
    count(yr, uni, name = "n") |>
    arrange(yr, uni)
}

#' Stop with an explanation rather than a binder error when a view is missing.
#'
#' v_thesis_unit and friends are created by scripts/discipline_map.sql, the last
#' step of the pipeline. A database that has not reached it yet is a normal
#' state, not a broken one.
require_table <- function(name) {
  have <- q(sprintf(
    "select count(*) as n from information_schema.tables where table_name = '%s'",
    name
  ), quiet = TRUE)$n
  if (!have) {
    stop(name, " does not exist yet. It is created by the last pipeline step:\n",
         "  duckdb data/processed/thesis.db < scripts/discipline_map.sql\n",
         "or, if the database is locked, refresh the snapshot with snapshot().",
         call. = FALSE)
  }
  invisible(TRUE)
}

#' Source every figure in R/plots/ in turn. Interactively, each waits for Enter.
#'
#' A figure whose data is not in the database yet is skipped with its reason
#' rather than stopping the rest.
draw_all <- function(pause = interactive()) {
  files <- sort(list.files(file.path(.root, "R", "plots"), "[.][Rr]$", full.names = TRUE))
  for (f in files) {
    message("--- ", basename(f))
    ok <- tryCatch({
      source(f, local = globalenv())
      TRUE
    }, error = function(e) {
      message("    skipped: ", conditionMessage(e))
      FALSE
    })
    if (ok && pause && f != tail(files, 1)) readline("Enter for the next figure...")
  }
  invisible(NULL)
}

message("Ready. Source a figure, e.g. source(\"R/plots/rq1-ggplot.R\"), or draw_all().")
