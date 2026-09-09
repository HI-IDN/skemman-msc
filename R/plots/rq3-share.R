#' RQ3 -- each school's share of the year's total.
#'
#' The counts are in rq1_volume(); this asks the other question, which of the
#' two is producing more of what gets produced. A share can rise while the count
#' falls, and on this data it does.
rq3_share <- function() {
  masters_by_year() |>
    group_by(yr) |>
    mutate(hlutfall = n / sum(n)) |>
    ungroup() |>
    ggplot(aes(yr, hlutfall, fill = uni)) +
    geom_area(alpha = 0.85) +
    scale_fill_manual(values = hi_colors) +
    scale_y_continuous(labels = percent) +
    scale_x_continuous(breaks = seq(2010, 2026, 2)) +
    labs(x = NULL, y = NULL, fill = NULL)
}

register_figure("rq3_share", "RQ3 — hlutdeild skólanna í ritgerðum ársins")
