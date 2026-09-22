-- Rebuild thesis.db from the committed Parquet snapshot.
--
-- Run from the repository root, in this order:
--   duckdb data/processed/thesis.db < scripts/restore_db.sql      -- tables
--   duckdb data/processed/thesis.db < scripts/create_thesis_db.sql -- indexes, views
--   duckdb data/processed/thesis.db < scripts/discipline_map.sql   -- mapping layer
--
-- All three are idempotent, so re-running them is safe. This restores the
-- derived tables only; data/raw/ (193 MB of Skemman HTML) stays out of the
-- repository and is refetched by `skemman metadata-load` when needed.

create or replace table thesis          as select * from 'data/db/thesis.parquet';
create or replace table thesis_metadata as select * from 'data/db/thesis_metadata.parquet';
create or replace table people          as select * from 'data/db/people.parquet';
create or replace table thesis_people   as select * from 'data/db/thesis_people.parquet';
create or replace table keywords        as select * from 'data/db/keywords.parquet';
create or replace table thesis_keywords as select * from 'data/db/thesis_keywords.parquet';
create or replace table thesis_titlepage         as select * from 'data/db/thesis_titlepage.parquet';
create or replace table thesis_titlepage_failure as select * from 'data/db/thesis_titlepage_failure.parquet';
create or replace table thesis_titlepage_date    as select * from 'data/db/thesis_titlepage_date.parquet';
create or replace table thesis_access_date       as select * from 'data/db/thesis_access_date.parquet';
create or replace table thesis_fulltext_scan     as select * from 'data/db/thesis_fulltext_scan.parquet';
create or replace table thesis_file              as select * from 'data/db/thesis_file.parquet';

-- The sequences must not hand out ids that already exist in the restored tables.
select setval('people_id_seq',  coalesce((select max(id) from people),  0) + 1);
select setval('keyword_id_seq', coalesce((select max(id) from keywords), 0) + 1);
