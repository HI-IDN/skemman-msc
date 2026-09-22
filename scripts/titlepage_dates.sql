-- Which of the dates a title page states is the thesis's own.
--
-- thesis_titlepage.year_on_page / month_on_page is the page's single best reading, by the
-- kind of line it came from (skemman-harvester's _date_on_page). A page often states more
-- than one date, though, and the best-looking line is sometimes the wrong one: a date from a
-- template left unchanged ("Reykjavík, February 2008" on a thesis copyrighted 2010, 4445),
-- a draft date next to the defence date (43316), a year typed one off (37525). The page alone
-- cannot tell these apart. Skemman's date_accepted can, most of the time, and where it
-- cannot, the thesis's own references can: a web page read on 1 November 2020 was read
-- before the thesis was finished.
--
-- The rule, in order, stopping at the first that settles it:
--
--   1. title_page   The page's best reading is within 3 months of date_accepted. Kept.
--   2. other_date   Another date on the same page, or a month and a year that both appear on
--                   it (4445: February, from the stale line, and 2010, from the copyright),
--                   is within 3 months of date_accepted. The nearest wins. This step also
--                   gives a month to a best reading that has none, when a dated line near
--                   date_accepted states one.
--   3. access_date  The references were read (skemman access-dates) and their latest access
--                   date L supports a candidate: the candidate falls in the six months from
--                   L on. Also admitted here: the page's month-dated lines with the year one
--                   off, a typo nothing else can show (37525: December 2021 on the page,
--                   December 2020 by its references). Of the supported candidates, the one
--                   nearest date_accepted wins, as long as it is either near it or a date
--                   the page really states -- a page date backed by the references stands
--                   even when date_accepted disagrees.
--   4. unresolved   Nothing settles it. The best guess is the page date nearest
--                   date_accepted that its references do not rule out (none earlier than
--                   L), else -- every page date ruled out -- date_accepted itself. These
--                   are listed for a person to check (TODO.md). needs_fulltext marks the
--                   ones whose references have not been read yet:
--                   `bash scripts/rebuild.sh --only dates` reads them.
--
-- Two kinds of candidate are left out throughout: a bare year that only repeats the best
-- reading's year (it would "match" date_accepted at year level and hide a month-level
-- disagreement), and any bare year at all on a page that has a copyright or dated line (next
-- to a real date line, a bare year is more often a citation in the abstract).
--
-- The rule names no thesis. A date a person has checked against the thesis itself goes in
-- thesis_date_reviewed below, which comes before every step (status 'confirmed'); that is
-- for an unresolved case the evidence here cannot reach, not for overruling the rule.
--
-- Needs v_thesis_msc (population.sql) and thesis_titlepage_date (titlepage-load).

-- skemman access-dates creates these; empty until it has run, so the view below still works.
create table if not exists thesis_access_date (
    thesis_id integer, accessed_on date, precision varchar, phrase varchar
);
create table if not exists thesis_fulltext_scan (
    thesis_id integer, n_pages integer, text_chars integer, n_dates integer, scanned_at timestamp
);

-- Human-reviewed thesis dates, with what the review found. Same pattern as
-- thesis_author_name_override in licences.sql.
create or replace table thesis_date_reviewed (
    thesis_id integer not null,
    year      integer not null,
    month     integer,
    source    varchar not null
);

insert into thesis_date_reviewed values
    (4375, 2009, 9, 'human-confirmed: title page (September 2009) is right; deposited in Skemman late');

-- Months between a (year, month) and a date. A year with no month is a span: 0 anywhere in
-- it, otherwise the distance to its nearer end.
create or replace macro months_off(y, m, d) as
    case when m is not null
         then abs(date_diff('month', make_date(y, m, 1), date_trunc('month', d)))
         else greatest(0,
                       date_diff('month', make_date(y, 12, 1), date_trunc('month', d)),
                       date_diff('month', date_trunc('month', d), make_date(y, 1, 1)))
    end;

create or replace view v_titlepage_date_candidate as
with page as (
    select thesis_id, kind, year, month, position from thesis_titlepage_date
),
-- A month and a year that both appear on the page, not necessarily on the same line.
combined as (
    select m.thesis_id, 'combined' as kind, y.year, m.month, null::integer as position
    from (select distinct thesis_id, month from page where month is not null) m
    join (select distinct thesis_id, year from page where kind <> 'year') y using (thesis_id)
),
-- The year typed one off. Only step 3 may use these.
year_typo as (
    select thesis_id, 'year_typo' as kind, year + d as year, month, position
    from page, (values (-1), (1)) t(d)
    where kind in ('copyright', 'dated_city', 'month_year') and month is not null
),
primary_reading as (
    select thesis_id, 'primary' as kind, year_on_page as year, month_on_page as month,
           null::integer as position
    from thesis_titlepage
    where year_on_page is not null
),
everything as (
    select * from primary_reading
    union all select * from page
    union all select * from combined
    union all select * from year_typo
)
select e.thesis_id, e.kind, e.year, e.month, e.position,
       case e.kind when 'primary' then 0 when 'combined' then 2 when 'year_typo' then 3
                   else 1 end                                   as kind_rank,
       months_off(e.year, e.month, m.date_accepted)             as months_off,
       -- The first and last day the candidate could mean.
       make_date(e.year, coalesce(e.month, 1), 1)               as starts_on,
       last_day(make_date(e.year, coalesce(e.month, 12), 1))    as ends_on
