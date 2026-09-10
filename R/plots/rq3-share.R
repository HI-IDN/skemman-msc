# RQ3 -- each school's share of the year's total.
#
# The counts are in rq1-ggplot.R; this asks the other question, which of the
# two is producing more of what gets produced. A share can rise while the count
# falls.
#
#   source("R/global.R")
#   source("R/plots/rq3-share.R")

if (!exists("hi_colors")) source("R/global.R")

d_rq3_share <- masters_by_year() |>
  group_by(yr) |>
  mutate(hlutfall = n / sum(n)) |>
  ungroup()

p_rq3_share <- ggplot(d_rq3_share, aes(yr, hlutfall, fill = uni)) +
  geom_area(alpha = 0.85) +
  scale_fill_manual(values = hi_colors) +
  scale_y_continuous(labels = percent) +
  scale_x_continuous(breaks = seq(2010, 2026, 2)) +
  labs(x = NULL, y = NULL, fill = NULL)

print(p_rq3_share)
