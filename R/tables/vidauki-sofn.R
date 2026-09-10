# Appendix -- the collections the search returns. Bold rows form the population.
#
# school and study_category came from the item-page breadcrumbs, which nothing
# harvests any more, so on a database built today this shows one empty row.
# It stays until the title page replaces it.
#
#   source("R/global.R")
#   source("R/tables/vidauki-sofn.R")

if (!exists(".root")) source("R/global.R")

d_vidauki_sofn <- q("
  select school         as \"Svið\",
         study_category as \"Safn\",
         count(*)       as \"Fjöldi\"
  from v_thesis_msc
  group by 1, 2
  order by 1, 3 desc
", quiet = TRUE)

# The three collections the population is drawn from. At HÍ one collection
# covers what HR splits in two, which is exactly why the schools are treated
# differently.
valin <- c(
  "Meistaraprófsritgerðir - Verkfræði- og náttúruvísindasvið",
  "MEd/MPM/MSc Verkfræðideild (áður Tækni- og verkfræðideild) og íþróttafræðideild -2019 / Department of Engineering (was Dep. of Science and Engineering)",
  "MSc Tölvunarfræðideild / Department of Computer Science"
)

t_vidauki_sofn <- kbl(d_vidauki_sofn, caption = "Söfnin sem leitin skilar. Feitletruð söfn mynda þýðið.") |>
  row_spec(which(d_vidauki_sofn$Safn %in% valin), bold = TRUE) |>
  kable_styling(full_width = FALSE)

display(t_vidauki_sofn)
