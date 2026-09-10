# RQ7 -- possible signals of knowledge transfer, and where each stands.
#
#   source("R/global.R")
#   source("R/tables/rq7-signals.R")

if (!exists(".root")) source("R/global.R")

d_rq7_signals <- tibble::tribble(
  ~Merki,                       ~Uppspretta,                     ~Staða,
  "Skráður styrktaraðili",      "`thesis_metadata.sponsor`",     "Lítil þekja, skekkt yfir tíma",
  "Leiðbeinendur",              "`thesis_people`",               "Til staðar, starfsvettvang vantar",
  "Nefndir aðilar í útdrætti",  "`abstract_is` / `abstract_en`", "Óunnið",
  "Þakkarorð",                  "PDF-skjöl",                     "Ekki sótt",
  "Tengd vefslóð",              "`thesis_metadata.related_url`", "Mjög lítil þekja"
)

t_rq7_signals <- knitr::kable(
  d_rq7_signals,
  caption = "Möguleg merki um þekkingaryfirfærslu og staða þeirra."
)

display(t_rq7_signals)
