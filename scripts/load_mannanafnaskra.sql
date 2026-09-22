-- Þjóðskrá's Mannanafnaskrá, from data/processed/mannanafnaskra.csv (scripts/fetch_mannanafnaskra.py).
-- A fallback source for v_licence_person.kyn (scripts/licences.sql) where the surname-ending rule
-- can't classify someone. About names, not people: no privacy concern.
--
--   duckdb data/processed/thesis.db < scripts/load_mannanafnaskra.sql

delete from mannanafnaskra_name;
insert into mannanafnaskra_name
select id::integer, "icelandicName", type, status, verdict, url
from read_csv('data/processed/mannanafnaskra.csv', header = true, all_varchar = true);

select count(*) as names, count(*) filter (where type in ('DR', 'RDR')) as boy_names,
       count(*) filter (where type in ('ST', 'RST')) as girl_names
from mannanafnaskra_name;
