# RQ8 -- an independent check on date_accepted's accuracy: the year the title page states for
# itself (thesis_titlepage.year_on_page, skemman-harvester's titlepage_load.py), compared against
# date_accepted (OAI dc.date). year_on_page is read off the front matter itself -- a "Copyright ©
# YYYY" line, or a dated "Reykjavík, Month YYYY" line, or (weakest) the earliest year in that
# block -- not from Skemman's own metadata, so agreement between the two is real corroboration,
# not the same imprecise source read twice.
#
#   source("R/global.R")
#   source("R/tables/rq8-titilsida-dags.R")

if (!exists(".root")) source("R/global.R")
require_table("thesis_titlepage")

d_rq8_titilsida_dags <- q("
  select
    count(*) as total,
    count(*) filter (where t.year_on_page is not null) as with_titlepage_year,
    count(*) filter (where t.year_on_page is not null
                      and abs(year(m.date_accepted) - t.year_on_page) <= 1) as within_1y,
    count(*) filter (where t.year_on_page is not null
                      and abs(year(m.date_accepted) - t.year_on_page) between 2 and 5) as gap_2_5y,
    count(*) filter (where t.year_on_page is not null
                      and abs(year(m.date_accepted) - t.year_on_page) > 5) as gap_over_5y
  from v_thesis_msc m
  left join thesis_titlepage t using (thesis_id)", quiet = TRUE)

n_titlepage_total <- d_rq8_titilsida_dags$total
n_titlepage_year <- d_rq8_titilsida_dags$with_titlepage_year
pct_titilsida_thekja <- round(100 * n_titlepage_year / n_titlepage_total, 1)
n_titilsida_within1y <- d_rq8_titilsida_dags$within_1y
pct_titilsida_within1y <- round(100 * n_titilsida_within1y / n_titlepage_year, 1)
n_titilsida_gap_2_5y <- d_rq8_titilsida_dags$gap_2_5y
n_titilsida_gap_over5y <- d_rq8_titilsida_dags$gap_over_5y
