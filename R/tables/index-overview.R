# Front page -- every record the harvest found, by degree level.
#
# One of the few scripts that reads `thesis` directly, on purpose: it describes
# what was harvested, of which the population is one part, so it has to see
# the bachelor's theses, diplomas and doctorates the population leaves out.
#
#   source("R/global.R")
#   source("R/tables/index-overview.R")

if (!exists(".root")) source("R/global.R")

d_index_overview <- q("
  select coalesce(m.degree_level, 'óþekkt') as \"Námsstig\",
         count(*)                           as \"Fjöldi\",
         min(year(t.date_accepted))         as \"Fyrsta ár\",
         max(year(t.date_accepted))         as \"Síðasta ár\"
  from thesis t
  left join thesis_metadata m on m.thesis_id = t.id
  group by 1
  order by 2 desc
", quiet = TRUE)

t_index_overview <- knitr::kable(d_index_overview, caption = "Allar færslur í grunninum, eftir námsstigi.")

display(t_index_overview)
