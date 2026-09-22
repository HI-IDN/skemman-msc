# RQ8 -- verkfræðingar and tæknifræðingar, running total by (apparent) gender, kk/kvk/óþekkt.
# Verkfræðingar on top, tæknifræðingar below, so the two are readable on their own scale rather
# than one dwarfing the other. Gender: v_licence_person -- a surname-ending proxy, not a record
# of gender identity (R/tables/rq8-leyfishafar.R explains it).
#
#   source("R/global.R")
#   source("R/plots/rq8-uppsafnad-kyn.R")

if (!exists(".root")) source("R/global.R")
require_table("v_licence_person")

d_rq8_uppsafnad_kyn <- q("
  select licence_year as ar, list, coalesce(kyn, 'oþekkt') as kyn, count(*) as fjoldi
  from v_licence_person
  group by all", quiet = TRUE) |>
  mutate(list = recode(list, verkfraedingur = "Verkfræðingar", taeknifraedingur = "Tæknifræðingar"),
         list = factor(list, levels = c("Verkfræðingar", "Tæknifræðingar")),
         kyn = recode(kyn, kk = "Karlar", kvk = "Konur", oþekkt = "óþekkt kyn"),
         kyn = factor(kyn, levels = c("Karlar", "Konur", "óþekkt kyn"))) |>
  arrange(list, kyn, ar) |>
  mutate(uppsafnad = cumsum(fjoldi), .by = c(list, kyn))

# Inline values used immediately after this figure in the chapter. They live here because this
# chunk is evaluated before that prose; the summary table below is evaluated afterwards.
ar_fyrsta_verk <- min(d_rq8_uppsafnad_kyn$ar[d_rq8_uppsafnad_kyn$list == "Verkfræðingar"])
ar_fyrsta_taekni <- min(d_rq8_uppsafnad_kyn$ar[d_rq8_uppsafnad_kyn$list == "Tæknifræðingar"])
ar_fyrsta_kvk_verk <- min(d_rq8_uppsafnad_kyn$ar[
  d_rq8_uppsafnad_kyn$list == "Verkfræðingar" & d_rq8_uppsafnad_kyn$kyn == "Konur"
])
ar_fyrsta_kvk_taekni <- min(d_rq8_uppsafnad_kyn$ar[
  d_rq8_uppsafnad_kyn$list == "Tæknifræðingar" & d_rq8_uppsafnad_kyn$kyn == "Konur"
])

p_rq8_uppsafnad_kyn <- ggplot(d_rq8_uppsafnad_kyn, aes(ar, uppsafnad, colour = kyn)) +
  geom_line(linewidth = 0.9) +
  facet_wrap(~ list, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c(Karlar = "#10099F", Konur = "#d61f69", `óþekkt kyn` = "grey60")) +
  scale_x_continuous(breaks = seq(1960, 2025, 10)) +
  labs(x = NULL, y = "Uppsafnað", colour = NULL) +
  guides(colour = guide_legend(position = "bottom")) +
  theme(
    strip.text = element_text(face = "bold", hjust = 0),
    strip.background = element_rect(fill = "#eeedff", colour = NA)
  )

display(p_rq8_uppsafnad_kyn)
