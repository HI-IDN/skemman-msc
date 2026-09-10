# Schema appendix -- rows in each table of the current build.
#
# Reads the base tables directly, on purpose: this appendix documents them.
#
#   source("R/global.R")
#   source("R/tables/schema-sizes.R")

if (!exists(".root")) source("R/global.R")

d_schema_sizes <- q("
  select 'thesis' as \"Tafla\", count(*) as \"Raðir\" from thesis
  union all select 'thesis_metadata', count(*) from thesis_metadata
  union all select 'people', count(*) from people
  union all select 'thesis_people', count(*) from thesis_people
  union all select 'keywords', count(*) from keywords
  union all select 'thesis_keywords', count(*) from thesis_keywords
  union all select 'thesis_file', count(*) from thesis_file
  union all select 'thesis_file_index_status', count(*) from thesis_file_index_status
  order by raðir desc
", quiet = TRUE)

t_schema_sizes <- knitr::kable(
  d_schema_sizes,
  caption = "Fjöldi raða í hverri töflu í núverandi byggingu."
)

display(t_schema_sizes)
