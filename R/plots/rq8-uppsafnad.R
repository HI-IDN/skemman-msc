# RQ8 -- verkfræðingar against tæknifræðingar, running total over time (companion to
# rq8-samanburdur.R, which is the same data as new licences per year).
#
#   source("R/global.R")
#   source("R/plots/rq8-uppsafnad.R")

if (!exists(".root")) source("R/global.R")
require_table("v_licence_person")

d_rq8_uppsafnad <- q("
  select licence_year as ar, list, count(*) as fjoldi
  from v_licence_person
  group by all", quiet = TRUE) |>
  mutate(list = recode(list, verkfraedingur = "Verkfræðingur", taeknifraedingur = "Tæknifræðingur")) |>
  arrange(list, ar) |>
  mutate(uppsafnad = cumsum(fjoldi), .by = list)

p_rq8_uppsafnad <- ggplot(d_rq8_uppsafnad, aes(ar, uppsafnad, colour = list)) +
  geom_line(linewidth = 0.9) +
  scale_colour_manual(values = c(Verkfræðingur = "#10099F", Tæknifræðingur = "#FAC55B")) +
  scale_x_continuous(breaks = seq(1960, 2025, 10)) +
  labs(x = NULL, y = NULL, colour = NULL)

# Interactive (plotly): see rq8-samanburdur.R for why.
display(plotly::ggplotly(p_rq8_uppsafnad, tooltip = c("x", "y", "colour")) |>
          plotly::layout(legend = list(orientation = "h", x = 0, y = -0.15)))
