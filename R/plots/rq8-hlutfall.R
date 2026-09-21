# RQ8 -- the share of each year's engineering theses whose author has a licence.
#
# The dashed line is the last cohort with the full six years in which to apply
# (LEYFI_TIL in R/tables/rq8-leyfi.R). To its right the share falls because the authors have
# not applied yet, not because fewer do.
#
#   source("R/global.R")
#   source("R/plots/rq8-hlutfall.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_licence")

d_rq8_ar <- q("
  select d.yr, d.university as uni,
         count(*) as n,
         count(*) filter (where l.licensed_after) as leyfi
  from v_thesis_discipline d left join v_thesis_licence l using (thesis_id)
  where d.category = 'engineering'
  group by all", quiet = TRUE) |>
  mutate(hlutfall = leyfi / n)

p_rq8_hlutfall <- ggplot(d_rq8_ar, aes(yr, hlutfall, colour = uni)) +
  geom_vline(xintercept = 2020.5, linetype = "dashed", colour = "grey50") +
  geom_line(linewidth = 0.9) +
  geom_point(aes(size = n), alpha = 0.8) +
  scale_colour_manual(values = hi_colors) +
  scale_size_area(max_size = 3.5, guide = "none") +
  scale_y_continuous(labels = percent, limits = c(0, 1)) +
  scale_x_continuous(breaks = year_breaks()) +
  labs(x = NULL, y = NULL, colour = NULL,
       caption = "Punktastærð: fjöldi ritgerða. Brotalína: síðasti árgangur með sex ár til að sækja um.")

display(p_rq8_hlutfall)
