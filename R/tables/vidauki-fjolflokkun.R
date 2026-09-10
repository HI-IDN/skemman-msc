# Appendix -- how many theses carry keywords of more than one study line.
#
#   source("R/global.R")
#   source("R/tables/vidauki-fjolflokkun.R")

if (!exists(".root")) source("R/global.R")

require_table("v_thesis_unit")

d_vidauki_fjolflokkun <- q("
  with fjoldi as (
    select tk.thesis_id, count(distinct d.discipline) as n
    from thesis_keywords tk
    join keywords k on k.id = tk.keyword_id
    join discipline_keyword d on d.keyword_norm = k.keyword_norm
    join v_thesis_unit u on u.thesis_id = tk.thesis_id
    group by 1
  )
  select case when n = 1 then '1 námsleið' else n || ' námsleiðir' end as \"Leitarorð benda á\",
         count(*) as \"Ritgerðir\",
         round(100.0 * count(*) / sum(count(*)) over (), 1) as \"Hlutfall (%)\"
  from fjoldi
  group by n
  order by n
", quiet = TRUE)

t_vidauki_fjolflokkun <- knitr::kable(
  d_vidauki_fjolflokkun,
  caption = "Hversu margar ritgerðir bera leitarorð fleiri en einnar námsleiðar."
)

display(t_vidauki_fjolflokkun)
