# RQ8 -- the licence lists as their own population, apart from any thesis: how many people are
# licensed, on which list, at what age, and whether there is a gender gap.
#
# Gender is read off the Icelandic patronymic/matronymic surname ending (v_licence_person,
# scripts/licences.sql): a naming convention assigned at birth, not a record of anyone's present
# gender identity, and it is left unknown for a name it cannot read (a family name, a foreign
# name) rather than guessed.
#
#   source("R/global.R")
#   source("R/tables/rq8-leyfishafar.R")

if (!exists(".root")) source("R/global.R")
require_table("v_licence_person")

.listaheiti <- c(verkfraedingur = "Verkfræðingur", taeknifraedingur = "Tæknifræðingur")

d_rq8_fjoldi_kyn <- q("
  select list, kyn, count(*) as fjoldi
  from v_licence_person
  group by all", quiet = TRUE) |>
  mutate(kyn = coalesce(kyn, "oþekkt")) |>
  tidyr::pivot_wider(names_from = kyn, values_from = fjoldi, values_fill = 0) |>
  mutate(list = unname(.listaheiti[list]),
         Alls = kk + kvk + oþekkt,
         `Hlutfall kvenna (%)` = round(100 * kvk / (kk + kvk), 1)) |>
  rename(Listi = list, Karlar = kk, Konur = kvk, `óþekkt kyn` = oþekkt) |>
  select(Listi, Alls, Karlar, Konur, `óþekkt kyn`, `Hlutfall kvenna (%)`)

t_rq8_fjoldi_kyn <- knitr::kable(
  d_rq8_fjoldi_kyn,
  caption = "Fjöldi á starfsleyfaskránum frá upphafi (1962/1965 til vors 2026), eftir kyni."
)

# Named scalars for inline use in prose (docs/08-verkfraedingsleyfi.qmd), so numbers there are
# read out of the data, not retyped by hand each time the pipeline reruns.
n_kyn_uppl  <- sum(d_rq8_fjoldi_kyn$Alls)
n_kyn_thekkt <- sum(d_rq8_fjoldi_kyn$Karlar) + sum(d_rq8_fjoldi_kyn$Konur)
n_kyn_okunn <- sum(d_rq8_fjoldi_kyn$`óþekkt kyn`)
pct_kyn_okunn <- round(100 * n_kyn_okunn / n_kyn_uppl, 1)
pct_kvk_verk <- d_rq8_fjoldi_kyn$`Hlutfall kvenna (%)`[d_rq8_fjoldi_kyn$Listi == "Verkfræðingur"]
pct_kvk_taekni <- d_rq8_fjoldi_kyn$`Hlutfall kvenna (%)`[d_rq8_fjoldi_kyn$Listi == "Tæknifræðingur"]
kvk_hlutfall_margfeldi <- round(pct_kvk_verk / pct_kvk_taekni, 1)

.fyrsta_kvk <- q("
  select list, min(licence_year) as ar
  from v_licence_person where kyn = 'kvk' group by all", quiet = TRUE) |>
  mutate(list = unname(.listaheiti[list]))
ar_fyrsta_kvk_verk <- .fyrsta_kvk$ar[.fyrsta_kvk$list == "Verkfræðingur"]
ar_fyrsta_kvk_taekni <- .fyrsta_kvk$ar[.fyrsta_kvk$list == "Tæknifræðingur"]

.fyrsta_ar <- q("
  select list, min(licence_year) as ar
  from v_licence_person group by all", quiet = TRUE) |>
  mutate(list = unname(.listaheiti[list]))
ar_fyrsta_verk <- .fyrsta_ar$ar[.fyrsta_ar$list == "Verkfræðingur"]
ar_fyrsta_taekni <- .fyrsta_ar$ar[.fyrsta_ar$list == "Tæknifræðingur"]

d_rq8_aldur <- q("
  select list,
         count(*) as n,
         median(aldur) as midgildi,
         avg(aldur) as medaltal,
         quantile_cont(aldur, 0.25) as q1,
         quantile_cont(aldur, 0.75) as q3
  from v_licence_person
  where aldur between 15 and 85
  group by all", quiet = TRUE) |>
  mutate(list = unname(.listaheiti[list])) |>
  transmute(Listi = list, N = n, Miðgildi = round(midgildi, 1), Meðaltal = round(medaltal, 1),
            Fjórðungsmörk = sprintf("%.0f – %.0f", q1, q3))

t_rq8_aldur <- knitr::kable(
  d_rq8_aldur,
  caption = "Aldur við útgáfu starfsleyfis (leyfisár − fæðingarár; nákvæmni því ± um eitt ár)."
)

midgildi_aldur_verk <- d_rq8_aldur$Miðgildi[d_rq8_aldur$Listi == "Verkfræðingur"]
midgildi_aldur_taekni <- d_rq8_aldur$Miðgildi[d_rq8_aldur$Listi == "Tæknifræðingur"]

display(t_rq8_fjoldi_kyn)
display(t_rq8_aldur)
