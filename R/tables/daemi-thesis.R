# Schema appendix -- two rows of `thesis`, as an example.
#
# Reads the base table directly, on purpose: this appendix documents it.
#
#   source("R/global.R")
#   source("R/tables/daemi-thesis.R")

if (!exists(".root")) source("R/global.R")

d_daemi_thesis <- q("
  select id, date_accepted, title, authors
  from thesis
  where id in (4445, 50249)
  order by id
", quiet = TRUE)

t_daemi_thesis <- knitr::kable(
  d_daemi_thesis,
  caption = "`thesis` — ein röð á hverja leitarniðurstöðu, þátta úr leitartöflunni."
)

display(t_daemi_thesis)
