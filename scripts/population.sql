-- The study population, defined once.
--
-- Everything downstream -- the figures and tables in R/, the Quarto chapters,
-- and the discipline views in discipline_map.sql -- reads from v_thesis_msc and
-- never from `thesis` directly. `thesis` holds every record the harvest found:
-- bachelor's theses, diplomas, doctorates, and years outside the study.
-- Selecting the population in one place means no chapter can quietly count a
-- different one.
--
-- The years come from the `analysis:` block of config/collections.yaml.
-- scripts/rebuild.sh reads it and passes the values in as environment
-- variables, because SQL cannot read YAML:
--
--   bash scripts/rebuild.sh --only population
--
-- Run by hand, the same four variables have to be set, or the casts below
-- fail. That is deliberate: a population with no period is not a default.

create or replace table analysis_period as
select
    getenv('ANALYSIS_YEAR_START')::integer   as year_start,
    getenv('ANALYSIS_YEAR_END')::integer     as year_end,
    -- The whole years. The first years and the current one are partial in the
    -- data, and a partial year distorts a share or a seasonal pattern far more
    -- than it distorts a count.
    getenv('ANALYSIS_STABLE_START')::integer as stable_start,
    getenv('ANALYSIS_STABLE_END')::integer   as stable_end;

-- Master's theses in the analysis years, one row per thesis.
--
-- degree_level = 'master' is the classification metadata-load and files-load
-- settle between them: OAI's dc:type, and xoai's dc.type.degree where OAI said
-- nothing. Records neither source names are not in the population.
--
-- type = 'Thesis' leaves out what is filed as a research project, a report or
-- a staff article, even where Skemman also labels it Master's: the collection
-- is the curator's decision, dc:type the submitter's.
create or replace view v_thesis_msc as
select
    t.id                   as thesis_id,
    t.date_accepted,
    year(t.date_accepted)  as yr,
    month(t.date_accepted) as man,
    m.university,
    m.title_is,
    m.title_en,
    m.abstract_is,
    m.abstract_en,
    m.raw_keywords,
    m.sponsor,
    m.related_url,
    m.degree_raw,
    m.school,
    -- Empty since the item-page scraper was retired. The HR unit rule in
    -- discipline_map.sql still reads it until the title page replaces it.
    m.study_category,
    year(t.date_accepted) between p.stable_start and p.stable_end as in_stable_period
from thesis t
join thesis_metadata m on m.thesis_id = t.id
cross join analysis_period p
where m.degree_level = 'master'
  and m.type = 'Thesis'
  and year(t.date_accepted) between p.year_start and p.year_end;
