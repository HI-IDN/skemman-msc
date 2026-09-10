# RQ3 -- each school's total, per year and share, over the whole years.
#
#   source("R/global.R")
#   source("R/tables/rq3-totals.R")

if (!exists(".root")) source("R/global.R")

n_stable_years <- STABLE_TO - STABLE_FROM + 1

d_rq3_totals <- masters() |>
  filter(in_stable_period) |>
  count(uni, name = "alls") |>
  mutate(
    `á ári`  = round(alls / n_stable_years, 1),
    hlutfall = percent(alls / sum(alls), accuracy = 0.1)
  )

t_rq3_totals <- d_rq3_totals |>
  rename(Skóli = uni, Alls = alls, `Á ári` = `á ári`, Hlutfall = hlutfall) |>
  knitr::kable(caption = sprintf(
    "Meistararitgerðir %s, að undanskildum jaðarárum.", stable_label
  ))

display(t_rq3_totals)
