-- Which authors of master's theses hold a government engineering licence, and how long after the
-- thesis they got it.
--
-- Matched in three tiers, best evidence first (v_thesis_author_licence.how / tier):
--   1. full name        -- name_key (accents, case, years, brackets ignored) matches exactly.
--   2. compatible middle name -- first and last name and birth year match, and both sides carry a
--      middle name that is compatible: identical, or one an initial/prefix of the other (the same
--      rule advisor_identity uses in scripts/advisor_units.sql), e.g. "Tómas P. Jónsson"
--      for "Tómas Philip Jónsson". Real positive evidence, not just an absence of conflict.
--   3. first and last name -- first, last and birth year match, but at least one side has no middle
--      name at all, so there is nothing to confirm or contradict. The weakest tier, and the one
--      that produced a real collision: 18555 "Helgi Guðjónsson" (Líffræði) was wrongly matched to
--      a licence that in fact belongs to 28751's "Helgi Þór Guðjónsson" (an exact match) -- both
--      born 1987. A licence row (its own name + birth year, the only identity it has here) is
--      claimed by its single best-tier match across the whole population; a lower-tier match to a
--      different thesis for the same licence row is dropped, not just a same-thesis duplicate.
-- A licence proves that its holder has an engineering degree, not that it is this thesis; a person
-- may hold a licence from an earlier degree (rel = 'before'). No match is a lower bound: not
-- everyone applies, and applying costs money.
--
-- Depends on: v_thesis_msc (population), people, thesis_people, engineer_licence.
-- Independent of the discipline views, which in turn use v_thesis_licence.

-- OAI author metadata sometimes omits a middle name that is printed on the thesis title page.
-- These reviewed title-page names are used only for licence identity matching; they do not
-- rewrite the generic people table. The correction is material when two licence holders share
-- first name, last name and birth year but have incompatible middle names (22691, 23416).
create table if not exists thesis_author_name_override
(
    thesis_id integer not null,
    name      varchar not null,
    source    varchar not null
);

delete from thesis_author_name_override;

insert into thesis_author_name_override values
    (8765,  'Atli Geir Júlíusson',             'title page'),
    (12769, 'Sandra Dís Dagbjartsdóttir',      'title page'),
    (17335, 'Sigurður Andrés Þorvarðarson',    'title page'),
    (17343, 'Samuel Nicholas Perkin',           'human-confirmed against licence identity'),
    (18392, 'Tómas Joð Þorsteinsson',           'human-confirmed against licence identity'),
    (19382, 'Heimir Þór Gíslason',             'title page'),
    (22336, 'Elísabet Edda Guðbjörnsdóttir',   'title page'),
    (22691, 'Jón Smári Einarsson',              'title page'),
    (23416, 'Guðmundur Örn Sigurðsson',         'title page'),
    (25604, 'Höskuldur Goði Þorbjargarson',     'title page'),
    (26927, 'Alasdair Paul Brewer',              'human-confirmed against licence identity'),
    (28765, 'Einar I Ólafsson',                 'title page'),
    (33338, 'Albert Ingi Haraldsson',            'title page'),
    (36416, 'Brandon Nicholas Velasquez',        'human-confirmed against licence identity'),
    (39445, 'Valur I Örnólfsson',               'title page');

create or replace view v_thesis_author as
select m.thesis_id, m.university, m.yr,
       coalesce(make_date(tp_date.year_on_page, coalesce(tp_date.month_on_page, 1), 1), m.date_accepted)
                                                               as date_accepted,
       p.id as person_id, coalesce(o.name, p.name) as name, p.year_born,
       name_key(coalesce(o.name, p.name))                       as nk,
       string_split(name_key(coalesce(o.name, p.name)), ' ')[1] as first_tok,
       string_split(name_key(coalesce(o.name, p.name)), ' ')[-1] as last_tok,
       array_to_string(list_slice(string_split(name_key(coalesce(o.name, p.name)), ' '), 2,
                                   len(string_split(name_key(coalesce(o.name, p.name)), ' ')) - 1), ' ')
                                                              as mid_s
from v_thesis_msc m
join thesis_people tp on tp.thesis_id = m.thesis_id and tp.role = 'author'
join people p on p.id = tp.person_id
left join thesis_titlepage tp_date on tp_date.thesis_id = m.thesis_id
left join thesis_author_name_override o on o.thesis_id = m.thesis_id
where p.year_born is not null;

