# Appendix -- every unclassified master's thesis and its keywords.
#
#   source("R/global.R")
#   source("R/tables/vidauki-oflokkad.R")

if (!exists(".root")) source("R/global.R")

require_table("v_thesis_unit_named")

d_vidauki_oflokkad <- q("
  select u.university as \"Skóli\",
         u.yr         as \"Ár\",
         u.thesis_id  as \"Auðkenni\",
         coalesce(m.raw_keywords, '(engin leitarorð)') as \"Leitarorð\"
  from v_thesis_unit_named u
  join v_thesis_msc m on m.thesis_id = u.thesis_id
  where u.discipline is null
  order by 1, 2
", quiet = TRUE)

t_vidauki_oflokkad <- kbl(
  d_vidauki_oflokkad,
  caption = "Allar óflokkaðar meistararitgerðir og leitarorð þeirra."
) |>
  kable_styling(full_width = FALSE, font_size = 12)

display(t_vidauki_oflokkad)
