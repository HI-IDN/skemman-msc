#' Shared setup for every figure and table in the book.
#'
#' All R the book runs lives in R/: the chapters source this file, and each
#' chunk reads its code from one script, named after the chunk.
#'
#'   R/plots/   figures      p_* the plot, d_* the data behind it
#'   R/tables/  tables       t_* the table, d_* the data behind it
#'   R/text/    generated prose
#'
#' At the console:
#'
#'   source("R/global.R")
#'   source("R/plots/rq1-ggplot.R")     # draws it
#'   source("R/tables/rq1-table.R")     # shows it
#'   draw_all()                         # every script in turn
#'
#' The population is defined once, in the database: v_thesis_msc holds the
#' master's theses in the analysis years, and analysis_period holds those years.
#' Both come from scripts/population.sql, which rebuild.sh fills from the
#' `analysis:` block of config/collections.yaml. Nothing here reads `thesis`
#' directly, and no year is written into the code.

suppressMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(kableExtra)
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
# Parquet snapshot in data/db/ when the database is locked. THESIS_DB points it
# at another database.
source(file.path(.root, "scripts", "query.R"))

#' Stop with an explanation rather than a binder error when a view is missing.
require_table <- function(name) {
  have <- q(sprintf(
    "select count(*) as n from information_schema.tables where table_name = '%s'",
    name
  ), quiet = TRUE)$n
  if (!have) {
    stop(name, " does not exist yet. It is created by the postprocessing step:\n",
         "  bash scripts/rebuild.sh --postprocessing\n",
         "or, if the database is locked, refresh the snapshot with snapshot().",
         call. = FALSE)
  }
  invisible(TRUE)
}

#' Show a figure or a table, in the book and at the console alike.
#'
#' Inside knitr the object is returned visibly, so knitr renders it the way it
#' renders any chunk result -- a kable as a table, not as its markdown source.
#' At the console, where `source()` prints nothing on its own, it is printed.
display <- function(x) {
  if (isTRUE(getOption("knitr.in.progress"))) return(x)
  print(x)
  invisible(x)
}

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

#' Icelandic long date, e.g. "18. júní 2026". By hand for the same reason.
format_is_date <- function(d) {
  manudir <- c(
    "janúar", "febrúar", "mars", "apríl", "maí", "júní",
    "júlí", "ágúst", "september", "október", "nóvember", "desember"
  )
  sprintf(
    "%d. %s %d",
    as.integer(format(d, "%d")),
    manudir[as.integer(format(d, "%m"))],
    as.integer(format(d, "%Y"))
  )
}

# The analysis' own labels for the discipline categories. The database keeps
# English keys, which are code; the translation belongs in the presentation,
# and this order is the order categories sort in.
flokkaheiti <- c(
  engineering   = "Verkfræði",
  professional  = "Fagnám",
  applied       = "Iðnfræði",
  science       = "Náttúruvísindi",
  out_of_scope  = "Utan sviðs"
)

# --- Population -------------------------------------------------------------

require_table("analysis_period")
require_table("v_thesis_msc")

.period <- q("select * from analysis_period", quiet = TRUE)
YEAR_FROM   <- as.integer(.period$year_start)
YEAR_TO     <- as.integer(.period$year_end)
STABLE_FROM <- as.integer(.period$stable_start)
STABLE_TO   <- as.integer(.period$stable_end)

#' The whole years as text, "2012–2025", for captions.
stable_label <- sprintf("%d–%d", STABLE_FROM, STABLE_TO)

#' Axis breaks across the analysis years.
year_breaks <- function(by = 2) seq(YEAR_FROM, YEAR_TO, by)

