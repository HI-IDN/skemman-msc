# RQ2 -- the ten most frequent keywords at each school.
#
#   source("R/global.R")
#   source("R/tables/rq2-keywords.R")

if (!exists(".root")) source("R/global.R")

d_rq2_keywords <- q("
  select m.university as \"Skóli\", k.keyword as \"Leitarorð\", count(*) as \"Fjöldi\"
  from v_thesis_msc m
  join thesis_keywords tk on tk.thesis_id = m.thesis_id
  join keywords k on k.id = tk.keyword_id
  group by 1, 2
  qualify row_number() over (partition by m.university order by count(*) desc) <= 10
  order by 1, 3 desc
", quiet = TRUE)

t_rq2_keywords <- knitr::kable(
  d_rq2_keywords,
  caption = "Tíðustu leitarorð, tíu efstu hjá hvorum skóla."
)

display(t_rq2_keywords)
