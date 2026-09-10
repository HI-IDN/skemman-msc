# Appendix -- HÍ's master's theses by department and study line.
#
# Each facet is one department, and its height is proportional to how many
# study lines it holds, so a department with three lines does not get the same
# vertical space as one with twelve.
#
# Engineering departments come first, then each group by size. A department
# counts as engineering when most of its theses are, which is a judgment the
# data cannot make for `(óflokkað)` -- it holds theses of both kinds.
#
#   source("R/global.R")
#   source("R/plots/vidauki-hi-tre.R")

if (!exists(".root")) source("R/global.R")

require_table("v_thesis_unit_named")

d_hi_tree <- q("
  select case when category = 'engineering' then 'Verkfræði' else 'Náttúruvísindi' end as grein,
         unit_short  as deild,
         discipline  as namsleid,
         count(*)    as n
  from v_thesis_unit_named
  where university_short = 'HÍ'
    and discipline is not null
  group by 1, 2, 3
", quiet = TRUE)

if (!nrow(d_hi_tree)) {
  stop("v_thesis_unit_named holds no classified HÍ master's theses.", call. = FALSE)
}

hi_tree_order <- d_hi_tree |>
  summarise(
    alls = sum(n),
    verk = sum(n[grein == "Verkfræði"]) > sum(n[grein != "Verkfræði"]),
    .by = deild
  ) |>
  arrange(desc(verk), desc(alls))

p_hi_tree <- d_hi_tree |>
  mutate(
    namsleid = forcats::fct_reorder(namsleid, n),
    deild = factor(deild, levels = hi_tree_order$deild)
  ) |>
  ggplot(aes(n, namsleid, fill = grein)) +
  geom_col(width = 0.72) +
  geom_text(aes(label = n), hjust = -0.25, size = 3, colour = "grey30") +
  facet_grid(deild ~ ., scales = "free_y", space = "free_y", switch = "y") +
  scale_fill_manual(values = field_colors) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = NULL, y = NULL, fill = NULL) +
  theme(
    strip.placement = "outside",
    strip.text.y.left = element_text(angle = 0, face = "bold", hjust = 1),
    panel.grid.major.y = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks = element_blank()
  )

display(p_hi_tree)
