# RQ8 -- how many master's theses lead to a government engineer's licence, and how soon.
#
# An author is matched to the licence lists (verkfræðingar, tæknifræðingar) by name and birth
# year (scripts/licences.sql). A licence counts as "after" when it is granted from 60 days before
# to 2.5 years after the thesis was accepted -- see @sec-dreifing in docs/08-verkfraedingsleyfi.qmd
# for why: 90% of positive-lag matches land within roughly 2.5 years, and that shape, not a round number, is
# what the window is drawn from.
#
# LEYFI_BUFFER (also 2.5 years) sets LEYFI_TIL, the last cohort counted as settled -- not simply
# max(licence_year) - buffer, because the lists only run to *mid* 2026: a thesis from late in
# LEYFI_TIL's year needs its full 2-year window to land inside that coverage too, so a year whose
# very last day, plus the buffer, would land after the last date on file is pushed back one more
# year. With the lists as they stand this lands on 2023, not 2024.
#
#   source("R/global.R")
#   source("R/tables/rq8-leyfi.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_licence")
require_table("v_thesis_discipline")

LEYFI_BUFFER <- 2.5
LEYFI_TIL <- leyfi_til(LEYFI_BUFFER, "select max(licence_date) from engineer_licence")
buffer_ar_label <- tala(LEYFI_BUFFER)  # for inline use, e.g. "innan `r buffer_ar_label` ára"
LEYFI_MIN_N <- 8L   # fewest theses in a cell before its median is shown

.leyfi <- "
  from v_thesis_discipline d
  left join v_thesis_licence l using (thesis_id)
"

