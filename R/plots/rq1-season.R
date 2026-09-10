# RQ1 -- what share of a school's theses arrives in each month.
#
# The edge years are dropped. 2010-2011 and the current year are not whole
# years, and a partial year distorts a seasonal share far more than it distorts
# a count: a year cut off in June doubles June's apparent weight.
#
#   source("R/global.R")
#   source("R/plots/rq1-season.R")

if (!exists("hi_colors")) source("R/global.R")

season_from <- STABLE_FROM
season_to   <- STABLE_TO

d_rq1_season <- masters(season_from, season_to) |>
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

print(p_rq1_season)
