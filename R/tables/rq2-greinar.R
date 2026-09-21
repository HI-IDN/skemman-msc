# RQ2 -- which engineering disciplines grew or shrank, early vs late stable
# period. Splits the whole-year window (analysis_period.stable_*) in half so
# a discipline with only a handful of theses a year -- most of them -- is
# compared over several years on each side, not year to year.
#
# Rows are the umbrella discipline (discipline_group), not the niche label the
# title page states: HÍ and HR name and split their study lines differently, so
# the niche labels (Fjármálaverkfræði, Mekatróník, ...) are listed beside the
# umbrella they roll up into instead of being counted as separate rows.
#
#   source("R/global.R")
#   source("R/tables/rq2-greinar.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_discipline")

.mid <- STABLE_FROM + (STABLE_TO - STABLE_FROM) %/% 2

d_rq2_greinar <- q(sprintf("
  select umbrella,
         string_agg(distinct discipline, ', ' order by discipline)
           filter (where discipline <> umbrella) as undirgreinar,
         sum(case when yr between %d and %d then 1 else 0 end) as fyrri,
         sum(case when yr between %d and %d then 1 else 0 end) as seinni
  from v_thesis_discipline
  where category = 'engineering' and yr between %d and %d
  group by umbrella
", STABLE_FROM, .mid, .mid + 1, STABLE_TO, STABLE_FROM, STABLE_TO), quiet = TRUE) |>
  mutate(undirgreinar = coalesce(undirgreinar, ""), breyting = seinni - fyrri) |>
  arrange(desc(breyting))

names(d_rq2_greinar) <- c(
  "Grein",
  "Undirgreinar",
  sprintf("%d–%d", STABLE_FROM, .mid),
  sprintf("%d–%d", .mid + 1, STABLE_TO),
  "Breyting"
)

t_rq2_greinar <- knitr::kable(
  d_rq2_greinar,
  caption = sprintf(
    "Verkfræðigreinar (yfirgreinar), %d–%d borið saman við %d–%d.",
    STABLE_FROM, .mid, .mid + 1, STABLE_TO
  )
)

display(t_rq2_greinar)
