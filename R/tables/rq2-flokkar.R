# RQ2 -- how the population splits across the study categories, per school.
#
#   source("R/global.R")
#   source("R/tables/rq2-flokkar.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_discipline")

d_rq2_flokkar <- q("
  select university as uni,
         category   as flokkur,
         count(*)   as fjoldi
  from v_thesis_discipline
  group by 1, 2
", quiet = TRUE) |>
  mutate(flokkur = factor(coalesce(unname(flokkaheiti[flokkur]), flokkur),
                           levels = unname(flokkaheiti))) |>
  tidyr::pivot_wider(names_from = uni, values_from = fjoldi, values_fill = 0) |>
  arrange(flokkur) |>
  mutate(Samtals = rowSums(across(where(is.numeric)))) |>
  rename(Flokkur = flokkur)

t_rq2_flokkar <- knitr::kable(
  d_rq2_flokkar,
  caption = sprintf("Greinaflokkun þýðisins, %s.", stable_label)
)

display(t_rq2_flokkar)
