# RQ1 -- 30 or 60 ECTS, by discipline and school.
#
# ECTS is read off the title page (thesis_titlepage.ects), not Skemman's metadata --
# see issue #5. Restricted to `category = 'engineering'`: the professional/MPM track
# runs its own much smaller credit scale (9-20 ECTS for a capstone report, not a full
# thesis) and would otherwise swamp the 30/60 split this asks about. Within
# engineering the field is almost entirely clean: only 4 of 891 recorded values are
# neither 30 nor 60.
#
# There is no clear drift over time at either school -- HÍ's share at 30 ECTS goes
# 44% (2010-15) to 52% (2016-20) back to 36% (2021-26), HR's 70% to 50% to 54%. What
# actually predicts it is the discipline: HR's business-adjacent tracks
# (Fjármála-/Rekstrar-/Byggingar-/Vélaverkfræði) are almost all 30 ECTS, while HÍ's
# core IVT/RT tracks (Rafmagns-, Hugbúnaðar-, Reikniverkfræði) are almost all still 60.
# This plot shows that split directly rather than a time series with nothing in it.
#
# Interactive (plotly), like rq1-ggplot.R: hovering a bar gives the counts behind the
# share, so a 97% on 38 theses reads differently from a 46% on 87.
#
#   source("R/global.R")
#   source("R/plots/rq1-ects.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_discipline")

d_rq1_ects <- q("
  select d.discipline, d.university as uni,
         sum(case when p.ects = 30 then 1 else 0 end) as ects30,
         count(*) as fjoldi
  from v_thesis_msc m
  join thesis_titlepage p on p.thesis_id = m.thesis_id
  join v_thesis_discipline d on d.thesis_id = m.thesis_id
  where d.category = 'engineering' and p.ects in (30, 60)
  group by 1, 2
  having count(*) >= 15
", quiet = TRUE) |>
  mutate(
    hlutfall = ects30 / fjoldi,
    # "Tölvunarfræði" exists at both schools -- the label has to carry the school
    # too, or ggplot treats the two bars as one.
    merki = sprintf("%s (%s)", discipline, if_else(uni == "Háskóli Íslands", "HÍ", "HR")),
    merki = reorder(merki, hlutfall),
    skyring = sprintf("%s<br>30 einingar: %d af %d (%s)", merki, ects30, fjoldi,
                      percent(hlutfall, accuracy = 0.1, decimal.mark = ","))
  )

p_rq1_ects <- ggplot(d_rq1_ects, aes(hlutfall, merki, fill = uni, text = skyring)) +
  geom_col() +
  scale_fill_manual(values = hi_colors) +
  scale_x_continuous(labels = percent, limits = c(0, 1)) +
  labs(x = "Hlutfall 30 einingar", y = NULL, fill = NULL)

display(plotly::ggplotly(p_rq1_ects, tooltip = "text") |>
          plotly::layout(legend = list(orientation = "h", x = 0, y = -0.15)))
