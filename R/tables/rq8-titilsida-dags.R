# RQ8 -- an independent check on date_accepted's accuracy: the date the title page states for
# itself, compared against date_accepted (OAI dc.date). The page date is read off the front
# matter (skemman-harvester's titlepage_load.py) -- a "Copyright © YYYY" line, a dated
# "Reykjavík, Month YYYY" line, or (weakest) a bare year -- not from Skemman's own metadata, so
# agreement between the two is real corroboration, not the same imprecise source read twice.
#
# Where the page states more than one date, v_thesis_titlepage_date (scripts/titlepage_dates.sql)
# chooses among them, using date_accepted and, failing that, the access dates in the thesis's
# own references. `status` says which step settled it.
#
#   source("R/global.R")
#   source("R/tables/rq8-titilsida-dags.R")

if (!exists(".root")) source("R/global.R")
require_table("thesis_titlepage")
require_table("v_thesis_titlepage_date")

d_rq8_titilsida_dags <- q("
  select
    count(*) as total,
    count(d.year_on_page) as with_titlepage_year,
    count(*) filter (where abs(year(m.date_accepted) - d.year_on_page) <= 1) as within_1y,
    count(*) filter (where abs(year(m.date_accepted) - d.year_on_page) between 2 and 5) as gap_2_5y,
    count(*) filter (where abs(year(m.date_accepted) - d.year_on_page) > 5) as gap_over_5y,
    count(*) filter (where d.status = 'other_date') as other_date,
    count(*) filter (where d.status = 'access_date') as access_date,
    count(*) filter (where d.status = 'unresolved') as unresolved
  from thesis_titlepage t
  join v_thesis_msc m using (thesis_id)
  left join v_thesis_titlepage_date d using (thesis_id)", quiet = TRUE)

n_titlepage_total <- d_rq8_titilsida_dags$total
n_titlepage_year <- d_rq8_titilsida_dags$with_titlepage_year
pct_titilsida_thekja <- round(100 * n_titlepage_year / n_titlepage_total, 1)
n_titilsida_within1y <- d_rq8_titilsida_dags$within_1y
pct_titilsida_within1y <- round(100 * n_titilsida_within1y / n_titlepage_year, 1)
n_titilsida_gap_2_5y <- d_rq8_titilsida_dags$gap_2_5y
n_titilsida_gap_over5y <- d_rq8_titilsida_dags$gap_over_5y
n_titilsida_other_date <- d_rq8_titilsida_dags$other_date
n_titilsida_access_date <- d_rq8_titilsida_dags$access_date
n_titilsida_unresolved <- d_rq8_titilsida_dags$unresolved
