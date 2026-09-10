# RQ7 -- how much advisor data the population has.
#
#   source("R/global.R")
#   source("R/tables/rq7-advisors.R")

if (!exists(".root")) source("R/global.R")

d_rq7_advisors <- q("
  select count(distinct tp.person_id) as \"Leiðbeinendur\",
         count(*)                     as \"Tengingar\"
  from v_thesis_msc m
  join thesis_people tp on tp.thesis_id = m.thesis_id
  where tp.role = 'advisor'
", quiet = TRUE)

t_rq7_advisors <- knitr::kable(
  d_rq7_advisors,
  caption = "Umfang leiðbeinendagagna fyrir meistararitgerðir."
)

display(t_rq7_advisors)
