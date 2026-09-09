-- Export the derived database to per-table Parquet for version control.
--
-- Run from the repository root:
--   duckdb data/processed/thesis.db < scripts/export_db.sql
--
-- Why per-table Parquet and not the .db file:
--
--   thesis.db is one monolithic binary. Adding a column, cleaning a field or
--   reloading metadata rewrites the whole file, so git stores a fresh ~6.5 MB
--   blob for every change no matter how small. Per-table Parquet means a change
--   to thesis_metadata leaves thesis, people and keywords byte-identical, and
--   git stores nothing new for them.
--
--   Parquet over CSV because it keeps types and, crucially, keeps NULL distinct
--   from the empty string -- abstract_en being absent is not the same as being
--   blank, and that distinction carries real meaning in this dataset.
--
-- discipline_keyword and discipline_unit are deliberately NOT exported: they are
-- source, seeded by scripts/discipline_map.sql, not data.

copy thesis          to 'data/db/thesis.parquet'          (format parquet, compression zstd);
copy thesis_metadata to 'data/db/thesis_metadata.parquet' (format parquet, compression zstd);
copy people          to 'data/db/people.parquet'          (format parquet, compression zstd);
copy thesis_people   to 'data/db/thesis_people.parquet'   (format parquet, compression zstd);
copy keywords        to 'data/db/keywords.parquet'        (format parquet, compression zstd);
copy thesis_keywords to 'data/db/thesis_keywords.parquet' (format parquet, compression zstd);

-- Read off the thesis PDFs and off each item's file table. Derived data like the
-- rest, so they belong in the snapshot: without them a snapshot cannot answer
-- anything about faculty, credits or thesis length.
copy thesis_titlepage         to 'data/db/thesis_titlepage.parquet'         (format parquet, compression zstd);
copy thesis_titlepage_failure to 'data/db/thesis_titlepage_failure.parquet' (format parquet, compression zstd);
copy thesis_file              to 'data/db/thesis_file.parquet'              (format parquet, compression zstd);
