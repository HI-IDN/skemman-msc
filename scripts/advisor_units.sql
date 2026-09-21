-- Advisors' own home departments, from the universities' staff pages.
--
-- Input (helper scripts that need the network, NOT part of rebuild.sh; see TODO.md):
--   data/processed/hi_staff_units.csv   scripts/scrape_hi_staff.py  (HI staff pages)
--   data/processed/hr_staff_units.csv   scripts/scrape_hr_staff.py  (RU staff directory)
-- Both are gitignored. Run from the repository root, after scripts/discipline_map.sql:
--   duckdb data/processed/thesis.db < scripts/advisor_units.sql
--
-- The point: place each advisor by their OWN department instead of by the department of the
-- theses they supervise, which is all the database knows otherwise. A page exists only for
-- people who still work at (or, for HI, once worked at) the university, so coverage is partial
-- and biased toward current staff: v_advisor_unit_coverage says how partial.
--
-- People are matched on a normalised name, not on person_id: the scrapers were run against an
-- older people table whose ids no longer exist, and a name is also all a staff page has.

-- A comparable form of a person's name: lower case, no accents, eth -> d, thorn -> th, ae and o
-- for the ligatures strip_accents leaves alone (without them Sævarsdóttir splits in two), no
-- years or bracketed notes, "Last, First" -> "First Last", letters and single spaces only.
create or replace macro name_key(s) as
    trim(regexp_replace(
        regexp_replace(
            replace(replace(replace(replace(lower(strip_accents(
                case
                    when contains(regexp_replace(s, '\(.*?\)', '', 'g'), ',')
                    then trim(split_part(regexp_replace(s, '\(.*?\)', '', 'g'), ',', 2))
                         || ' ' ||
                         trim(split_part(regexp_replace(s, '\(.*?\)', '', 'g'), ',', 1))
                    else regexp_replace(s, '\(.*?\)', '', 'g')
                end)), 'ð', 'd'), 'þ', 'th'), 'æ', 'ae'), 'ø', 'o'),
            '[^a-z ]', ' ', 'g'),
        '\s+', ' ', 'g'));

create or replace table advisor_unit_raw as
select 'HÍ' as page_school, name, status, title, school as svid, unit as unit_raw, url, fetched
from read_csv('data/processed/hi_staff_units.csv', all_varchar = true)
union all
select 'HR', name, status, title, null, unit, url, fetched
from read_csv('data/processed/hr_staff_units.csv', all_varchar = true);

-- What each unit string on a staff page means. `unit_group` is comparable across the two
-- universities. Source, like discipline_unit: the strings are what the pages say, the meaning
-- is a judgment. A string not listed keeps its own text, kind 'annað' and group 'Annað'.
--
--   Verkfræði og tölvunarfræði -- HI's three engineering deilds (IVT includes computer science)
--                                 and RU's Verkfræði-, Tölvunarfræði- and Tæknifræðideild
--   Raunvísindi                -- HI's natural-science deilds, their institutes and labs
--   Annað                      -- health, business, psychology, law, management offices
create or replace table advisor_unit_map
(
    unit_raw   varchar,
    unit       varchar,
    unit_group varchar,
    kind       varchar
);