from everything e
join v_thesis_msc m using (thesis_id);

create or replace view v_thesis_titlepage_date as
with near as (select 3 as months),
bound as (
    select s.thesis_id, max(a.accessed_on) as accessed_max
    from thesis_fulltext_scan s
    left join thesis_access_date a using (thesis_id)
    group by s.thesis_id
),
c as (
    select c.*, b.thesis_id is not null as scanned, b.accessed_max,
           -- Supported by the references: in the six months from the latest access date on.
           b.accessed_max is not null
             and c.ends_on >= b.accessed_max
             and c.starts_on <= b.accessed_max + interval 6 month  as supported,
           -- Not ruled out by them: no earlier than the latest access date.
           b.accessed_max is null or c.ends_on >= b.accessed_max    as possible
    from v_titlepage_date_candidate c
    join v_titlepage_date_candidate p on p.thesis_id = c.thesis_id and p.kind = 'primary'
    left join bound b on b.thesis_id = c.thesis_id
    -- A year with no month that only repeats the best reading's year says nothing new, and
    -- would hide a month-level disagreement by matching date_accepted at year level.
    where not (c.month is null and c.kind <> 'primary' and c.year = p.year)
      -- A bare year is only worth weighing on a page with nothing better: an academic year
      -- ("A.Y. 2017/2018") is then the whole date. Next to a real date line, a bare year is
      -- more often a citation in the abstract than the thesis's own date.
      and not (c.kind = 'year' and exists (
          select 1 from thesis_titlepage_date a
          where a.thesis_id = c.thesis_id and a.kind <> 'year'))
),
-- Steps 1 and 2 together: every date on the page near date_accepted. A stated month beats
-- none, then the page's best reading beats the rest; among the rest, the nearest.
step12 as (
    select * from c
    where kind <> 'year_typo' and months_off <= (select months from near)
    qualify row_number() over (partition by thesis_id
                               order by month is null, kind_rank > 0, months_off,
                                        kind_rank, position nulls last) = 1
),
step1 as (select * from step12 where kind = 'primary'),
step2 as (select * from step12 where kind <> 'primary'),
step3 as (
    select * from c
    where supported
      and (months_off <= (select months from near) or kind_rank <= 1)
    qualify row_number() over (partition by thesis_id
                               order by months_off, month is null, kind_rank,
                                        position nulls last) = 1
),
guess as (
    select * from c
    where kind_rank <= 1 and possible
    qualify row_number() over (partition by thesis_id
                               order by month is null, months_off, kind_rank,
                                        position nulls last) = 1
),
picked as (
    select p.thesis_id,
           -- When the references rule out every date the page states, date_accepted is
           -- the only date left standing.
           coalesce(r.year, s1.year, s2.year, s3.year, g.year, year(a.date_accepted)) as year,
           case when r.thesis_id  is not null then r.month
                when s1.thesis_id is not null then s1.month
                when s2.thesis_id is not null then s2.month
                when s3.thesis_id is not null then s3.month
                when g.thesis_id  is not null then g.month
                else month(a.date_accepted) end                        as month,
           coalesce(case when r.thesis_id is not null then 'reviewed' end,
                    s1.kind, s2.kind, s3.kind, g.kind, 'date_accepted') as kind,
           case when r.thesis_id  is not null then 'confirmed'
                when s1.thesis_id is not null then 'title_page'
                when s2.thesis_id is not null then 'other_date'
                when s3.thesis_id is not null then 'access_date'
                else 'unresolved' end                                  as status,
           p.year as page_year, p.month as page_month,
           p.scanned, p.accessed_max
    from c p
    left join step1 s1 using (thesis_id)
    left join step2 s2 using (thesis_id)
    left join step3 s3 using (thesis_id)
    left join guess g  using (thesis_id)
    left join thesis_date_reviewed r using (thesis_id)
    join v_thesis_msc a using (thesis_id)
    where p.kind = 'primary'
)
select p.thesis_id,
       p.year  as year_on_page,
       p.month as month_on_page,
       p.kind  as source,
       p.status,
       months_off(p.year, p.month, m.date_accepted) as months_off,
       p.page_year, p.page_month,
       p.accessed_max,
       p.status = 'unresolved' and not p.scanned   as needs_fulltext
from picked p
join v_thesis_msc m using (thesis_id);
