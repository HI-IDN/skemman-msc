# RQ8 -- how many master's theses lead to a government engineer's licence, and how soon.
#
# An author is matched to the licence lists (verkfræðingar, tæknifræðingar) by name and birth
# year (scripts/licences.sql). A licence counts as "after" when it is granted from 60 days before
# to six years after the thesis was accepted. Only aggregates are reported.
#
# The lists run to mid-2026, so a cohort needs the whole six years to be counted fairly:
# LEYFI_TIL is the last such cohort, and the lag tables stop there. Later cohorts are right-
# censored -- most of their authors have not applied yet -- and are drawn, not summarised.
#
#   source("R/global.R")
#   source("R/tables/rq8-leyfi.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_licence")
require_table("v_thesis_discipline")

LEYFI_TIL <- 2020L
LEYFI_MIN_N <- 8L   # fewest theses in a cell before its median is shown

.leyfi <- "
  from v_thesis_discipline d
  left join v_thesis_licence l using (thesis_id)
"

# Share of theses whose author got a licence, by school and category.
d_rq8_hlutfall <- q(sprintf("
  select d.university as skoli, d.category as flokkur,
         count(*) as fjoldi,
         count(*) filter (where l.licensed_after) as med_leyfi
  %s where d.yr <= %d and d.category <> 'out_of_scope'
  group by all order by 1, 2", .leyfi, LEYFI_TIL), quiet = TRUE) |>
  mutate(flokkur = factor(unname(flokkaheiti[flokkur]), levels = unname(flokkaheiti)),
         hlutfall = round(100 * med_leyfi / fjoldi, 1)) |>
  arrange(skoli, flokkur) |>
  rename(Skóli = skoli, Flokkur = flokkur, Ritgerðir = fjoldi,
         `Höfundur með leyfi` = med_leyfi, `Hlutfall (%)` = hlutfall)

t_rq8_hlutfall <- knitr::kable(
  d_rq8_hlutfall,
  caption = sprintf("Ritgerðir sem enduðu í starfsleyfi verkfræðings eða tæknifræðings, árgangar til og með %d.", LEYFI_TIL)
)

# Median time from thesis to licence, by umbrella discipline, engineering theses only.
d_rq8_bid <- q(sprintf("
  select d.university as skoli, d.umbrella as grein,
         count(*) as fjoldi,
         count(*) filter (where l.licensed_after) as med_leyfi,
         median(l.lag_days) filter (where l.licensed_after) / 365.25 as midgildi,
         quantile_cont(l.lag_days, 0.25) filter (where l.licensed_after) / 365.25 as q1,
         quantile_cont(l.lag_days, 0.75) filter (where l.licensed_after) / 365.25 as q3
  %s where d.yr <= %d and d.category = 'engineering'
  group by all having count(*) >= %d
  order by 1, 3 desc", .leyfi, LEYFI_TIL, LEYFI_MIN_N), quiet = TRUE) |>
  mutate(hlutfall = 100 * med_leyfi / fjoldi)

t_rq8_bid <- d_rq8_bid |>
  transmute(Skóli = skoli, Grein = grein, Ritgerðir = fjoldi,
            `Með leyfi` = med_leyfi, `Hlutfall (%)` = round(hlutfall),
            `Miðgildi (ár)` = round(midgildi, 1),
            `Fjórðungsmörk (ár)` = ifelse(is.na(q1), NA_character_,
                                          sprintf("%.1f – %.1f", q1, q3))) |>
  knitr::kable(caption = sprintf(
    "Tími frá ritgerð til leyfis eftir grein (verkfræðiritgerðir til og með %d; greinar með færri en %d ritgerðir sleppt). Miðgildi miðast við þá sem fengu leyfi.",
    LEYFI_TIL, LEYFI_MIN_N))

# Which list. A licence from before the thesis is a BSc (tæknifræðingur) or an earlier degree.
d_rq8_listar <- q("
  select
    count(*) filter (where is_verkfraedingur and licensed_after and not is_taeknifraedingur) as bara_verk,
    count(*) filter (where is_verkfraedingur and is_taeknifraedingur and licensed_after)      as bada,
    count(*) filter (where is_taeknifraedingur and not is_verkfraedingur and licensed_after)  as bara_taekni,
    count(*) filter (where licensed_before)                                                   as adur,
    count(*) filter (where licensed_late)                                                     as seint
  from v_thesis_licence", quiet = TRUE)

t_rq8_listar <- d_rq8_listar |>
  transmute(`Aðeins verkfræðingur` = bara_verk,
            `Bæði verkfræðingur og tæknifræðingur` = bada,
            `Aðeins tæknifræðingur` = bara_taekni,
            `Leyfi áður en ritgerð var skilað` = adur,
            `Leyfi meira en sex árum síðar` = seint) |>
  knitr::kable(caption = "Ritgerðir eftir því hvaða skrá höfundur er á. Ritgerð getur talist í fleiri en einum dálki.")

# The two ways in from outside the engineering departments.
d_rq8_utan <- q("
  select d.university as skoli, d.category as flokkur, d.discipline as grein, count(*) as fjoldi
  from v_thesis_discipline d join v_thesis_licence l using (thesis_id)
  where l.licensed_after and d.category <> 'engineering'
  group by all order by fjoldi desc, 1", quiet = TRUE) |>
  mutate(flokkur = unname(flokkaheiti[flokkur])) |>
  rename(Skóli = skoli, Flokkur = flokkur, Grein = grein, Ritgerðir = fjoldi)

t_rq8_utan <- knitr::kable(
  d_rq8_utan,
  caption = "Ritgerðir utan verkfræðiflokksins þar sem höfundur fékk síðar starfsleyfi verkfræðings."
)

display(t_rq8_hlutfall)
display(t_rq8_bid)
display(t_rq8_listar)
display(t_rq8_utan)