create or replace view v_licence_key as
select *, name_key(name)                                    as nk,
       string_split(name_key(name), ' ')[1]                 as first_tok,
       string_split(name_key(name), ' ')[-1]                as last_tok,
       array_to_string(list_slice(string_split(name_key(name), ' '), 2,
                                   len(string_split(name_key(name), ' ')) - 1), ' ')
                                                              as mid_s,
       coalesce(licence_date, make_date(licence_year, 7, 1)) as licensed_on
from engineer_licence;

-- Confirmed identity conflicts where incomplete thesis metadata would otherwise allow the
-- weakest first+last+birth-year match. Keep these study-specific corrections here rather than
-- weakening the generic matching rule for every person.
create table if not exists licence_match_exclusion
(
    thesis_id          integer not null,
    licence_name       varchar not null,
    licence_birth_year integer not null,
    reason             varchar not null
);

delete from licence_match_exclusion;

insert into licence_match_exclusion values
    (22691, 'Jón Helgi Einarsson', 1964,
     'Title page names the author Jón Smári Einarsson; incompatible middle name'),
    (23113, 'Fannar Guðmundsson', 1986,
     'Title page names Fannar Benedikt Guðmundsson; government list is treated as full name, and multiple people share first name, last name and birth year'),
    (26950, 'Emilía Maí Valdimarsdóttir', 1986,
     'Title page omits Maí; first name, last name and birth year alone are insufficient to confirm identity');

-- The licence lists as their own population, apart from any thesis: how many people are licensed
-- each year, on which list, and roughly how old they are (licence_year - birth_year; there is no
-- birth date, so this is exact to within about a year). The lists do not record gender; `kyn` is
-- read in two tiers, neither about the person's present gender identity, both about a naming
-- convention: first, the Icelandic patronymic/matronymic ending (-son / -dóttir) on ANY name
-- token, not just the last -- someone can carry a patronymic (Rúnarsson) followed by an inherited
-- family name (Fjeldsted), and the patronymic is still the signal. Second, where that finds
-- nothing (a family name that isn't a patronymic, a foreign surname), EVERY given name (first and
-- any middle names, i.e. every token but the last) is looked up in Þjóðskrá's Mannanafnaskrá
-- (mannanafnaskra_name, scripts/fetch_mannanafnaskra.py) -- not just the first: "Ármannn Einar
-- Lund" has a typo in the first name (so it alone would not be found), but "Einar" alone is
-- enough. mannanafnaskra_name is empty until fetched, so this tier is a no-op rather than an
-- error if it hasn't been. A name registered for both boys and girls (e.g. "Alex"), or given
-- names that disagree with each other, stay null: real ambiguity, not a name this can't read.
create or replace view v_mannanafnaskra_gender as
select lower(name) as given_name, bool_or(type in ('DR', 'RDR')) as is_boy_name,
       bool_or(type in ('ST', 'RST')) as is_girl_name
from mannanafnaskra_name
group by 1;

create or replace view v_licence_given_names as
select el.name as licence_name, el.birth_year as licence_birth_year, gn as given_name
from engineer_licence el,
     unnest(
         case when len(string_split(el.name, ' ')) > 1
              then list_slice(string_split(el.name, ' '), 1, len(string_split(el.name, ' ')) - 1)
              else string_split(el.name, ' ') end
     ) as t(gn);

create or replace view v_licence_person_mannanafnaskra as
select gn.licence_name, gn.licence_birth_year,
       bool_or(g.is_boy_name)  as is_boy_name,
       bool_or(g.is_girl_name) as is_girl_name
from v_licence_given_names gn
join v_mannanafnaskra_gender g on g.given_name = lower(gn.given_name)
group by 1, 2;

create or replace view v_licence_person as
select el.*,
       coalesce(
           case when regexp_matches(lower(el.name), '(^| )[^ ]*dóttir( |$)') then 'kvk'
                when regexp_matches(lower(el.name), '(^| )[^ ]*son( |$)')    then 'kk'
                end,
           case when g.is_boy_name and not g.is_girl_name then 'kk'
                when g.is_girl_name and not g.is_boy_name then 'kvk'
                end
       )                                                    as kyn,
       el.licence_year - el.birth_year                      as aldur
from engineer_licence el
left join v_licence_person_mannanafnaskra g
  on g.licence_name = el.name and g.licence_birth_year = el.birth_year;

