# RQ8 -- how long after the thesis the licence comes, by discipline.
#
# The dot is the median, the bar the quarter to three quarters. Only those who got a licence, only
# cohorts with the full six years (LEYFI_TIL), only disciplines with enough theses.
#
#   source("R/global.R")
#   source("R/plots/rq8-bid.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_licence")

d_rq8_bid_p <- q("
  select d.university as skoli, d.umbrella as grein,
         median(l.lag_days) / 365.25 as midgildi,
         quantile_cont(l.lag_days, 0.25) / 365.25 as q1,
         quantile_cont(l.lag_days, 0.75) / 365.25 as q3
  from v_thesis_discipline d join v_thesis_licence l using (thesis_id)
  where d.yr <= 2020 and d.category = 'engineering' and l.licensed_after
  group by all having count(*) >= 8", quiet = TRUE)

p_rq8_bid <- d_rq8_bid_p |>
  mutate(grein = forcats::fct_reorder(grein, midgildi)) |>
  ggplot(aes(midgildi, grein, colour = skoli)) +
  geom_linerange(aes(xmin = q1, xmax = q3), position = position_dodge(0.5), linewidth = 1.1, alpha = 0.6) +
  geom_point(position = position_dodge(0.5), size = 2.6) +
  scale_colour_manual(values = hi_colors) +
  labs(x = "Ár frá lokum ritgerðar til leyfis", y = NULL, colour = NULL)

display(p_rq8_bid)