insert into advisor_unit_map (unit_raw, unit, unit_group, kind) values
-- HI: deilds as the page names them (a ", kennsla" / ", rannsóknir" suffix is stripped first)
('Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', 'Verkfræði og tölvunarfræði', 'deild'),
('Umhverfis- og byggingarverkfræðideild',                   'Umhverfis- og byggingarverkfræðideild',                   'Verkfræði og tölvunarfræði', 'deild'),
('Rafmagns- og tölvuverkfræðideild',                        'Rafmagns- og tölvuverkfræðideild',                        'Verkfræði og tölvunarfræði', 'deild'),
('Raunvísindadeild',                                        'Raunvísindadeild',                                        'Raunvísindi', 'deild'),
('Jarðvísindadeild',                                        'Jarðvísindadeild',                                        'Raunvísindi', 'deild'),
('Líf- og umhverfisvísindadeild',                           'Líf- og umhverfisvísindadeild',                           'Raunvísindi', 'deild'),
-- HI: research affiliations and programmes that name a deild by another name
('Tölvunarfræði',                            'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', 'Verkfræði og tölvunarfræði', 'deild'),
('Véla-og iðnaðarverkfræði',                 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', 'Verkfræði og tölvunarfræði', 'deild'),
('Rafmagnsverkfræðistofa',                   'Rafmagns- og tölvuverkfræðideild',                        'Verkfræði og tölvunarfræði', 'stofnun'),
('Umhverfis- og auðlindafræði',              'Líf- og umhverfisvísindadeild',                           'Raunvísindi', 'deild'),
('Jarðvísindastofnun',                       'Jarðvísindadeild',                                        'Raunvísindi', 'stofnun'),
('Eðlisvísindastofnun, Reiknifræðistofa',    'Raunvísindadeild',                                        'Raunvísindi', 'stofnun'),
('Eðlisvísindastofnun, Efnafræðistofa',      'Raunvísindadeild',                                        'Raunvísindi', 'stofnun'),
('Tæknifræðisetur',                          'Tæknifræðisetur',                                         'Verkfræði og tölvunarfræði', 'stofnun'),
-- HI: outside the engineering and natural-science deilds
('Matvæla- og næringarfræðideild',           'Matvæla- og næringarfræðideild',           'Annað', 'deild'),
('Læknadeild',                               'Læknadeild',                               'Annað', 'deild'),
('Læknadeild, Lífefnafræði',                 'Læknadeild',                               'Annað', 'deild'),
('Lífvísindasetur',                          'Læknadeild',                               'Annað', 'stofnun'),
('Lyfjafræðideild kennsla/rekstur',          'Lyfjafræðideild',                          'Annað', 'deild'),
('Lyfjafræðideild',                          'Lyfjafræðideild',                          'Annað', 'deild'),
('Hjúkrunar- og ljósmóðurfræðideild',        'Hjúkrunar- og ljósmóðurfræðideild',        'Annað', 'deild'),
('Sálfræðideild',                            'Sálfræðideild',                            'Annað', 'deild'),
('Viðskiptafræðideild',                      'Viðskiptafræðideild',                      'Annað', 'deild'),
-- RU: the page names the deild directly
('Verkfræðideild',                           'Verkfræðideild',                           'Verkfræði og tölvunarfræði', 'deild'),
('Tölvunarfræðideild',                       'Tölvunarfræðideild',                       'Verkfræði og tölvunarfræði', 'deild'),
('Tæknifræðideild',                          'Tæknifræðideild',                          'Verkfræði og tölvunarfræði', 'deild'),
('Iðnaðar- og rafmagnssvið',                 'Tæknifræðideild',                          'Verkfræði og tölvunarfræði', 'deild'),
('Viðskipta- og hagfræðideild',              'Viðskipta- og hagfræðideild',              'Annað', 'deild'),
('Íþróttafræðideild',                        'Íþróttafræðideild',                        'Annað', 'deild'),
('MPM',                                      'MPM',                                      'Annað', 'deild'),
('Lagadeild',                                'Lagadeild',                                'Annað', 'deild'),
('Tæknisvið',                                'Tæknisvið',                                'Annað', 'annað'),
('Skrifstofa rektors',                       'Skrifstofa rektors',                       'Annað', 'annað');

-- One row per staff-page hit, with the unit string cleaned (suffix stripped, page junk dropped)
-- and given its meaning.
create or replace view v_advisor_unit_page as
with cleaned as (
    select
        r.*,
        nullif(trim(regexp_replace(r.unit_raw, ',\s*(kennsla|rannsóknir)\s*$', '')), '') as unit_clean
    from advisor_unit_raw r
    where r.status = 'ok'
      and r.unit_raw not in ('Var efnið hjálplegt?', 'Tölvupóstur', 'Email')
)
select
    c.page_school,
    c.name,
    name_key(c.name)                               as name_key,
    c.title,
    c.unit_raw,
    coalesce(m.unit, c.unit_clean)                 as unit,
    coalesce(m.unit_group, case when c.unit_clean is null then null else 'Annað' end)
                                                   as unit_group,
    coalesce(m.kind, case when c.unit_clean is null then null else 'annað' end)
                                                   as kind,
    c.url,
    c.fetched
from cleaned c
left join advisor_unit_map m on m.unit_raw = c.unit_clean;

-- Advisor identity. The people table keeps one row per (name, year_born) as the record spells
-- it, so one advisor can be several rows: "Guðrún A. Sævarsdóttir" (31 supervisions) and
-- "Guðrún Arnbjörg Sævarsdóttir" (10) are the same person. Two rows are aliases only when they
-- share a NON-NULL birth year, the same first and last name, and compatible middle names (one has
-- none, or every middle name of the shorter is an initial or prefix of one in the other): a
-- namesake with another middle name, or with no birth year, is left alone. The row with the
-- most supervisions is the canonical one.
create or replace table advisor_identity as
with a as (
    select p.id, p.year_born, name_key(p.name) as k, count(*) as n
    from people p
    join thesis_people tp on tp.person_id = p.id and tp.role = 'advisor'
    group by 1, 2, 3
),
t as (
    select
        *,
        string_split(k, ' ')                                                  as tok,
        string_split(k, ' ')[1]                                               as first_tok,
        string_split(k, ' ')[-1]                                              as last_tok,
        list_slice(string_split(k, ' '), 2, len(string_split(k, ' ')) - 1)    as mid,
        array_to_string(list_slice(string_split(k, ' '), 2, len(string_split(k, ' ')) - 1), ' ')
                                                                              as mid_s
    from a
    where year_born is not null and len(string_split(k, ' ')) >= 2
),
pairs as (
    select x.id as a_id, x.n as a_n, y.id as b_id, y.n as b_n
    from t x
    join t y
      on x.year_born = y.year_born and x.first_tok = y.first_tok and x.last_tok = y.last_tok
     and x.id < y.id and x.k <> y.k
    -- one side has no middle name, or one is an initial / abbreviation that starts the other:
    -- "a" for "arnbjorg", "kr" for "kristjan", "c" for "christian" (either side may be the short one)
    where x.mid_s = '' or y.mid_s = ''
       or starts_with(y.mid_s, x.mid_s) or starts_with(x.mid_s, y.mid_s)
),
edges as (
    select a_id as id, b_id as other, b_n as other_n from pairs
    union all select b_id, a_id, a_n from pairs
    union all select id, id, n from a
),
first_pass as (
    select id, arg_max(other, other_n * 1000000 - other) as canonical_id from edges group by 1
)
select f.id as person_id, g.canonical_id
from first_pass f
join first_pass g on g.id = f.canonical_id;

-- An advisor's home unit. A person row is matched on the normalised name to a staff page of a
-- school where they supervised in-scope theses, and only when that name names exactly one person
-- there (a namesake with another birth year would otherwise inherit the unit). A person found on
-- both schools' pages keeps the page of the school where they supervise most.
create or replace view v_advisor_unit as
with advisor_school as (
    select
        coalesce(i.canonical_id, tp.person_id) as person_id,
        u.university_short as school,
        count(*)           as n
    from thesis_people tp
    left join advisor_identity i on i.person_id = tp.person_id
    join v_thesis_unit u on u.thesis_id = tp.thesis_id and u.in_scope_broad
    where tp.role = 'advisor'
    group by 1, 2
),
person_school as (
    select
        p.id as person_id, p.name, p.year_born, name_key(p.name) as name_key,
        a.school, a.n,
        sum(a.n) over (partition by p.id)                          as supervisions,
        first_value(a.school) over (partition by p.id order by a.n desc, a.school) as main_school
    from people p
    join advisor_school a on a.person_id = p.id
),
-- every spelling a person goes by, so a page matches whichever form the staff page uses
spellings as (
    select distinct coalesce(i.canonical_id, p.id) as person_id, name_key(p.name) as name_key
    from people p
    left join advisor_identity i on i.person_id = p.id
),
namesakes as (
    select sp.name_key, ps.school, count(distinct ps.person_id) as n_people
    from person_school ps
    join spellings sp on sp.person_id = ps.person_id
    group by 1, 2
),
hits as (
    select
        ps.person_id, ps.name, ps.year_born, ps.supervisions, ps.main_school,
        pg.page_school, pg.title, pg.unit_raw, pg.unit, pg.unit_group, pg.kind, pg.url,
        pg.fetched,
        row_number() over (
            partition by ps.person_id
            order by (pg.page_school = ps.main_school) desc, pg.page_school
        ) as rn
    from person_school ps
    join spellings sp on sp.person_id = ps.person_id
    join v_advisor_unit_page pg on pg.name_key = sp.name_key and pg.page_school = ps.school
    join namesakes n on n.name_key = sp.name_key and n.school = ps.school
    where n.n_people = 1
)
select person_id, name, year_born, supervisions, main_school, page_school, title, unit_raw,
       unit, unit_group, kind, url, fetched
from hits
where rn = 1 and unit is not null;

-- How partial the picture is: the advisors and supervisions a home unit is known for.
create or replace view v_advisor_unit_coverage as
with sup as (
    select
        u.university_short as school,
        coalesce(i.canonical_id, tp.person_id) as person_id,
        count(*) as n
    from thesis_people tp
    left join advisor_identity i on i.person_id = tp.person_id
    join v_thesis_unit u on u.thesis_id = tp.thesis_id and u.in_scope_broad
    where tp.role = 'advisor'
    group by 1, 2
)
select
    s.school,
    count(*)                                                     as advisors,
    count(*) filter (where a.person_id is not null)              as advisors_with_unit,
    sum(s.n)                                                     as supervisions,
    sum(s.n) filter (where a.person_id is not null)              as supervisions_with_unit
from sup s
left join v_advisor_unit a on a.person_id = s.person_id
group by 1;

-- Each supervision: the thesis's unit next to the advisor's own, where the advisor's is known.
-- `same_unit` compares the deilds (a thesis's `unit_label` for HI, the advisor's mapped unit);
-- `same_group` compares the wider group, which is the fair comparison across the two schools.
create or replace view v_thesis_advisor_unit as
select
    u.thesis_id,
    u.yr,
    u.university_short,
    u.unit_label       as thesis_unit,
    u.category         as thesis_category,
    coalesce(i.canonical_id, tp.person_id) as person_id,
    a.name             as advisor,
    a.unit             as advisor_unit,
    a.unit_group       as advisor_group,
    a.kind             as advisor_kind,
    a.unit is not distinct from u.unit_label as same_unit,
    case
        when u.university_short = 'HR' and u.unit_label in ('Verkfræðideild', 'Tölvunarfræðideild', 'Tæknifræðideild')
            then 'Verkfræði og tölvunarfræði'
        when u.unit_label in ('Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild',
                              'Umhverfis- og byggingarverkfræðideild', 'Rafmagns- og tölvuverkfræðideild')
            then 'Verkfræði og tölvunarfræði'
        when u.unit_label in ('Raunvísindadeild', 'Jarðvísindadeild', 'Líf- og umhverfisvísindadeild')
            then 'Raunvísindi'
        else 'Annað'
    end                as thesis_group
from v_thesis_unit u
join thesis_people tp on tp.thesis_id = u.thesis_id and tp.role = 'advisor'
left join advisor_identity i on i.person_id = tp.person_id
left join v_advisor_unit a on a.person_id = coalesce(i.canonical_id, tp.person_id)
where u.in_scope_broad;
