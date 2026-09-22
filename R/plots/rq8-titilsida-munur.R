# RQ8 -- month difference where both the title page and Skemman's metadata give a month.

if (!exists(".root")) source("R/global.R")
require_table("thesis_titlepage")

d_rq8_titilsida_munur <- q("
  select date_diff(
           'month',
           make_date(t.year_on_page, coalesce(t.month_on_page, 1), 1),
           m.date_accepted
         ) as manada_bil
  from thesis_titlepage t
  join v_thesis_msc m using (thesis_id)
  where t.year_on_page is not null
    and t.month_on_page is not null", quiet = TRUE)

p_rq8_titilsida_munur <- ggplot(d_rq8_titilsida_munur, aes(manada_bil)) +
  geom_histogram(binwidth = 1, boundary = 0, fill = "#10099F", colour = "white", alpha = 0.8) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "#d61f69") +
  scale_x_continuous(expand = expansion(mult = c(0.01, 0.03))) +
  labs(
    x = "date_accepted − titilsíðudagsetning (mánuðir)",
    y = "Fjöldi ritgerða"
  )

display(p_rq8_titilsida_munur)