# Share of theses whose author got a licence, by school and category.
d_rq8_hlutfall <- q(sprintf("
  select d.university as skoli, d.category as flokkur,
         count(*) as fjoldi,
         count(*) filter (where l.licensed_after) as med_leyfi
  %s where d.yr <= %d and d.category <> 'out_of_scope'
  group by all order by 1, 2", .leyfi, LEYFI_TIL), quiet = TRUE) |>
  mutate(flokkur = factor(unname(flokkaheiti[flokkur]), levels = unname(flokkaheiti)),
         hlutfall = round(100 * med_leyfi / fjoldi, 1)) |>
  arrange(skoli, flokkur) |>
  rename(Skóli = skoli, Grein = flokkur, Ritgerðir = fjoldi,
         `Höfundur með leyfi` = med_leyfi, `Hlutfall (%)` = hlutfall)

t_rq8_hlutfall <- knitr::kable(
  d_rq8_hlutfall,
  caption = sprintf("Ritgerðir þar sem höfundur fékk starfsleyfi verkfræðings eða tæknifræðings í kjölfarið, árgangar til og með %d.", LEYFI_TIL)
)

# Named scalars for inline use in prose (docs/08-verkfraedingsleyfi.qmd).
.hlutfall_verk <- \(skoli) d_rq8_hlutfall$`Hlutfall (%)`[d_rq8_hlutfall$Skóli == skoli & d_rq8_hlutfall$Grein == "Verkfræði"]
pct_hlutfall_hi <- round(.hlutfall_verk("Háskóli Íslands"))
pct_hlutfall_hr <- round(.hlutfall_verk("Háskólinn í Reykjavík"))

# Median time from thesis to licence, by umbrella discipline, engineering theses only. The row is
# the umbrella (discipline_group merges e.g. Rekstrarverkfræði and Fjármálaverkfræði into
# Iðnaðarverkfræði for cross-school comparison, R/tables/rq2-greinar.R does the same), but the
# umbrella's own name is not always what either school actually calls the line -- HR has no
# department named Iðnaðarverkfræði, its line there is Rekstrarverkfræði -- so the school's own
# niche disciplines are listed alongside it, as in rq2-greinar.
d_rq8_bid <- q(sprintf("
  select d.university as skoli, d.umbrella as grein,
         string_agg(distinct d.discipline, ', ' order by d.discipline)
           filter (where d.discipline <> d.umbrella) as undirgreinar,
         count(*) as fjoldi,
         count(*) filter (where l.licensed_after) as med_leyfi,
         median(l.lag_days) filter (where l.licensed_after) / 365.25 as midgildi,
         quantile_cont(l.lag_days, 0.25) filter (where l.licensed_after) / 365.25 as q1,
         quantile_cont(l.lag_days, 0.75) filter (where l.licensed_after) / 365.25 as q3
  %s where d.yr <= %d and d.category = 'engineering'
  group by all having count(*) >= %d
  order by 1, 3 desc", .leyfi, LEYFI_TIL, LEYFI_MIN_N), quiet = TRUE) |>
  mutate(
    skoli = recode(skoli, `Háskóli Íslands` = "HÍ", `Háskólinn í Reykjavík` = "HR"),
    hlutfall = 100 * med_leyfi / fjoldi,
    undirgreinar = coalesce(undirgreinar, "")
  )

t_rq8_bid <- d_rq8_bid |>
  transmute(Skóli = skoli, Grein = grein, Undirgreinar = undirgreinar, Ritgerðir = fjoldi,
            `Með leyfi` = med_leyfi, `Hlutfall (%)` = round(hlutfall),
            `Miðgildi (ár)` = round(midgildi, 1),
            `Fjórðungsmörk (ár)` = ifelse(is.na(q1), NA_character_,
                                          sprintf("%s – %s", tala(q1), tala(q3)))) |>
  knitr::kable(
    align = c("l", "l", "l", "r", "r", "r", "r", "r"),
    caption = sprintf(
    "Tími frá ritgerð til leyfis eftir grein (yfirgrein; undirgreinar taldar þar sem þær eru ekki sama heiti, verkfræðiritgerðir til og með %d; greinar með færri en %d ritgerðir sleppt). Miðgildi miðast við þá sem fengu leyfi.",
    LEYFI_TIL, LEYFI_MIN_N
  ))

# Which list. A licence from before the thesis is a BSc (tæknifræðingur) or an earlier degree.
d_rq8_listar <- q("
  select
    count(*) filter (where is_verkfraedingur and licensed_after and not is_taeknifraedingur) as bara_verk,
    count(*) filter (where is_verkfraedingur and is_taeknifraedingur and licensed_after)      as bada,
    count(*) filter (where is_taeknifraedingur and not is_verkfraedingur and licensed_after)  as bara_taekni,
    count(*) filter (where licensed_before)                                                   as adur,
    count(*) filter (where licensed_late)                                                     as seint
  from v_thesis_licence", quiet = TRUE)

total_licensed_after <- with(d_rq8_listar, bara_verk + bada + bara_taekni)

t_rq8_listar <- tibble::tibble(
    `Tegund samsvörunar` = c(
      "Aðeins verkfræðingsleyfi",
      "Bæði verkfræðings- og tæknifræðingsleyfi",
      "Aðeins tæknifræðingsleyfi",
      "Leyfi fyrir skiladag ritgerðar",
      "Leyfi meira en 2,5 árum eftir ritgerð"
    ),
    Ritgerðir = c(
      d_rq8_listar$bara_verk, d_rq8_listar$bada, d_rq8_listar$bara_taekni,
      d_rq8_listar$adur, d_rq8_listar$seint
    ),
    `Hlutfall (%)` = round(100 * c(
      d_rq8_listar$bara_verk, d_rq8_listar$bada, d_rq8_listar$bara_taekni,
      d_rq8_listar$adur, d_rq8_listar$seint
    ) / total_licensed_after, 1)
  ) |>
  knitr::kable(
    align = c("l", "r", "r"),
    caption = sprintf(
      "Lykiltölur um samsvörun ritgerða og starfsleyfaskráa (samtals %d ritgerðir með leyfi í kjölfar ritgerðar; flokkar geta skarast).",
      total_licensed_after
    )
  )

# The two ways in from outside the engineering departments. A tæknifræðingur licence requires its
# own tæknifræði degree -- an MPM (professional: Verkefnastjórnun/Framkvæmdastjórnun) can't be the
# qualifying degree for it, so a tæknifræðingur-only match there almost certainly reflects earlier,
# unrelated technologist training rather than the MPM itself (confirmed human-reviewed case: 44740,
# see TODO.md). A verkfræðingur match is kept, since a postgraduate MPM on top of an engineering
# undergraduate degree can genuinely qualify (confirmed case: 12943).
d_rq8_utan <- q("
  select d.university as skoli, d.category as flokkur, d.discipline as grein, count(*) as fjoldi
  from v_thesis_discipline d join v_thesis_licence l using (thesis_id)
  where l.licensed_after and d.category <> 'engineering'
    and (d.category <> 'professional' or l.is_verkfraedingur)
  group by all order by fjoldi desc, 1", quiet = TRUE) |>
  mutate(flokkur = unname(flokkaheiti[flokkur])) |>
  rename(Skóli = skoli, Flokkur = flokkur, Grein = grein, Ritgerðir = fjoldi)

t_rq8_utan <- knitr::kable(
  d_rq8_utan,
  caption = "Ritgerðir utan verkfræðiflokksins með síðara starfsleyfi."
)

# Named scalars for the "Munur á greinum" / "Verkfræðingar og tæknifræðingar" / "Sjálfbær
# orkuvísindi" prose, all for inline use in docs/08-verkfraedingsleyfi.qmd.
.grein_row <- \(sk, gr, col) d_rq8_bid[[col]][d_rq8_bid$skoli == sk & d_rq8_bid$grein == gr]
pct_bygg_hi <- round(.grein_row("HÍ", "Byggingarverkfræði", "hlutfall"))
pct_bygg_hr <- round(.grein_row("HR", "Byggingarverkfræði", "hlutfall"))
n_tolvun_hi <- .grein_row("HÍ", "Tölvunarfræði", "fjoldi")
n_tolvun_hr <- .grein_row("HR", "Tölvunarfræði", "fjoldi")
n_tolvun_hr_leyfi <- .grein_row("HR", "Tölvunarfræði", "med_leyfi")
pct_orku_hr <- round(.grein_row("HR", "Orkuverkfræði", "hlutfall"))
n_umhverfi_hr <- d_rq8_bid$fjoldi[d_rq8_bid$skoli == "HR" & d_rq8_bid$grein == "Umhverfisverkfræði"]

n_bara_verk <- d_rq8_listar$bara_verk
n_bada <- d_rq8_listar$bada
n_bara_taekni <- d_rq8_listar$bara_taekni
n_leyfi_alls <- total_licensed_after
n_adur <- d_rq8_listar$adur
n_seint <- d_rq8_listar$seint

d_rq8_adur <- q("
  select count(*) filter (where licensed_before and not licensed_after) as eingongu,
         count(*) filter (where licensed_before and is_taeknifraedingur and not is_verkfraedingur) as taeknifr_eingongu
  from v_thesis_licence", quiet = TRUE)
n_adur_eingongu <- d_rq8_adur$eingongu
n_adur_taeknifr_eingongu <- d_rq8_adur$taeknifr_eingongu

lag_dagar_39936 <- q(
  "select lag_days from v_thesis_author_licence where thesis_id = 39936", quiet = TRUE)[[1]]

n_utan_alls <- sum(d_rq8_utan$Ritgerðir)
n_utan_mpm <- sum(d_rq8_utan$Ritgerðir[d_rq8_utan$Grein %in% c("Verkefnastjórnun", "Framkvæmdastjórnun")])
n_utan_tolfraedi <- sum(d_rq8_utan$Ritgerðir[d_rq8_utan$Grein == "Tölfræði"])
stopifnot(n_utan_alls == n_utan_mpm + n_utan_tolfraedi)  # catches a new, unnamed category early
n_utan_verkefnastjornun <- sum(d_rq8_utan$Ritgerðir[d_rq8_utan$Grein == "Verkefnastjórnun"])
n_utan_framkvaemdastjornun <- sum(d_rq8_utan$Ritgerðir[d_rq8_utan$Grein == "Framkvæmdastjórnun"])
stopifnot(n_utan_mpm == n_utan_verkefnastjornun + n_utan_framkvaemdastjornun)

d_rq8_orku_hi <- q("
  select count(*) as n, count(*) filter (where l.licensed_after) as med
  from v_thesis_discipline d left join v_thesis_licence l using (thesis_id)
  where d.discipline = 'Sjálfbær orkuvísindi'", quiet = TRUE)
n_orku_hi <- d_rq8_orku_hi$n
n_orku_hi_leyfi <- d_rq8_orku_hi$med

n_engir_faedingarar <- q("
  select count(*) from v_thesis_msc m
  where not exists (
    select 1 from thesis_people tp join people p on p.id = tp.person_id
    where tp.thesis_id = m.thesis_id and tp.role = 'author' and p.year_born is not null
  )", quiet = TRUE)[[1]]

display(t_rq8_hlutfall)
display(t_rq8_bid)
display(t_rq8_listar)
