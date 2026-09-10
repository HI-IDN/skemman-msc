# Appendix -- the study lines HÍ's keywords give. namsleidir() is in global.R,
# because the HR table uses it too.
#
#   source("R/global.R")
#   source("R/tables/vidauki-namsleidir-hi.R")

if (!exists(".root")) source("R/global.R")

t_vidauki_namsleidir_hi <- namsleidir(
  "HÍ", "HÍ: námsleiðir sem leitarorðin gefa, allt meistarastigið.", raða = "flokk"
)

display(t_vidauki_namsleidir_hi)
