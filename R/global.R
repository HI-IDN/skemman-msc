#' Shared setup for every figure in the book, and the loader for all of them.
#'
#' Rendering the book to look at one plot is slow, and it fails outright while a
#' loader holds the database. Sourcing this file gives every figure as a
#' function that returns a ggplot object, so it can be drawn, modified, or have
#' its data pulled out.
#'
#' Usage:
#'   source("R/global.R")
#'   rq1_volume()          # draws it
#'   p <- rq1_season()     # or keep it and modify
#'   p + labs(title = "...")
#'   figures()             # what is available
#'   draw_all()            # draw everything in turn
#'
#' One file per figure lives in R/plots/, named after the Quarto chunk it
#' replaces, so a figure in the book and its definition are one search apart.
#' Adding a figure means adding a file there; this loader finds it.
#'
#' Data is re-queried on every call, so a figure drawn after a loader has
#' written more rows shows the new ones. Nothing is cached.

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
})

# --- Project root ----------------------------------------------------------
#
# `source()` gives no reliable way to ask where the sourced file is -- it
# depends on how it was sourced -- so walk up to the project marker instead,
# the same way scripts/query.R does. Everything below is relative to this.

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
# the figures work while a harvest is running, which report_setup.R cannot do:
# it holds a connection open from the moment it is sourced.
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

# --- Shared data ------------------------------------------------------------

#' Master's theses in scope, one row per thesis.
#'
#' NOTE: this is not yet the population defined in the research plan. It is
#' every master's thesis in the two collections; narrowing it to engineering is
#' what the discipline mapping does.
masters <- function(from = 2010, to = 2026) {
  q(sprintf("
    select t.id,
           year(t.date_accepted)  as yr,
           month(t.date_accepted) as man,
           m.university           as uni,
           m.sponsor              as sponsor,
           m.degree_level         as degree_level,
           m.degree_raw           as degree_raw
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

# --- Figures ----------------------------------------------------------------
#
# Each file in R/plots/ defines one function and registers it by calling
# register_figure(). Nothing here needs to know what they are.

.figures <- new.env(parent = emptyenv())

#' Announce a figure so figures() and draw_all() can find it.
#'
#' @param name The function's name, as a string.
#' @param description One line, in Icelandic: it is read, not executed.
register_figure <- function(name, description) {
  assign(name, description, envir = .figures)
  invisible(name)
}

for (f in sort(list.files(file.path(.root, "R", "plots"), "[.][Rr]$", full.names = TRUE))) {
  source(f)
}

#' What figures are defined, and where each one appears in the book.
figures <- function() {
  names <- sort(ls(.figures))
  data.frame(
    figure = names,
    description = vapply(names, function(n) get(n, envir = .figures), character(1)),
    row.names = NULL
  )
}

#' Draw every figure in turn. Interactively, each one waits for Enter.
#'
#' A figure whose data is not in the database yet is skipped with its reason
#' rather than stopping the rest.
draw_all <- function(pause = interactive()) {
  names <- sort(ls(.figures))
  for (name in names) {
    message("--- ", name, ": ", get(name, envir = .figures))
    p <- tryCatch(get(name)(), error = function(e) {
      message("    skipped: ", conditionMessage(e))
      NULL
    })
    if (is.null(p)) next
    print(p)
    if (pause && name != tail(names, 1)) readline("Enter for the next figure...")
  }
  invisible(NULL)
}

message("Loaded ", length(ls(.figures)),
        " figures. figures() lists them, draw_all() draws them all.")
