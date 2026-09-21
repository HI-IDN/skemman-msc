-- Useful DuckDB queries for thesis.db

-- Simple comparison: counts per year.
select extract(year from date_accepted) as year,
  count(*) as n
from thesis
group by year
order by year;

-- Metadata coverage: how many theses have metadata rows.
select count(*)                      as total_thesis,
       count(m.thesis_id)            as with_metadata,
       count(*) - count(m.thesis_id) as missing_metadata
from thesis t
         left join thesis_metadata m on m.thesis_id = t.id;

-- Missing metadata rows (ids).
select t.id
from thesis t
         left join thesis_metadata m on m.thesis_id = t.id
where m.thesis_id is null
order by t.id;

-- Metadata completeness checks for key fields.
select thesis_id,
       title_is is not null    as has_title_is,
       title_en is not null    as has_title_en,
       abstract_is is not null as has_abstract_is,
       abstract_en is not null as has_abstract_en,
       sponsor is not null     as has_sponsor,
       pdf_url is not null     as has_pdf_url
from thesis_metadata
order by thesis_id;

-- Which theses are closed, and until when.
--
-- `access` is filled by files-index, which is run only for the theses whose PDF
-- could not be opened -- xoai, where the file table comes from, does not carry
-- the access status at all. A thesis with no row here is not necessarily open;
-- it may simply never have been asked about.
select
    f.thesis_id,
    m.title_is,
    m.degree_level,
    f.access,
    try_strptime(regexp_extract(f.access, '(\d{2}\.\d{2}\.\d{4})', 1), '%d.%m.%Y')::date as opens,
    'https://skemman.is/handle/1946/' || f.thesis_id as item_url
from thesis_file f
join thesis_metadata m on m.thesis_id = f.thesis_id
where f.role = 'primary'
  and f.access is not null
  and f.access <> 'Opinn'
order by opens nulls last, f.thesis_id;


select degree_level, count(*) from thesis_metadata group by degree_level;
select type, degree_level, count(*) from thesis_metadata group by all order by all;

-- Theses with no level: neither dc:type nor the collection names one.
select thesis_id, collection, title_is, title_en
from thesis_metadata
where type = 'Thesis' and degree_level is null
order by collection, thesis_id;
