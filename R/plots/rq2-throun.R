# RQ2 -- how many verkfræði theses each school produced per year.
#
#   source("R/global.R")
#   source("R/plots/rq2-throun.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_discipline")

d_rq2_throun <- q("
  select yr, university as uni, count(*) as n
  from v_thesis_discipline
  where category = 'engineering'
  group by 1, 2
", quiet = TRUE)

p_rq2_throun <- ggplot(d_rq2_throun, aes(yr, n, color = uni)) +
  geom_line(linewidth = 1) +
  geom_point(size = 1.5) +
  scale_color_manual(values = hi_colors) +
  scale_x_continuous(breaks = year_breaks()) +
  labs(x = NULL, y = NULL, color = NULL)

display(p_rq2_throun)
