# Front page -- where each research question stands.
#
#   source("R/global.R")
#   source("R/tables/index-status.R")

if (!exists(".root")) source("R/global.R")

d_index_status <- tibble::tribble(
  ~Spurning, ~Efni,                          ~Staða,
  "RS1",     "Þróun umfangs",                "Svarað",
  "RS2",     "Þróun fræðasviða",             "Bíður greinaflokkunar",
  "RS3",     "Samanburður HÍ og HR",         "Að hluta",
  "RS4",     "Samstarf við atvinnulíf",      "Gögn ófullnægjandi",
  "RS5",     "Tegund samstarfsaðila",        "Gögn ófullnægjandi",
  "RS6",     "Þróun rannsóknarviðfangsefna", "Framkvæmanlegt",
  "RS7",     "Þekkingaryfirfærsla",          "Háð RS4 og RS5"
)

t_index_status <- knitr::kable(d_index_status)

display(t_index_status)
