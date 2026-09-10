# RQ2 -- three keywords for the same study line.
#
# MPM appears under three names, and a thesis often carries more than one, so
# summing them counts theses twice. The caption states both numbers, and both
# are computed: the caption used to have "945" and "399" typed in, which stops
# being true the moment the population changes.
#
#   source("R/global.R")
#   source("R/tables/rq2-mpm.R")

if (!exists(".root")) source("R/global.R")

d_rq2_mpm <- q("
  with tagged as (
    select tk.thesis_id,
           max(case when k.keyword_norm = 'mpm' then 1 else 0 end)                          as mpm,
           max(case when k.keyword_norm = 'master of project management' then 1 else 0 end) as mopm,
           max(case when k.keyword_norm = 'verkefnastjórnun' then 1 else 0 end)             as vst
    from v_thesis_msc m
    join thesis_keywords tk on tk.thesis_id = m.thesis_id
    join keywords k on k.id = tk.keyword_id
    group by 1
  )
  select sum(mpm)                                              as \"MPM\",
         sum(mopm)                                             as \"Master of project management\",
         sum(vst)                                              as \"Verkefnastjórnun\",
         sum(case when mpm + mopm + vst > 0 then 1 else 0 end) as \"Ólíkar ritgerðir\"
  from tagged
", quiet = TRUE)

t_rq2_mpm <- knitr::kable(
  d_rq2_mpm,
  caption = sprintf(
    "Þrjú leitarorð um sömu námsleið. Samtala þeirra er %d en ritgerðirnar eru %d.",
    as.integer(sum(d_rq2_mpm[1, 1:3])),
    as.integer(d_rq2_mpm[1, 4])
  )
)

display(t_rq2_mpm)
