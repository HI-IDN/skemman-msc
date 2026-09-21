# Appendix -- HÍ's master's theses by department and study line, laid out like HÍ's own
# programme catalogue (config/hi_ms_programmes.yaml, supplied by a domain expert).
#
# Each facet is one deild and each bar one of its MS programmes, in the catalogue's terms: a
# discipline that is a track of a programme (Heilbrigðisverkfræði is the Læknisfræðileg
# verkfræði track of Rafmagns- og tölvuverkfræði) is counted under the programme and named in
# its label. A catalogue programme with no HÍ thesis is still drawn, with a 0. A line the
# catalogue does not list today (older or cross-cutting: Umhverfis- og auðlindafræði, Líftækni,
# Landupplýsinga- og umhverfisfræði, Orkuverkfræði) is drawn under the deild the crosswalk
# gives it and marked with an asterisk. Height is proportional to the number of bars, so a deild
# with three programmes does not get the space of one with twelve.
#
# The deildir come in the catalogue's order of interest: the three engineering ones, then the
# natural-science ones, then what is outside VoN.
#
#   source("R/global.R")
#   source("R/plots/vidauki-hi-tre.R")

if (!exists(".root")) source("R/global.R")

require_table("v_thesis_hi_programme")
require_table("hi_programme")

# Deild as the catalogue and the crosswalk name it -> the short form used everywhere else.
.short <- q("select name, short_name from org_short_name where kind = 'unit'", quiet = TRUE)
.short <- setNames(.short$short_name, .short$name)

.count <- q("
  select coalesce(programme, discipline)            as namsleid,
         coalesce(catalogue_deild, crosswalk_deild) as deild_full,
         not in_catalogue                           as utan_skrar,
         case when category = 'engineering' then 'Verkfræði'
              when category = 'science'     then 'Náttúruvísindi'
              else 'Utan VoN' end                   as grein,
         count(*)                                   as n
  from v_thesis_hi_programme
  where discipline is not null
  group by all
", quiet = TRUE)

# Track breakdown, where the data resolves one, for the label ("Rafmagnsverkfræði 26 · ...").
.tracks <- q("
  select programme as namsleid, track, count(*) as n
  from v_thesis_hi_programme
  where in_catalogue and track is not null
  group by all
", quiet = TRUE) |>
  summarise(brot = paste0(track, " ", n, collapse = " · "),
            greinar = n(), .by = namsleid) |>
  filter(greinar > 1)

.catalogue <- q("select programme as namsleid, deild as deild_full from hi_programme where track is null",
                quiet = TRUE)

d_hi_tree <- .catalogue |>
  full_join(.count, by = c("namsleid", "deild_full")) |>
  filter(!is.na(deild_full)) |>
  mutate(
    n = coalesce(n, 0L),
    utan_skrar = coalesce(utan_skrar, FALSE),
    # a catalogue programme with no HÍ thesis has no category of its own: take its deild's
    deild = coalesce(unname(.short[deild_full]), deild_full)
  ) |>
  left_join(.tracks, by = "namsleid") |>
  mutate(
    grein = coalesce(grein, "Náttúruvísindi"),
    merki = paste0(namsleid, if_else(utan_skrar, " *", ""),
                   if_else(!is.na(brot), paste0("\n", brot), ""))
  )

# A zero-thesis programme takes the colour of the rest of its deild.
.deild_grein <- d_hi_tree |>
  filter(n > 0) |>
  summarise(grein_deild = names(sort(table(grein), decreasing = TRUE))[1], .by = deild)
d_hi_tree <- d_hi_tree |>
  left_join(.deild_grein, by = "deild") |>
  mutate(grein = if_else(n == 0, coalesce(grein_deild, grein), grein))

if (!nrow(d_hi_tree)) {
  stop("v_thesis_hi_programme holds no HÍ master's theses.", call. = FALSE)
}

.order <- c("IVT", "UmBygg", "RT", "Raun", "Líf", "Jarð", "Matv", "(óflokkað)")
hi_tree_order <- unique(c(.order[.order %in% d_hi_tree$deild], sort(setdiff(d_hi_tree$deild, .order))))

p_hi_tree <- d_hi_tree |>
  mutate(
    merki = forcats::fct_reorder(merki, n),
    deild = factor(deild, levels = hi_tree_order)
  ) |>
  ggplot(aes(n, merki, fill = grein, alpha = utan_skrar)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = n), hjust = -0.25, size = 3, colour = "grey30", alpha = 1) +
  facet_grid(deild ~ ., scales = "free_y", space = "free_y", switch = "y") +
  scale_fill_manual(values = c(field_colors, "Utan VoN" = "grey60")) +
  scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = 0.55), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = NULL, y = NULL, fill = NULL,
       caption = "* lína sem er ekki í núverandi námsskrá HÍ") +
  theme(
    strip.placement = "outside",
    strip.text.y.left = element_text(angle = 0, face = "bold", hjust = 1),
    panel.grid.major.y = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks = element_blank()
  )

display(p_hi_tree)
