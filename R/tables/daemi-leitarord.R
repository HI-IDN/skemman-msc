# Schema appendix -- `thesis_keywords` and `keywords` for the two example theses.
#
#   source("R/global.R")
#   source("R/tables/daemi-leitarord.R")

if (!exists(".root")) source("R/global.R")

d_daemi_leitarord <- q("
  select tk.thesis_id as \"Ritgerð\", tk.sort_order as \"Röð\", k.id as \"Auðkenni\",
         k.keyword as \"Leitarorð\", k.keyword_norm as \"Staðlað\"
  from thesis_keywords tk
  join keywords k on k.id = tk.keyword_id
  where tk.thesis_id in (4445, 50249)
  order by tk.thesis_id, tk.sort_order
", quiet = TRUE)

t_daemi_leitarord <- knitr::kable(
  d_daemi_leitarord,
  caption = "`thesis_keywords` og `keywords` — `raw_keywords` eftir klofningu."
)

display(t_daemi_leitarord)
