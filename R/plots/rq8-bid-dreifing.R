# RQ8 -- the empirical distribution of lag (thesis -> licence), and why the window in
# scripts/licences.sql is drawn where it is.
#
# The vertical lines are empirical quantiles, not values from a fitted probability distribution.
# Include the -60-day grace period in the plotted distribution. A slightly negative lag may reflect
# date_accepted metadata, a later upload or revision in Skemman, rather than the actual completion
# date. More distant negative lags are shown separately in rq8-fyrri-leyfi.R.
#
#   source("R/global.R")
#   source("R/plots/rq8-bid-dreifing.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_author_licence")

d_rq8_lag <- q("select lag_days from v_thesis_author_licence", quiet = TRUE)

.negative <- q("
  select
    count(*) filter (where a.lag_days < 0) as alls,
    count(*) filter (where a.lag_days between -60 and -1) as innan_grace,
    count(*) filter (where a.lag_days < -60) as eldra_leyfi,
    count(*) filter (
      where a.lag_days < -60 and d.discipline = 'Verkefnastjórnun'
    ) as eldra_leyfi_mpm,
    count(distinct a.thesis_id) filter (
      where a.lag_days < -60 and d.discipline = 'Verkefnastjórnun'
    ) as eldri_mpm_ritgerdir,
    count(distinct a.thesis_id) filter (
      where a.lag_days < -60 and d.discipline = 'Verkefnastjórnun' and a.tier = 3
    ) as veikar_mpm_ritgerdir
  from v_thesis_author_licence a
  join v_thesis_discipline d using (thesis_id)", quiet = TRUE)

n_negative <- .negative$alls
n_negative_grace <- .negative$innan_grace
n_prior_licence <- .negative$eldra_leyfi
n_prior_licence_mpm <- .negative$eldra_leyfi_mpm
n_prior_mpm_theses <- .negative$eldri_mpm_ritgerdir
n_prior_mpm_weak <- .negative$veikar_mpm_ritgerdir

.pos <- d_rq8_lag$lag_days[d_rq8_lag$lag_days > 0] / 365.25
.plot_lag <- d_rq8_lag$lag_days[d_rq8_lag$lag_days > 0] / 365.25
.probs <- c(0.50, 0.80, 0.90, 0.95)
.quantiles <- tibble(
  prob = .probs,
  ar = as.numeric(quantile(.pos, probs = .probs, names = FALSE)),
  merki = sprintf("%d%%: %s ár", round(100 * prob), tala(ar))
)

n_positive_lag <- length(.pos)
pct_innan_2 <- round(100 * mean(.pos <= 2))
pct_innan_4 <- round(100 * mean(.pos <= 4))
q90_days <- as.integer(quantile(
  d_rq8_lag$lag_days[d_rq8_lag$lag_days > 0],
  probs = 0.90,
  names = FALSE
))
.max_licence_date <- q("select max(licence_date) as dagur from v_licence_person", quiet = TRUE)$dagur
q90_cutoff_date <- .max_licence_date - q90_days
q90_cutoff_label <- format_is_date(q90_cutoff_date)
max_licence_date_label <- format_is_date(.max_licence_date)
q50_years <- round(.quantiles$ar[.quantiles$prob == 0.50], 1)
q80_years <- round(.quantiles$ar[.quantiles$prob == 0.80], 1)
q90_years <- round(.quantiles$ar[.quantiles$prob == 0.90], 1)
q95_years <- round(.quantiles$ar[.quantiles$prob == 0.95], 1)

p_rq8_bid_dreifing <- ggplot(tibble(lag = .plot_lag), aes(lag)) +
  geom_histogram(
    binwidth = 0.25, boundary = 0,
    fill = "#10099F", alpha = 0.65, colour = "white"
  ) +
  geom_vline(
    data = .quantiles,
    aes(xintercept = ar, linetype = merki),
    colour = "#d61f69",
    linewidth = 0.8
  ) +
  coord_cartesian(xlim = c(0, ceiling(max(.quantiles$ar)))) +
  scale_linetype_manual(values = c("dashed", "dotdash", "longdash", "dotted")) +
  labs(
    x = "Ár frá ritgerð til leyfis",
    y = "Fjöldi",
    linetype = "Hlutfall komið með leyfi"
  )

display(p_rq8_bid_dreifing)
