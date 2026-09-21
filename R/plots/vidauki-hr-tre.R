# Appendix -- HR's master's theses by department and study line.
#
# HR has no grein layer the way HÍ does: study_category already names the
# department directly (v_thesis_unit's case-when), so this tree has just two
# levels, deild and námsleið. Colour carries category instead, since HR's
# deildir mix engineering with MPM, íþróttafræði and iðnfræði.
#
#   source("R/global.R")
#   source("R/plots/vidauki-hr-tre.R")

if (!exists(".root")) source("R/global.R")

require_table("v_thesis_unit_named")

d_hr_tree <- q("
  select unit_short  as deild,
         discipline  as namsleid,
         category    as flokkur,
         count(*)    as n
  from v_thesis_unit_named
  where university_short = 'HR'
    and discipline is not null
  group by 1, 2, 3
", quiet = TRUE)

if (!nrow(d_hr_tree)) {
  stop("v_thesis_unit_named holds no classified HR master's theses.", call. = FALSE)
}

d_hr_tree <- d_hr_tree |>
  mutate(flokkur = coalesce(unname(flokkaheiti[flokkur]), flokkur))

hr_tree_order <- d_hr_tree |>
  summarise(alls = sum(n), .by = deild) |>
  arrange(desc(alls))

p_hr_tree <- d_hr_tree |>
  mutate(
    namsleid = forcats::fct_reorder(namsleid, n),
    deild = factor(deild, levels = hr_tree_order$deild)
  ) |>
  ggplot(aes(n, namsleid, fill = flokkur)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = n), hjust = -0.25, size = 3, colour = "grey30") +
  facet_grid(deild ~ ., scales = "free_y", space = "free_y", switch = "y") +
  scale_fill_manual(values = flokkur_colors) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = NULL, y = NULL, fill = NULL) +
  theme(
    strip.placement = "outside",
    strip.text.y.left = element_text(angle = 0, face = "bold", hjust = 1),
    panel.grid.major.y = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks = element_blank()
  )

display(p_hr_tree)
