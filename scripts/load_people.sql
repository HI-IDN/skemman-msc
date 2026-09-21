-- Authors and advisors: people and thesis_people, from the committed Parquet snapshot.
--
-- Nothing in the current pipeline creates these rows -- `metadata-load` fills the theses and
-- keywords, and `clean-people` only tidies people that already exist -- so on a database that
-- was not restored from the snapshot they are empty. The advisor tier of v_thesis_discipline
-- (scripts/discipline_map.sql) and the advisor views need them: with them empty, a thesis that
-- no override, title page or keyword settles quietly falls back to the generic discipline.
--
-- Idempotent: each table is filled only while it is empty, so re-running never duplicates rows
-- and never overwrites people that a later loader may have written. The snapshot is re-exported
-- with scripts/export_db.sql; theses newer than the last export have no people until it is.
--
--   duckdb data/processed/thesis.db < scripts/load_people.sql

insert into people (id, name, year_born, year_died)
select id, name, year_born, year_died
from 'data/db/people.parquet'
where not exists (select 1 from people);

insert into thesis_people (thesis_id, person_id, role, sort_order)
select thesis_id, person_id, role, sort_order
from 'data/db/thesis_people.parquet'
where not exists (select 1 from thesis_people);
