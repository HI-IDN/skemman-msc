# RQ4 -- how often a sponsor is recorded at all.
#
# This measures coverage of the `sponsor` field, and that is all it can
# measure. The fall at HÍ from 2010 is a change in cataloguing practice, not a
# collapse in industry collaboration -- collaboration that is never written
# down is invisible here by construction.
#
#   source("R/global.R")
#   source("R/plots/rq4-coverage.R")

if (!exists("hi_colors")) source("R/global.R")

d_rq4_sponsor <- masters() |>
  group_by(yr, uni) |>
  summarise(hlutfall = mean(!is.na(sponsor)), .groups = "drop")

p_rq4_sponsor <- ggplot(d_rq4_sponsor, aes(yr, hlutfall, colour = uni)) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_colour_manual(values = hi_colors) +
  scale_y_continuous(labels = percent, limits = c(0, NA)) +
  scale_x_continuous(breaks = year_breaks()) +
  labs(x = NULL, y = "Með skráðan styrktaraðila", colour = NULL)

print(p_rq4_sponsor)
