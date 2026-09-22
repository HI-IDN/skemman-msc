-- The government lists of licensed engineers (verkfræðingar) and technologists (tæknifræðingar),
-- from data/processed/engineer_licences.csv (scripts/fetch_engineer_licences.py).
--
-- Only what the analysis needs is kept: name, birth year, licence date and which list. The
-- kennitala printed on the lists is read for its century digit and birth year in the fetch script
-- and is never written anywhere. The table is replaced whole, so a re-fetch is a re-run.
--
--   duckdb data/processed/thesis.db < scripts/load_licences.sql

-- No per-name typo corrections here: the source is hand-typed and will always have more of
-- them, and hardcoding a fix for each one found is not sustainable. A name that is misspelled
-- on the government page stays misspelled here too -- at most it costs one more "óþekkt kyn"
-- (v_licence_person) or one missed thesis-author match, both already expected/tolerated.

delete from engineer_licence;
insert into engineer_licence
-- A handful of people are printed twice on the source page itself, once with the date spelled
-- out ("4. febrúar 2025") and once numeric ("04.02.25") -- the same grant, not two. Group on the
-- meaningful key and keep one raw_date, so they count once.
select name, birth_year::integer, licence_year::integer, licence_date::date, list,
       -- Defence in depth against a CSV from before the fetch script scrubbed this itself: a
       -- kennitala must never be stored, so anything shaped like one is redacted here too.
       -- (DuckDB's RE2 engine has no lookaround, so this is looser than the fetch script's guard.)
       min(regexp_replace(raw_date, '\d{6}[-.\s]?\d{4}', '<kt>', 'g')) as raw_date
from read_csv('data/processed/engineer_licences.csv', header = true, all_varchar = true)
-- licence_year is null for people the source page itself says never applied for the licence
-- ("... hefur ekki sótt leyfi"): qualified and listed, but not licensed, so they do not belong
-- in a table of licence holders.
where name is not null and birth_year is not null and licence_year is not null
group by name, birth_year::integer, licence_year::integer, licence_date::date, list;

select list, count(*) as licences, min(licence_year) as first_year, max(licence_year) as last_year
from engineer_licence group by list order by list;
