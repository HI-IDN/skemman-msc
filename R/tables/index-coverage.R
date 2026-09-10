# Front page -- how often each key field is filled, across the whole harvest.
#
# Reads thesis_metadata directly, on purpose: this is a statement about the
# data Skemman provides, not about the population.
#
#   source("R/global.R")
#   source("R/tables/index-coverage.R")

if (!exists(".root")) source("R/global.R")

d_index_coverage <- q("
  select 'Titill (is)' as \"Breyta\",
         round(100.0 * count(title_is) / count(*), 1) as \"Þekja (%)\"
  from thesis_metadata
  union all select 'Útdráttur (hvaða mál sem er)',
         round(100.0 * count(coalesce(abstract_is, abstract_en)) / count(*), 1) from thesis_metadata
  union all select 'Leitarorð',
         round(100.0 * count(raw_keywords) / count(*), 1) from thesis_metadata
  union all select 'Námsstig',
         round(100.0 * count(degree_level) / count(*), 1) from thesis_metadata
  union all select 'Styrktaraðili',
         round(100.0 * count(sponsor) / count(*), 1) from thesis_metadata
  union all select 'Deild (faculty)',
         round(100.0 * count(faculty) / count(*), 1) from thesis_metadata
", quiet = TRUE)

t_index_coverage <- knitr::kable(
  d_index_coverage,
  caption = "Þekja lykilbreyta í `thesis_metadata`, hlutfall útfyllt."
)

display(t_index_coverage)
