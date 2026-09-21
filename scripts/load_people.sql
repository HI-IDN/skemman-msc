-- Authors and advisors: people and thesis_people, from the Parquet snapshot in data/db/.
--
-- The FALLBACK of the `people` step in scripts/rebuild.sh. The primary source is
-- `skemman people-load`, which reads `dc.contributor.author` and `dc.description.advisor` from
-- the cached xoai pages (data/raw/oai) and so covers every thesis harvested. Use this only where
-- those pages are not on disk. The snapshot is older -- theses newer than the last
-- scripts/export_db.sql export have no people -- and carries a few mangled names (leading accented
-- capitals dropped: `lfar` for Úlfar, `Gudni` for Guðni) that people-load gets right.
--
-- Each table is filled only while it is empty, so re-running never duplicates rows and never
-- overwrites people that people-load already wrote.
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