create or replace view v_thesis_author_licence as
with exact as (
    select a.thesis_id, a.person_id, l.name as licence_name, l.birth_year as licence_birth_year,
           l.list, l.licence_year, l.licensed_on, a.date_accepted,
           'full name' as how, 1 as tier
    from v_thesis_author a
    join v_licence_key l on l.nk = a.nk and l.birth_year = a.year_born
),
compatible as (
    select a.thesis_id, a.person_id, l.name as licence_name, l.birth_year as licence_birth_year,
           l.list, l.licence_year, l.licensed_on, a.date_accepted,
           'compatible middle name' as how, 2 as tier
    from v_thesis_author a
    join v_licence_key l
      on l.first_tok = a.first_tok and l.last_tok = a.last_tok and l.birth_year = a.year_born
    where a.mid_s <> '' and l.mid_s <> ''
      and (starts_with(a.mid_s, l.mid_s) or starts_with(l.mid_s, a.mid_s))
      and not exists (select 1 from exact e where e.thesis_id = a.thesis_id and e.person_id = a.person_id)
),
loose as (
    select a.thesis_id, a.person_id, l.name as licence_name, l.birth_year as licence_birth_year,
           l.list, l.licence_year, l.licensed_on, a.date_accepted,
           'first and last name' as how, 3 as tier
    from v_thesis_author a
    join v_licence_key l
      on l.first_tok = a.first_tok and l.last_tok = a.last_tok and l.birth_year = a.year_born
    where (a.mid_s = '' or l.mid_s = '')
      and not exists (select 1 from exact e where e.thesis_id = a.thesis_id and e.person_id = a.person_id)
      and not exists (select 1 from compatible c where c.thesis_id = a.thesis_id and c.person_id = a.person_id)
),
hit0_raw as (select * from exact union all select * from compatible union all select * from loose),
hit0 as (
    select h.*
    from hit0_raw h
    where not exists (
        select 1
        from licence_match_exclusion x
        where x.thesis_id = h.thesis_id
          and name_key(x.licence_name) = name_key(h.licence_name)
          and x.licence_birth_year = h.licence_birth_year
    )
),
-- A licence row belongs to its single best-tier match, across the whole population, not just
-- within one thesis: if some thesis matches it at tier 1, a tier-3 match to a different thesis is
-- dropped even though the two theses never compete for the same thesis_id.
best as (
    select licence_name, licence_birth_year, min(tier) as best_tier
    from hit0 group by 1, 2
),
hit as (
    select h.* from hit0 h
    join best b on b.licence_name = h.licence_name and b.licence_birth_year = h.licence_birth_year
                and b.best_tier = h.tier
)
select h.thesis_id, h.person_id, h.list, h.licence_year, h.licensed_on, h.how, h.tier,
       m.university, m.yr, h.date_accepted,
       date_diff('day', h.date_accepted, h.licensed_on) as lag_days,
       -- The 0/+2y window: positive lags are the evidence that a licence follows the thesis.
       -- Negative lags are retained separately because Skemman dates may reflect late uploads
       -- or later metadata updates; see @sec-dreifing in docs/08-verkfraedingsleyfi.qmd.
       case when date_diff('day', h.date_accepted, h.licensed_on) < 0 then 'before'
            when date_diff('day', h.date_accepted, h.licensed_on) <= 2.5 * 365 then 'after'
            else 'late' end as rel
from hit h join v_thesis_msc m using (thesis_id);

-- One row per thesis: the first licence it led to, else the earliest one held. A thesis with two
-- authors counts once, as licensed if either is. match_confidence names the weakest tier ('full
-- name' / 'compatible middle name' / 'first and last name') behind ANY of the thesis's matches --
-- a thesis with several matches is only as trustworthy as its shakiest one.
create or replace view v_thesis_licence as
select thesis_id,
       arg_min(list, case rel when 'after' then 0 when 'late' then 1 else 2 end * 100000 + abs(lag_days)) as list,
       arg_max(how, tier)                                   as match_confidence,
       min(case when rel = 'after' then licensed_on end)   as licensed_on_after,
       min(licensed_on)                                     as licensed_on_first,
       min(case when rel = 'after' then lag_days end)       as lag_days,
       bool_or(rel = 'after')                               as licensed_after,
       bool_or(rel = 'before')                              as licensed_before,
       bool_or(rel = 'late')                                as licensed_late,
       bool_or(list = 'verkfraedingur')                     as is_verkfraedingur,
       bool_or(list = 'taeknifraedingur')                   as is_taeknifraedingur
from v_thesis_author_licence
group by thesis_id;
