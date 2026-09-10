# Appendix -- HR's study lines from its two collections. Bold rows form the
# core population.
#
# Filters on study_category, which nothing harvests any more, so on a database
# built today this table is empty. It stays until the title page replaces it.
#
#   source("R/global.R")
#   source("R/tables/vidauki-hr.R")

if (!exists(".root")) source("R/global.R")

require_table("v_thesis_unit_named")

d_vidauki_hr <- q("
  select u.unit_label        as \"Námsleið\",
         count(*)            as \"Fjöldi\",
         max(u.in_core::int) as kjarni
  from v_thesis_unit_named u
  join v_thesis_msc m on m.thesis_id = u.thesis_id
  where u.university_short = 'HR'
    and (m.study_category like 'MEd/MPM/MSc Verkfræðideild%'
      or m.study_category like 'MSc Tölvunarfræðideild%')
  group by 1
  order by 2 desc
", quiet = TRUE)

t_vidauki_hr <- kbl(
  subset(d_vidauki_hr, select = -kjarni),
  caption = "Meistararitgerðir HR úr söfnunum tveimur, allt safnið. Feitletraðar námsleiðir mynda þýðið."
) |>
  row_spec(which(d_vidauki_hr$kjarni == 1), bold = TRUE) |>
  kable_styling(full_width = FALSE)

display(t_vidauki_hr)
