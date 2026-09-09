#' RQ4 -- how often a sponsor is recorded at all.
#'
#' This measures coverage of the `sponsor` field, and that is all it can
#' measure. The fall at HÍ from 2010 is a change in cataloguing practice, not a
#' collapse in industry collaboration -- the collaboration that is never written
#' down is invisible here by construction.
rq4_sponsor <- function() {
  masters() |>
    group_by(yr, uni) |>
    summarise(hlutfall = mean(!is.na(sponsor)), .groups = "drop") |>
    ggplot(aes(yr, hlutfall, colour = uni)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_colour_manual(values = hi_colors) +
    scale_y_continuous(labels = percent, limits = c(0, NA)) +
    scale_x_continuous(breaks = seq(2010, 2026, 2)) +
    labs(x = NULL, y = "Með skráðan styrktaraðila", colour = NULL)
}

register_figure("rq4_sponsor", "RQ4 — hlutfall með skráðan styrktaraðila")
