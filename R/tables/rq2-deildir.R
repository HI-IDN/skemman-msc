# RQ2 -- discipline broken down by department (unit), per school.
#
#   source("R/global.R")
#   source("R/tables/rq2-deildir.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_unit_named")

d_rq2_deildir <- q("
  select university_short as uni,
         unit_short       as deild,
         category         as flokkur,
         count(*)         as fjoldi
  from v_thesis_unit_named
  group by 1, 2, 3
", quiet = TRUE) |>
  mutate(flokkur = coalesce(unname(flokkaheiti[flokkur]), flokkur)) |>
  arrange(uni, desc(fjoldi)) |>
  rename(Skóli = uni, Deild = deild, Flokkur = flokkur, Fjöldi = fjoldi)

t_rq2_deildir <- knitr::kable(
  d_rq2_deildir,
  caption = "Ritgerðir eftir deild og fræðasviði."
)

display(t_rq2_deildir)
