# RQ8 -- the share of each year's engineering theses whose author has a licence.
#
# The dashed line is LEYFI_TIL, the last cohort counted as settled (R/tables/rq8-leyfi.R). To its
# right the share falls because the authors have not had time to apply yet, not because fewer do.
#
#   source("R/global.R")
#   source("R/plots/rq8-hlutfall.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_licence")

# Same buffer as R/tables/rq8-leyfi.R (LEYFI_BUFFER), via the shared leyfi_til() in R/global.R.
.leyfi_til <- leyfi_til(2.5, "select max(licence_date) from engineer_licence")

d_rq8_ar <- q("
  select d.yr, d.university as uni,
         count(*) as n,
         count(*) filter (where l.licensed_after) as leyfi
  from v_thesis_discipline d left join v_thesis_licence l using (thesis_id)
  where d.category = 'engineering'
  group by all", quiet = TRUE) |>
  mutate(hlutfall = leyfi / n)

p_rq8_hlutfall <- ggplot(d_rq8_ar, aes(yr, hlutfall, colour = uni)) +
  geom_vline(xintercept = .leyfi_til + 0.5, linetype = "dashed", colour = "grey50") +
  geom_line(linewidth = 0.9) +
  geom_point(aes(size = n), alpha = 0.8) +
  scale_colour_manual(values = hi_colors) +
  scale_size_area(max_size = 3.5, guide = "none") +
  scale_y_continuous(labels = percent, limits = c(0, 1)) +
  scale_x_continuous(breaks = year_breaks()) +
  labs(x = NULL, y = NULL, colour = NULL)

# Named scalars for inline use in prose (docs/08-verkfraedingsleyfi.qmd): the range of the share
# over the settled cohorts (yr <= .leyfi_til), and whichever settled year/school is the outlier low
# point -- found, not asserted, so it stays right if the data moves.
.settled <- d_rq8_ar |> filter(yr <= .leyfi_til)
pct_range_low <- round(100 * min(.settled$hlutfall))
pct_range_high <- round(100 * max(.settled$hlutfall))
.low_point <- .settled |> slice_min(hlutfall, n = 1, with_ties = FALSE)
low_point_ar <- .low_point$yr
low_point_uni <- .low_point$uni
low_point_n <- .low_point$n
low_point_leyfi <- .low_point$leyfi

display(p_rq8_hlutfall)
