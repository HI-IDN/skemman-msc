-- Which authors of master's theses hold a government engineering licence, and how long after the
-- thesis they got it.
--
-- A match is the full name (name_key: accents, case, years and brackets ignored) together with the
-- birth year, which both the Skemman author record and the licence lists carry. The second pass
-- takes a first-and-last-name match with the same birth year for people whose middle names are
-- written differently in the two sources. A licence proves that its holder has an engineering
-- degree, not that it is this thesis; a person may hold a licence from an earlier degree
-- (rel = 'before'). No match is a lower bound: not everyone applies, and applying costs money.
--
-- Depends on: v_thesis_msc (population), people, thesis_people, engineer_licence.
-- Independent of the discipline views, which in turn use v_thesis_licence.

create or replace view v_thesis_author as
select m.thesis_id, m.university, m.yr, m.date_accepted,
       p.id as person_id, p.name, p.year_born,
       name_key(p.name) as nk,
       split_part(name_key(p.name), ' ', 1) as first_tok,
       regexp_extract(name_key(p.name), '([^ ]+)$', 1) as last_tok
from v_thesis_msc m
join thesis_people tp on tp.thesis_id = m.thesis_id and tp.role = 'author'
join people p on p.id = tp.person_id
where p.year_born is not null;

create or replace view v_licence_key as
select *, name_key(name) as nk,
       split_part(name_key(name), ' ', 1) as first_tok,
       regexp_extract(name_key(name), '([^ ]+)$', 1) as last_tok,
       coalesce(licence_date, make_date(licence_year, 7, 1)) as licensed_on
from engineer_licence;

create or replace view v_thesis_author_licence as
with exact as (
    select a.thesis_id, a.person_id, l.list, l.licence_year, l.licensed_on, 'full name' as how
    from v_thesis_author a
    join v_licence_key l on l.nk = a.nk and l.birth_year = a.year_born
),
loose as (
    select a.thesis_id, a.person_id, l.list, l.licence_year, l.licensed_on, 'first and last name' as how
    from v_thesis_author a
    join v_licence_key l
      on l.first_tok = a.first_tok and l.last_tok = a.last_tok and l.birth_year = a.year_born
    where not exists (select 1 from exact e where e.thesis_id = a.thesis_id and e.person_id = a.person_id)
),
hit as (select * from exact union all select * from loose)
select h.thesis_id, h.person_id, h.list, h.licence_year, h.licensed_on, h.how,
       m.university, m.yr, m.date_accepted,
       date_diff('day', m.date_accepted, h.licensed_on) as lag_days,
       case when date_diff('day', m.date_accepted, h.licensed_on) < -60 then 'before'
            when date_diff('day', m.date_accepted, h.licensed_on) <= 6 * 365 then 'after'
            else 'late' end as rel
from hit h join v_thesis_msc m using (thesis_id);

-- One row per thesis: the first licence it led to, else the earliest one held. A thesis with two
-- authors counts once, as licensed if either is.
create or replace view v_thesis_licence as
select thesis_id,
       arg_min(list, case rel when 'after' then 0 when 'late' then 1 else 2 end * 100000 + abs(lag_days)) as list,
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
