# RQ4 -- how often a sponsor is recorded, over the whole population.
#
#   source("R/global.R")
#   source("R/tables/rq4-overall.R")

if (!exists(".root")) source("R/global.R")

d_rq4_overall <- masters() |>
  summarise(
    alls = n(),
    `með styrktaraðila` = sum(!is.na(sponsor)),
    þekja = percent(mean(!is.na(sponsor)), accuracy = 0.1),
    .by = uni
  )

t_rq4_overall <- d_rq4_overall |>
  rename(Skóli = uni, Alls = alls, `Með styrktaraðila` = `með styrktaraðila`,
         Þekja = þekja) |>
  knitr::kable(caption = "Þekja `sponsor` í heild.")

display(t_rq4_overall)
