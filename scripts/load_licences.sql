-- The government lists of licensed engineers (verkfræðingar) and technologists (tæknifræðingar),
-- from data/processed/engineer_licences.csv (scripts/fetch_engineer_licences.py).
--
-- Only what the analysis needs is kept: name, birth year, licence date and which list. The
-- kennitala printed on the lists is read for its century digit and birth year in the fetch script
-- and is never written anywhere. The table is replaced whole, so a re-fetch is a re-run.
--
--   duckdb data/processed/thesis.db < scripts/load_licences.sql

delete from engineer_licence;
insert into engineer_licence
select name, birth_year::integer, licence_year::integer, licence_date::date, list, raw_date
from read_csv('data/processed/engineer_licences.csv', header = true, all_varchar = true)
where name is not null and birth_year is not null;

select list, count(*) as licences, min(licence_year) as first_year, max(licence_year) as last_year
from engineer_licence group by list order by list;
