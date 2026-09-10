# Schema appendix -- `thesis_people` and `people` for the two example theses.
#
#   source("R/global.R")
#   source("R/tables/daemi-folk.R")

if (!exists(".root")) source("R/global.R")

d_daemi_folk <- q("
  select tp.thesis_id as \"Ritgerð\", tp.role as \"Hlutverk\", tp.sort_order as \"Röð\",
         p.id as \"Auðkenni\", p.name as \"Nafn\", p.year_born as \"Fæðingarár\"
  from thesis_people tp
  join people p on p.id = tp.person_id
  where tp.thesis_id in (4445, 50249)
  order by tp.thesis_id, tp.role, tp.sort_order
", quiet = TRUE)

t_daemi_folk <- knitr::kable(
  d_daemi_folk,
  caption = "`thesis_people` og `people` — hlutverk og upprunaröð varðveitast."
)

display(t_daemi_folk)
