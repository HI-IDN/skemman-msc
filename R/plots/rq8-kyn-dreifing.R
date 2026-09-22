# RQ8 -- how the gender composition of each licence list changes over time.
#
# Licence years are historical counts, not a sample from a stationary bell-shaped
# distribution. Show the directly observed quantity instead: women's annual share among
# records whose gender can be inferred. The pale band is not a confidence interval; it is
# the full sensitivity range obtained by assigning every unknown record to men (lower bound)
# or women (upper bound).
#
#   source("R/global.R")
#   source("R/plots/rq8-kyn-dreifing.R")

if (!exists(".root")) source("R/global.R")
require_table("v_licence_person")

.list_labels <- c(
  verkfraedingur = "Verkfræðingar",
  taeknifraedingur = "Tæknifræðingar"
)

d_rq8_kyn_ar <- q("
  select licence_year as ar, list,
         count(*) filter (where kyn = 'kvk') as konur,
         count(*) filter (where kyn = 'kk') as karlar,
         count(*) filter (where kyn is null) as othekkt
  from v_licence_person
  group by all
  order by list, licence_year", quiet = TRUE) |>
  mutate(
    list = unname(.list_labels[list]),
    list = factor(list, levels = unname(.list_labels)),
    thekkt = konur + karlar,
    alls = thekkt + othekkt,
    hlutfall = if_else(thekkt > 0, konur / thekkt, NA_real_),
    nedri_mork = konur / alls,
    efri_mork = (konur + othekkt) / alls
  )

# Compare the study period with the full historical list. The last year is partial, so use the
# last complete year from analysis_period rather than the live list's current maximum.
recent_to <- max(d_rq8_kyn_ar$ar) - 1L
recent_from <- YEAR_FROM
recent_label <- sprintf("%d–%d", recent_from, recent_to)
recent_table_label <- sprintf("Rannsóknartímabil Skemmu (%s)", recent_label)

.summarise_period <- function(data, period) {
  data |>
    summarise(
      konur = sum(konur), karlar = sum(karlar), othekkt = sum(othekkt),
      .by = list
    ) |>
    mutate(
      timabil = period,
      thekkt = konur + karlar,
      alls = thekkt + othekkt,
      hlutfall = konur / thekkt,
      nedri_mork = konur / alls,
      efri_mork = (konur + othekkt) / alls
    )
}

d_rq8_kyn_timabil <- bind_rows(
  .summarise_period(d_rq8_kyn_ar, "Allt tímabilið"),
  .summarise_period(
    filter(d_rq8_kyn_ar, between(ar, recent_from, recent_to)),
    recent_table_label
  )
) |>
  mutate(timabil = factor(timabil, levels = c("Allt tímabilið", recent_table_label)))

.table_rq8_kyn_dreifing <- d_rq8_kyn_timabil |>
  transmute(
    Skrá = list,
    Tímabil = timabil,
    Konur = konur,
    Karlar = karlar,
    `Óþekkt kyn` = othekkt,
    `Konur af þekktu kyni` = percent(hlutfall, accuracy = 0.1, decimal.mark = ","),
    `Mögulegt bil` = sprintf("%s–%s", percent(nedri_mork, accuracy = 0.1, decimal.mark = ","),
                             percent(efri_mork, accuracy = 0.1, decimal.mark = ","))
  ) |>
  arrange(Skrá, Tímabil)

t_rq8_kyn_dreifing <- .table_rq8_kyn_dreifing |>
  knitr::kable(
    align = c("l", "l", "r", "r", "r", "r", "r"),
    caption = paste(
      "Kynjasamsetning starfsleyfaskránna alls og á rannsóknartímabili Skemmu.",
      "Mögulegt bil setur öll óþekkt til skiptis með körlum og konum."
    )
  ) |>
  kableExtra::row_spec(
    which(.table_rq8_kyn_dreifing$Tímabil == recent_table_label),
    background = "#eeedff"
  )

.period_value <- function(list_name, period, column = "hlutfall") {
  row <- d_rq8_kyn_timabil$list == list_name & d_rq8_kyn_timabil$timabil == period
  d_rq8_kyn_timabil[[column]][row]
}

pct_recent_verk <- round(100 * .period_value("Verkfræðingar", recent_table_label), 1)
pct_recent_taekni <- round(100 * .period_value("Tæknifræðingar", recent_table_label), 1)
recent_verk_lower <- round(100 * .period_value("Verkfræðingar", recent_table_label, "nedri_mork"), 1)
recent_verk_upper <- round(100 * .period_value("Verkfræðingar", recent_table_label, "efri_mork"), 1)

p_rq8_kyn_dreifing <- ggplot(
  filter(d_rq8_kyn_ar, ar >= 1965, ar <= recent_to),
  aes(ar, hlutfall)
) +
  geom_ribbon(aes(ymin = nedri_mork, ymax = efri_mork), fill = "grey75", alpha = 0.55) +
  geom_line(colour = "#d61f69", linewidth = 0.55, alpha = 0.75) +
  geom_point(aes(size = thekkt), colour = "#d61f69", alpha = 0.8) +
  facet_wrap(vars(list), ncol = 1) +
  scale_x_continuous(breaks = seq(1970, recent_to, 10)) +
  scale_y_continuous(
    labels = percent_format(accuracy = 1),
    expand = expansion(mult = c(0, 0.05))
  ) +
  scale_size_area(max_size = 5, breaks = c(25, 50, 100, 150)) +
  labs(
    x = NULL,
    y = "Hlutfall kvenna af þekktu kyni",
    size = "Þekkt kyn"
  ) +
  theme(
    strip.text = element_text(face = "bold", hjust = 0),
    strip.background = element_rect(fill = "#eeedff", colour = NA)
  )

display(t_rq8_kyn_dreifing)
display(p_rq8_kyn_dreifing)
