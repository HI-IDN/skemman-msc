# Appendix -- what remains when only engineering and computer science count.
#
#   source("R/global.R")
#   source("R/tables/vidauki-kjarni.R")

if (!exists(".root")) source("R/global.R")

require_table("v_thesis_unit")

d_vidauki_kjarni <- q("
  select university as \"Skóli\",
         count(*) filter (where in_core)     as \"Í kjarna\",
         count(*) filter (where not in_core) as \"Utan kjarna\",
         round(100.0 * count(*) filter (where in_core) / count(*), 1) as \"% eftir\"
  from v_thesis_unit
  group by 1
", quiet = TRUE)

t_vidauki_kjarni <- knitr::kable(
  d_vidauki_kjarni,
  caption = "Hvað stendur eftir þegar aðeins verkfræði og tölvunarfræði eru talin."
)

display(t_vidauki_kjarni)
