# RQ1 -- master's theses per year and school, as a table.
#
#   source("R/global.R")
#   source("R/tables/rq1-table.R")

if (!exists(".root")) source("R/global.R")

d_rq1_table <- masters_by_year()

t_rq1_table <- d_rq1_table |>
  pivot_wider(names_from = uni, values_from = n) |>
  rename(Ár = yr) |>
  knitr::kable(caption = "Meistararitgerðir eftir ári og skóla.")

display(t_rq1_table)
