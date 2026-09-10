# RQ1 -- how much of a year's output arrives after the newest thesis's date.
#
# The final year is incomplete, and this says by how much: the share of a
# whole year's theses that, in a typical year, arrive after the day of the
# newest thesis in the database. The cut-off is that date, read from the
# population, so the table stays true as the harvest moves forward.
#
#   source("R/global.R")
#   source("R/tables/rq1-truncation.R")

if (!exists(".root")) source("R/global.R")

d_rq1_truncation <- q(sprintf("
  select university as \"Skóli\",
         count(*)   as \"Ritgerðir á ári\",
         round(
           100.0 * sum(case when dayofyear(date_accepted) > dayofyear(date '%s')
                            then 1 else 0 end) / count(*), 1
         ) as \"%% eftir %s\"
  from v_thesis_msc
  where in_stable_period
  group by 1
", format(latest_thesis, "%Y-%m-%d"), format_is_date(latest_thesis)), quiet = TRUE)

t_rq1_truncation <- knitr::kable(
  d_rq1_truncation,
  caption = sprintf(
    "Hlutfall ársskila sem berst eftir %s, dagsetningu nýjustu ritgerðar í grunninum.",
    sub(" \\d{4}$", "", format_is_date(latest_thesis))
  )
)

display(t_rq1_truncation)
