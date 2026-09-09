#' Ad hoc queries against thesis.db, safe to run while a loader is writing.
#'
#' DuckDB allows one process on the file at a time, so a long `skemman` run
#' locks everyone else out. `q()` therefore opens a connection, runs one
#' statement and closes immediately -- and if the file is locked it falls back to
#' the Parquet snapshot in data/db/ instead of failing.
#'
#' Usage:
#'   source("scripts/query.R")
#'   q("select count(*) from thesis")
#'   q("select * from thesis_metadata limit 5")
#'   tables()          # what is available right now
#'   src()             # which source the last query used
#'
#' The snapshot is written by scripts/export_db.sql and is only as fresh as the
#' last export, so `q()` says which source it used whenever that is not the live
#' database.

suppressMessages({
  library(DBI)
  library(duckdb)
})

.query_state <- new.env(parent = emptyenv())
.query_state$source <- NA_character_
.query_state$warned <- FALSE

.find_root <- function(start = getwd()) {
  d <- normalizePath(start, winslash = "/", mustWork = TRUE)
  while (!file.exists(file.path(d, "_quarto.yml"))) {
    parent <- dirname(d)
    if (parent == d) stop("could not locate project root (no _quarto.yml above ", start, ")")
    d <- parent
  }
  d
}

.root <- .find_root()
.db_path <- file.path(.root, "data/processed/thesis.db")
.parquet_dir <- file.path(.root, "data/db")

#' Is the database file available to open right now?
.db_free <- function() {
  con <- tryCatch(
    dbConnect(duckdb::duckdb(), dbdir = .db_path, read_only = TRUE),
    error = function(e) NULL
  )
  if (is.null(con)) return(FALSE)
  dbDisconnect(con, shutdown = TRUE)
  TRUE
}

#' Register each Parquet file as a view of the same name.
.attach_parquet <- function(con) {
  files <- list.files(.parquet_dir, pattern = "[.]parquet$", full.names = TRUE)
  if (!length(files)) {
    stop("thesis.db is locked and data/db/ holds no Parquet snapshot. ",
         "Stop the loader, or run: duckdb data/processed/thesis.db < scripts/export_db.sql")
  }
  for (f in files) {
    dbExecute(con, sprintf(
      "create or replace view %s as select * from read_parquet('%s')",
      tools::file_path_sans_ext(basename(f)), f
    ))
  }
  invisible(files)
}

#' Run one SQL statement and close the connection immediately.
#'
#' @param sql A single SQL statement.
#' @param quiet Suppress the note about which source was used.
#' @return A data frame.
q <- function(sql, quiet = FALSE) {
  live <- .db_free()

  if (live) {
    con <- dbConnect(duckdb::duckdb(), dbdir = .db_path, read_only = TRUE)
    .query_state$source <- "live"
  } else {
    con <- dbConnect(duckdb::duckdb())
    .attach_parquet(con)
    .query_state$source <- "parquet"
  }
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  if (!live && !quiet && !.query_state$warned) {
    stamp <- file.info(list.files(.parquet_dir, "[.]parquet$", full.names = TRUE))$mtime
    message(
      "thesis.db is locked by another process; reading the Parquet snapshot from ",
      format(max(stamp), "%Y-%m-%d %H:%M"), ".\n",
      "Tables written after that export (thesis_titlepage, thesis_file, the ",
      "discipline_* mapping) are not in it."
    )
    .query_state$warned <- TRUE
  }

  dbGetQuery(con, sql)
}

#' Which source did the last query use: "live" or "parquet"?
src <- function() .query_state$source

#' Refresh the Parquet snapshot from the live database.
#'
#' Only possible while nothing else holds the file, so run this before starting
#' a long loader -- then `q()` has fresh data to fall back on for the hour the
#' loader is writing. There is no way to snapshot a database that is locked.
snapshot <- function() {
  if (!.db_free()) {
    stop("thesis.db is locked, so it cannot be snapshotted. ",
         "Stop the loader first -- a locked database cannot be copied or exported.")
  }
  con <- dbConnect(duckdb::duckdb(), dbdir = .db_path, read_only = TRUE)
  on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

  dir.create(.parquet_dir, showWarnings = FALSE, recursive = TRUE)
  present <- dbGetQuery(con, "select table_name from information_schema.tables
                              where table_type = 'BASE TABLE'")$table_name
  # discipline_keyword and discipline_unit are source, seeded by
  # scripts/discipline_map.sql, so they stay out of the snapshot.
  wanted <- setdiff(present, c("discipline_keyword", "discipline_unit"))

  for (tbl in wanted) {
    dbExecute(con, sprintf(
      "copy %s to '%s/%s.parquet' (format parquet, compression zstd)",
      tbl, .parquet_dir, tbl
    ))
  }
  .query_state$warned <- FALSE
  message("Snapshotted ", length(wanted), " tables to ", .parquet_dir)
  invisible(wanted)
}

#' List the tables and views visible right now.
tables <- function() {
  q("select table_name, table_type from information_schema.tables order by 1", quiet = TRUE)
}
