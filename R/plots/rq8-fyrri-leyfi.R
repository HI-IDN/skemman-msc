# RQ8 -- licences that predate the matched thesis by more than the 60-day grace period, EXCLUDING
# a thesis that also has an "after" match: that is the ordinary tæknifræðingur-before /
# verkfræðingur-after progression of the same degree (already counted as "bæði" in
# R/tables/rq8-leyfi.R), not a separate earlier credential. What is left here is genuinely a
# different, earlier licence with no later match for this same thesis -- someone already
# credentialled, later writing an unrelated thesis (human-confirmed cases: 23749, licensed
# verkfræðingur in 1988, this thesis from 2016; 49145, licensed on an earlier, unrelated degree
# mid-way through an unrelated MSc that finished later).
#
#   source("R/global.R")
#   source("R/plots/rq8-fyrri-leyfi.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_author_licence")
require_table("v_thesis_discipline")

d_rq8_fyrri_leyfi <- q("
  select -a.lag_days / 365.25 as ar_adur,
         case when d.discipline in ('Verkefnastjórnun', 'Framkvæmdastjórnun') then 'MPM'
              when d.category = 'engineering'                                 then 'Verkfræðiritgerð'
              else 'Aðrar ritgerðir' end as hopur
  from v_thesis_author_licence a
  join v_thesis_discipline d using (thesis_id)
  where a.lag_days < -60
    and not exists (
      select 1 from v_thesis_author_licence a2
      where a2.thesis_id = a.thesis_id and a2.rel = 'after'
    )", quiet = TRUE) |>
  mutate(hopur = factor(
    hopur,
    levels = c("Verkfræðiritgerð", "MPM", "Aðrar ritgerðir")
  ))

p_rq8_fyrri_leyfi <- ggplot(d_rq8_fyrri_leyfi, aes(ar_adur, fill = hopur)) +
  geom_histogram(binwidth = 1, boundary = 0, position = "stack", colour = "white", alpha = 0.8) +
  scale_fill_manual(values = c(
    `Verkfræðiritgerð` = "#d61f69",
    `MPM` = "#FAC55B",
    `Aðrar ritgerðir` = "grey55"
  )) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.03))) +
  labs(
    x = "Ár frá leyfisveitingu að síðari, ótengdri ritgerð",
    y = "Fjöldi samsvarana",
    fill = NULL
  )

# Named scalars for inline use in prose (docs/08-verkfraedingsleyfi.qmd).
n_fyrri_leyfi_alls <- nrow(d_rq8_fyrri_leyfi)
n_fyrri_leyfi_verk <- sum(d_rq8_fyrri_leyfi$hopur == "Verkfræðiritgerð")
n_fyrri_leyfi_mpm <- sum(d_rq8_fyrri_leyfi$hopur == "MPM")
n_fyrri_leyfi_annad <- sum(d_rq8_fyrri_leyfi$hopur == "Aðrar ritgerðir")

display(p_rq8_fyrri_leyfi)
