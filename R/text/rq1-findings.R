# RQ1 -- the findings, as a bulleted list written from the data.
#
# The chunk that runs this is `output: asis`, so the markdown below becomes
# the page. At the console it prints as text.
#
#   source("R/global.R")
#   source("R/text/rq1-findings.R")

if (!exists(".root")) source("R/global.R")

d_rq1_findings <- masters_by_year()

stable <- d_rq1_findings |> filter(yr >= STABLE_FROM, yr <= STABLE_TO)
hi <- stable |> filter(uni == "Háskóli Íslands")
hr <- stable |> filter(uni == "Háskólinn í Reykjavík")

crossover <- d_rq1_findings |>
  pivot_wider(names_from = uni, values_from = n) |>
  filter(`Háskólinn í Reykjavík` > `Háskóli Íslands`) |>
  slice_min(yr, n = 1) |>
  pull(yr)

cat(sprintf(
  paste0(
    "- Á stöðugu tímabili (%s) skilar HÍ að meðaltali **%.0f** ritgerðum á ári ",
    "(bil %d–%d) og HR **%.0f** (bil %d–%d).\n",
    "- HR fer fram úr HÍ árið **%d** og helst yfir eftir það.\n",
    "- Hvorugur skólinn sýnir skýra leitni innan tímabilsins; breytileiki milli ára er ",
    "meiri en nokkur undirliggjandi þróun.\n"
  ),
  stable_label,
  mean(hi$n), min(hi$n), max(hi$n),
  mean(hr$n), min(hr$n), max(hr$n),
  crossover
))
