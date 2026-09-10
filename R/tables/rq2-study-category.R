# RQ2 -- what Skemman's study_category separates, per school.
#
# study_category came from the item-page breadcrumbs, which nothing harvests
# any more, so on a database built today this table shows one empty row per
# school. It stays until the title page replaces it as the unit source.
#
#   source("R/global.R")
#   source("R/tables/rq2-study-category.R")

if (!exists(".root")) source("R/global.R")

d_rq2_study_category <- q("
  select university     as \"Skóli\",
         study_category as \"Flokkur\",
         count(*)       as \"Fjöldi\"
  from v_thesis_msc
  group by 1, 2
  order by 1, 3 desc
", quiet = TRUE)

t_rq2_study_category <- knitr::kable(
  d_rq2_study_category,
  caption = "`study_category` aðgreinir greinar hjá HR en ekki hjá HÍ."
)

display(t_rq2_study_category)
