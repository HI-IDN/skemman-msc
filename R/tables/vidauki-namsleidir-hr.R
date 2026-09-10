# Appendix -- the study lines HR's keywords give. namsleidir() is in global.R.
#
#   source("R/global.R")
#   source("R/tables/vidauki-namsleidir-hr.R")

if (!exists(".root")) source("R/global.R")

t_vidauki_namsleidir_hr <- namsleidir(
  "HR", "HR: námsleiðir sem leitarorðin gefa, allt meistarastigið.", raða = "flokk"
)

display(t_vidauki_namsleidir_hr)
