# RQ8 -- date sources used when comparing thesis records with licence lists.

if (!exists(".root")) source("R/global.R")

t_rq8_dagsetningar <- tibble::tibble(
  Heimild = c(
    "Stjórnarráð: starfsleyfislisti",
    "Skemman: OAI metadata",
    "Skemman: færslusíða",
    "Skemman: titilsíða",
    "Útreikningur"
  ),
  Reitur = c(
    "licensed_on",
    "dc.date / date_accepted",
    "Samþykkt",
    "Copyright eða staður og mánuður",
    "Dagsetning ritgerðar sem notuð er í lag_days"
  ),
  Notkun = c(
    "Dagsetning starfsleyfis",
    "Samanburður og varadagsetning",
    "Óháð yfirferð á metadata",
    "Ræður þegar ár titilsíðu og metadata fara ekki saman",
    "Nákvæm metadata-dagsetning er notuð þegar hún er á sama ári; annars titilsíðuár"
  ),
  Sýnidæmi = c(
    "Helga Ingimundardóttir: leyfi 27.12.12",
    "date_accepted / dc.date: 18.2.2010",
    "Samþykkt: 18.2.2010",
    "Reykjavík, February 2010",
    "18.2.2010 → 27.12.2012 (34 mán.)"
  )
) |>
  knitr::kable(caption = "Dagsetningarheimildir í samsvörun ritgerða og starfsleyfa.")

display(t_rq8_dagsetningar)
