# RQ5 -- the twenty most frequent values in `sponsor`, uncleaned.
#
#   source("R/global.R")
#   source("R/tables/rq5-top.R")

if (!exists(".root")) source("R/global.R")

d_rq5_top <- q("
  select sponsor as \"Styrktaraðili\", count(*) as \"Fjöldi\"
  from v_thesis_msc
  where sponsor is not null
  group by 1
  order by 2 desc
  limit 20
", quiet = TRUE)

t_rq5_top <- knitr::kable(d_rq5_top, caption = "Tuttugu tíðustu gildi í `sponsor`, óhreinsuð.")

display(t_rq5_top)
