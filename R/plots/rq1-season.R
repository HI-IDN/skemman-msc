# RQ1 -- what share of a school's theses arrives in each month.
#
# Only the whole years. The first years and the current one are partial in the
# data, and a partial year distorts a seasonal share far more than it distorts
# a count: a year cut off in June doubles June's apparent weight. Which years
# are whole is the population's in_stable_period, not a number written here.
#
#   source("R/global.R")
#   source("R/plots/rq1-season.R")

if (!exists(".root")) source("R/global.R")

d_rq1_season <- masters() |>
  filter(in_stable_period) |>
  count(man, uni, name = "n") |>
  mutate(man = factor(MONTHS_IS[man], levels = MONTHS_IS)) |>
  group_by(uni) |>
  mutate(hlutfall = n / sum(n)) |>
  ungroup()

p_rq1_season <- ggplot(d_rq1_season, aes(man, hlutfall, fill = uni)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  scale_fill_manual(values = hi_colors) +
  scale_y_continuous(labels = percent) +
  labs(x = NULL, y = "Hlutfall ársskila", fill = NULL)

display(p_rq1_season)