#' The population, one row per thesis.
#'
#' NOTE: this is every master's thesis in the two collections and the analysis
#' years, not yet the engineering population in the research plan; narrowing
#' it is what the discipline mapping does.
masters <- function() {
  q("
    select thesis_id, yr, man, university as uni,
           sponsor, abstract_is, abstract_en, in_stable_period
    from v_thesis_msc
  ", quiet = TRUE)
}

#' Theses per year and school.
masters_by_year <- function() {
  masters() |>
    count(yr, uni, name = "n") |>
    arrange(yr, uni)
}

#' Newest thesis in the population, which dates the "final year is incomplete"
#' caveat.
latest_thesis <- q("select max(date_accepted) as d from v_thesis_msc", quiet = TRUE)$d[1]

#' Study lines the keywords give for one school, as a table.
#'
#' Used by both appendix tables, HÍ and HR, so it lives here rather than in
#' either script.
namsleidir <- function(uni, caption, raða = c("fjölda", "námsleið", "flokk")) {
  raða <- match.arg(raða)
  require_table("v_thesis_unit_named")

  tafla <- q(sprintf("
    select discipline as namsleid,
           category   as flokkur,
           count(*)   as fjoldi
    from v_thesis_unit_named
    where discipline is not null
      and university_short = '%s'
    group by 1, 2
  ", uni), quiet = TRUE) |>
    mutate(
      flokkur = coalesce(unname(flokkaheiti[flokkur]), flokkur),
      flokkur = factor(flokkur, levels = unname(flokkaheiti))
    )

  tafla <- switch(raða,
    "fjölda"   = arrange(tafla, desc(fjoldi)),
    "námsleið" = arrange(tafla, namsleid),
    "flokk"    = arrange(tafla, flokkur, desc(fjoldi))
  )

  tafla |>
    rename(Námsleið = namsleid, Flokkur = flokkur, Fjöldi = fjoldi) |>
    knitr::kable(caption = caption)
}

#' Run every script in R/plots, R/tables and R/text in turn.
#'
#' Interactively each waits for Enter. A script whose data is not in the
#' database yet is skipped with its reason rather than stopping the rest.
draw_all <- function(pause = interactive()) {
  files <- unlist(lapply(c("plots", "tables", "text"), function(dir) {
    sort(list.files(file.path(.root, "R", dir), "[.][Rr]$", full.names = TRUE))
  }))
  for (f in files) {
    message("--- ", basename(dirname(f)), "/", basename(f))
    ok <- tryCatch({
      source(f, local = globalenv())
      TRUE
    }, error = function(e) {
      message("    skipped: ", conditionMessage(e))
      FALSE
    })
    if (ok && pause && f != tail(files, 1)) readline("Enter for the next one...")
  }
  invisible(NULL)
}

#' Save every figure in R/plots/ as an image, and all of them in one PDF.
#'
#' Each script is sourced in turn, and the plot it ends on is what source()
#' returns, because display() hands the object back. Images are named after
#' the script, so outputs/figures/rq1-ggplot.png is the figure the chunk
#' rq1-ggplot shows. PNG by default: a chart is flat colour and hard edges,
#' which JPEG blurs. Pass format = "jpg" when a JPEG is needed anyway.
save_figures <- function(dir = file.path(.root, "outputs", "figures"),
                         pdf_file = file.path(.root, "outputs", "figures.pdf"),
                         format = c("png", "jpg"),
                         width = 9, height = 5.5, dpi = 150) {
  format <- match.arg(format)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  files <- sort(list.files(file.path(.root, "R", "plots"), "[.][Rr]$", full.names = TRUE))

  # display() draws on the current device, so with the PDF open each script
  # adds its own page. ggsave() opens a device of its own and returns to this.
  grDevices::pdf(pdf_file, width = width, height = height)
  on.exit(grDevices::dev.off(), add = TRUE)

  written <- character()
  for (f in files) {
    name <- tools::file_path_sans_ext(basename(f))
    p <- tryCatch(source(f, local = globalenv())$value, error = function(e) {
      message("    skipped ", name, ": ", conditionMessage(e))
      NULL
    })
    if (!inherits(p, "ggplot")) next
    out <- file.path(dir, paste0(name, ".", format))
    ggsave(out, p, width = width, height = height, dpi = dpi, bg = "white")
    written <- c(written, out)
  }
  message("Wrote ", length(written), " figures to ", dir, " and ", pdf_file)
  invisible(written)
}

message(sprintf(
  "Population: master's theses %d-%d (whole years %s). Source a script from R/, or draw_all().",
  YEAR_FROM, YEAR_TO, stable_label
))
