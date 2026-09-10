# RQ1 -- how many master's theses each school produces per year.
#
# 2010 is not a usable baseline for HR, and the final year is incomplete: the
# database holds theses up to whenever it was last harvested, not to the end of
# December. Both caveats belong in the caption, not in the data.
#
#   source("R/global.R")
#   source("R/plots/rq1-ggplot.R")

if (!exists(".root")) source("R/global.R")

d_rq1_volume <- masters_by_year()

p_rq1_volume <- ggplot(d_rq1_volume, aes(yr, n, colour = uni)) +
  geom_vline(xintercept = 2020, linetype = "dashed", colour = "grey55") +
  annotate(
    "text", x = 2020, y = 0, label = "COVID-19",
    angle = 90, hjust = -0.08, vjust = -0.5, size = 3.4, colour = "grey40"
  ) +
  geom_line(linewidth = 1) +
  geom_point(size = 2) +
  scale_colour_manual(values = hi_colors) +
  scale_y_continuous(labels = comma, limits = c(0, NA)) +
  scale_x_continuous(breaks = year_breaks()) +
  labs(x = NULL, y = "Fjöldi ritgerða", colour = NULL)

display(p_rq1_volume)
