# RQ2 -- which departments the advisors of the engineering theses come from.
#
# An advisor's own department (their staff page, scripts/advisor_units.sql) next to the
# department of the thesis they supervise. Only advisors with a page count, and a page exists
# only for people who still work (or, at HÍ, once worked) at the school, so the second table
# says how much of the supervision is covered before the first is read.
#
#   source("R/global.R")
#   source("R/tables/rq2-leidbeinendur.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_advisor_unit")
require_table("v_advisor_unit_coverage")

.gruppa <- c(
  "Verkfræði og tölvunarfræði" = "Verkfræði og tölvunarfræði",
  "Raunvísindi"                = "Raunvísindi",
  "Annað"                      = "Önnur svið"
)

# Engineering theses: where their advisors' own departments are.
d_rq2_leidb_heima <- q("
  with x as (
    select university_short as skoli,
           advisor_group    as heimadeild,
           count(*)         as fjoldi
    from v_thesis_advisor_unit
    where advisor_group is not null
      and thesis_group = 'Verkfræði og tölvunarfræði'
    group by 1, 2
  )
  select skoli, heimadeild, fjoldi,
         round(100.0 * fjoldi / sum(fjoldi) over (partition by skoli), 1) as hlutfall
  from x
  order by skoli, fjoldi desc
", quiet = TRUE) |>
  mutate(heimadeild = coalesce(unname(.gruppa[heimadeild]), heimadeild)) |>
  rename(Skóli = skoli, `Heimadeild leiðbeinanda` = heimadeild,
         Leiðbeiningar = fjoldi, `Hlutfall (%)` = hlutfall)

t_rq2_leidb_heima <- knitr::kable(
  d_rq2_leidb_heima,
  caption = "Verkfræðiritgerðir eftir því hvar leiðbeinandinn á sjálfur heima (aðeins leiðbeinendur með starfsmannasíðu)."
)

# How much of the supervision that covers.
d_rq2_leidb_thekja <- q("
  select school as skoli,
         advisors, advisors_with_unit,
         supervisions, supervisions_with_unit,
         round(100.0 * supervisions_with_unit / supervisions, 1) as hlutfall
  from v_advisor_unit_coverage
  order by school
", quiet = TRUE) |>
  rename(Skóli = skoli, Leiðbeinendur = advisors, `þar af með deild` = advisors_with_unit,
         Leiðbeiningar = supervisions, `þar af með deild ` = supervisions_with_unit,
         `Þekja leiðbeininga (%)` = hlutfall)

t_rq2_leidb_thekja <- knitr::kable(
  d_rq2_leidb_thekja,
  caption = "Þekja: leiðbeinendur og leiðbeiningar sem heimadeild er þekkt fyrir."
)

display(t_rq2_leidb_heima)
display(t_rq2_leidb_thekja)
