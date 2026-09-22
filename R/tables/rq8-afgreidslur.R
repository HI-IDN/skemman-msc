# RQ8 -- cadence and batch size on the licence lists.
# A shared licence_date is observable; whether it represents a committee meeting is not.
#
#   source("R/global.R")
#   source("R/tables/rq8-afgreidslur.R")

if (!exists(".root")) source("R/global.R")
require_table("v_licence_person")

d_rq8_afgreidslur <- q("
  with batches as (
    select licence_date,
           case
             when year(licence_date) < 1990 then 'Fyrir 1990'
             when year(licence_date) < 2010 then '1990–2009'
             when year(licence_date) < 2018 then '2010–2017'
             else '2018–2025'
           end as timabil,
           count(*) as fjoldi
    from v_licence_person
    where licence_date is not null and year(licence_date) <= 2025
    group by all
  )
  select timabil,
         min(licence_date) as fra,
         max(licence_date) as til,
         sum(fjoldi) as leyfi,
         count(*) as dagar,
         avg(fjoldi) as medaltal,
         median(fjoldi) as midgildi,
         avg((fjoldi = 1)::integer) as hlutfall_eitt,
         quantile_cont(fjoldi, 0.25) as q1,
         quantile_cont(fjoldi, 0.75) as q3,
         max(fjoldi) as haesta
  from batches
  group by timabil
  order by fra", quiet = TRUE) |>
  mutate(
    ar = as.integer(format(til, "%Y")) - as.integer(format(fra, "%Y")) + 1L,
    dagar_a_ari = dagar / ar
  )

t_rq8_afgreidslur <- d_rq8_afgreidslur |>
  transmute(
    Tímabil = timabil,
    Leyfi = leyfi,
    Afgreiðsludagar = dagar,
    `Dagar á ári` = round(dagar_a_ari, 1),
    `Leyfi á dag, miðgildi` = round(midgildi, 1),
    `Fjórðungsmörk` = sprintf("%.0f–%.0f", q1, q3),
    `Hæsta lota` = haesta
  ) |>
  knitr::kable(
    align = c("l", "r", "r", "r", "r", "r", "r"),
    caption = paste(
      "Fjöldi leyfa með sömu dagsetningu.",
      "Dagsetningin sýnir afgreiðslulotu en ekki endilega fund nefndar."
    )
  ) |>
  kableExtra::row_spec(
    which(d_rq8_afgreidslur$timabil %in% c("2010–2017", "2018–2025")),
    background = "#eeedff"
  )

.all_batches <- q("
  select licence_date, count(*) as fjoldi
  from v_licence_person
  where licence_date is not null
  group by licence_date", quiet = TRUE)

afgreidsludagar_allir <- nrow(.all_batches)
leyfi_dag_medaltal <- round(mean(.all_batches$fjoldi), 1)
leyfi_dag_midgildi <- median(.all_batches$fjoldi)
pct_eitt_leyfi <- round(100 * mean(.all_batches$fjoldi == 1), 1)
pct_tvo_eda_faerri <- round(100 * mean(.all_batches$fjoldi <= 2), 1)

.new <- filter(d_rq8_afgreidslur, timabil == "2018–2025")
.old <- filter(d_rq8_afgreidslur, timabil == "2010–2017")
.early <- filter(d_rq8_afgreidslur, timabil == "Fyrir 1990")
fyrri_eins_manns_lotur <- round(100 * .early$hlutfall_eitt, 1)
nyrri_eins_manns_lotur <- round(100 * .new$hlutfall_eitt, 1)
eldri_dagar_a_ari <- round(.old$dagar_a_ari, 1)
eldri_lota_midgildi <- .old$midgildi
nyir_dagar_a_ari <- round(.new$dagar_a_ari, 1)
ny_lota_midgildi <- .new$midgildi
ny_lota_q1 <- .new$q1
ny_lota_q3 <- .new$q3

d_rq8_afgreidslur_dagur <- q("
  with by_list as (
    select licence_date as dagur, list, count(*) as fjoldi
    from v_licence_person
    where licence_date is not null
    group by all
  ), total as (
    select dagur, 'alls' as list, sum(fjoldi) as fjoldi
    from by_list
    group by dagur
  )
  select * from by_list
  union all
  select * from total
  order by dagur, list", quiet = TRUE) |>
  mutate(
    list = recode(
      list,
      verkfraedingur = "Verkfræðingar",
      taeknifraedingur = "Tæknifræðingar",
      alls = "Alls"
    ),
    list = factor(list, levels = c("Alls", "Verkfræðingar", "Tæknifræðingar"))
  )

.y2025 <- filter(
  d_rq8_afgreidslur_dagur,
  list == "Alls", format(dagur, "%Y") == "2025"
)
n_leyfi_2025 <- sum(.y2025$fjoldi)
n_dagar_2025 <- nrow(.y2025)

.gaps <- q("
  with dates as (
    select distinct licence_date as dagur
    from v_licence_person
    where licence_date is not null and year(licence_date) <= 2025
  ), gaps as (
    select dagur, date_diff('day', lag(dagur) over (order by dagur), dagur) as bil
    from dates
  )
  select case when year(dagur) < 2018 then '2010–2017' else '2018–2025' end as timabil,
         median(bil) as midgildi
  from gaps
  where year(dagur) between 2010 and 2025
  group by all", quiet = TRUE)

eldra_bil_midgildi <- .gaps$midgildi[.gaps$timabil == "2010–2017"]
nyrra_bil_midgildi <- .gaps$midgildi[.gaps$timabil == "2018–2025"]

p_rq8_afgreidslur <- d_rq8_afgreidslur_dagur |>
  filter(
    list == "Alls",
    between(as.integer(format(dagur, "%Y")), YEAR_FROM, 2025)
  ) |>
  ggplot(aes(dagur, fjoldi)) +
  geom_col(width = 18, fill = "#10099F", alpha = 0.8) +
  geom_point(colour = "#10099F", size = 1.5) +
  scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(x = NULL, y = "Leyfi með sömu dagsetningu")

.nineties_gap <- q("
  select list,
         count(*) filter (where licence_year = 1991) as n_1991,
         count(*) filter (where licence_year between 1992 and 1993) as n_1992_93,
         count(*) filter (where licence_year = 1994) as n_1994
  from v_licence_person
  group by list", quiet = TRUE)

n_verk_1991 <- .nineties_gap$n_1991[.nineties_gap$list == "verkfraedingur"]
n_verk_1992_93 <- .nineties_gap$n_1992_93[.nineties_gap$list == "verkfraedingur"]
n_verk_1994 <- .nineties_gap$n_1994[.nineties_gap$list == "verkfraedingur"]
n_taekni_1991 <- .nineties_gap$n_1991[.nineties_gap$list == "taeknifraedingur"]
n_taekni_1992_93 <- .nineties_gap$n_1992_93[.nineties_gap$list == "taeknifraedingur"]
n_taekni_1994 <- .nineties_gap$n_1994[.nineties_gap$list == "taeknifraedingur"]

display(t_rq8_afgreidslur)
display(p_rq8_afgreidslur)
