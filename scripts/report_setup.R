library(DBI)
library(duckdb)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

# Locate the repository root so chapters work from any depth.
find_root <- function(start = getwd()) {
  d <- normalizePath(start, winslash = "/", mustWork = TRUE)
  while (!file.exists(file.path(d, "pyproject.toml"))) {
    parent <- dirname(d)
    if (parent == d) stop("could not locate project root (no pyproject.toml above ", start, ")")
    d <- parent
  }
  d
}

root <- find_root()
db_path <- Sys.getenv("THESIS_DB", unset = file.path(root, "data/processed/thesis.db"))

if (!file.exists(db_path)) {
  stop("thesis.db not found at ", db_path, " - see the README for how to build it.")
}

# DuckDB permits one process on the file; close any IDE connection before rendering.
con <- dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)

# HÍ palette, matching styles/hi-book.scss
hi_colors <- c(
  "Háskóli Íslands"       = "#10099F",
  "Háskólinn í Reykjavík" = "#d61f69"
)

theme_set(
  theme_minimal(base_size = 13) +
    theme(
      legend.position = "bottom",
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold")
    )
)

# Master's theses in scope, one row per thesis.
#
# NOTE: this is not yet the population defined in the research plan. HÍ's
# `school` is Verkfræði- og náttúruvísindasvið, which mixes natural sciences into
# the engineering counts, and `faculty` is empty. Narrowing it needs the
# discipline mapping discussed in RQ2.
masters <- dbGetQuery(con, "
  select t.id,
         year(t.date_accepted) as yr,
         m.university          as uni,
         m.study_category      as study_category,
         m.sponsor             as sponsor,
         m.abstract_is         as abstract_is,
         m.abstract_en         as abstract_en
  from thesis t
  join thesis_metadata m on m.thesis_id = t.id
  where m.degree_level = 'master'
    and year(t.date_accepted) between 2010 and 2026
")

masters_by_year <- masters |>
  count(yr, uni, name = "n") |>
  arrange(yr, uni)
