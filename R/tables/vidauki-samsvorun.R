# Appendix -- disciplines that cover the same ground under different names.
#
# Cosine similarity between the two schools' keyword profiles, per pair of
# engineering disciplines, over keywords that are not themselves discipline
# names.
#
#   source("R/global.R")
#   source("R/tables/vidauki-samsvorun.R")

if (!exists(".root")) source("R/global.R")

require_table("v_thesis_discipline")

d_vidauki_samsvorun <- q("
  with dkw as (
    select d.university as uni, d.discipline as disc, k.keyword_norm as kw, count(*) as n
    from v_thesis_discipline d
    join thesis_keywords tk on tk.thesis_id = d.thesis_id
    join keywords k on k.id = tk.keyword_id
    where d.category = 'engineering'
      and d.discipline is not null
      and k.keyword_norm not in (select keyword_norm from discipline_keyword)
      and k.keyword_norm not in ('meistaraprófsritgerðir', 'tækni- og verkfræðideild',
                                 'school of science and engineering', 'rannsóknir', 'ísland')
    group by 1, 2, 3
  ),
  a  as (select disc, kw, n from dkw where uni = 'Háskóli Íslands'),
  b  as (select disc, kw, n from dkw where uni = 'Háskólinn í Reykjavík'),
  na as (select disc, sqrt(sum(n * n)) as m from a group by 1),
  nb as (select disc, sqrt(sum(n * n)) as m from b group by 1)
  select a.disc as \"HÍ\",
         b.disc as \"HR\",
         round(sum(a.n * b.n) / (max(na.m) * max(nb.m)), 3) as \"Líkindi\",
         count(*) as \"Sameiginleg orð\"
  from a
  join b  on a.kw = b.kw
  join na on na.disc = a.disc
  join nb on nb.disc = b.disc
  group by 1, 2
  having count(*) >= 20
  order by \"Líkindi\" desc
  limit 8
", quiet = TRUE)

t_vidauki_samsvorun <- knitr::kable(
  d_vidauki_samsvorun,
  caption = "Greinar sem fjalla um það sama undir ólíkum nöfnum."
)

display(t_vidauki_samsvorun)
