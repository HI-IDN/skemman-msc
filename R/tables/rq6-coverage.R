# RQ6 -- how often an abstract exists, in each language.
#
#   source("R/global.R")
#   source("R/tables/rq6-coverage.R")

if (!exists(".root")) source("R/global.R")

d_rq6_coverage <- masters() |>
  summarise(
    alls = n(),
    `útdráttur (is)` = percent(mean(!is.na(abstract_is)), accuracy = 0.1),
    `útdráttur (en)` = percent(mean(!is.na(abstract_en)), accuracy = 0.1),
    `útdráttur (annað hvort)` = percent(
      mean(!is.na(abstract_is) | !is.na(abstract_en)), accuracy = 0.1
    ),
    .by = uni
  )

t_rq6_coverage <- d_rq6_coverage |>
  rename(Skóli = uni, Alls = alls,
         `Útdráttur (is)` = `útdráttur (is)`,
         `Útdráttur (en)` = `útdráttur (en)`,
         `Útdráttur (annað hvort)` = `útdráttur (annað hvort)`) |>
  knitr::kable(caption = "Þekja útdrátta meðal meistararitgerða.")

display(t_rq6_coverage)
