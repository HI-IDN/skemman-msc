# Schema appendix -- two rows of `thesis_metadata`, shown side by side.
#
# Reads the base table directly, on purpose: this appendix documents it.
#
#   source("R/global.R")
#   source("R/tables/daemi-metadata.R")

if (!exists(".root")) source("R/global.R")

d_daemi_metadata <- q("select * from thesis_metadata where thesis_id in (4445, 50249)", quiet = TRUE)

t_daemi_metadata <- d_daemi_metadata |>
  mutate(across(everything(), as.character)) |>
  pivot_longer(-thesis_id, names_to = "Dálkur", values_to = "gildi") |>
  mutate(gildi = if_else(
    !is.na(gildi) & nchar(gildi) > 80,
    paste0(substr(gildi, 1, 80), " …"),
    gildi
  )) |>
  pivot_wider(names_from = thesis_id, values_from = gildi) |>
  knitr::kable(caption = "`thesis_metadata` — ein röð á hverja ritgerð, sýnd á hliðinni.")

display(t_daemi_metadata)
