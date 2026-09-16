# Appendix -- keyword-based discipline against what the title page itself states.
#
# thesis_titlepage.subject (see issue #5) is the ground truth: what the thesis's
# own title page says the degree is in, read off the PDF rather than tagged by the
# submitter. Where both signals exist, this checks how often they agree, and lists
# every disagreement so it is clear whether they differ on the category
# (engineering vs. not) or only on which sibling discipline within it.
#
#   source("R/global.R")
#   source("R/tables/vidauki-titilsida.R")

if (!exists(".root")) source("R/global.R")

require_table("v_rq2_discipline_agreement")

d_vidauki_titilsida_yfirlit <- q("
  select count(*)                                        as \"Bæði til\",
         sum(case when agrees then 1 else 0 end)          as \"Samhljóða\",
         sum(case when not agrees then 1 else 0 end)       as \"Ósamhljóða\",
         sum(case when not agrees and keyword_category <> titlepage_category
                   then 1 else 0 end)                      as \"þar af flokkaskipti\"
  from v_rq2_discipline_agreement
", quiet = TRUE)

t_vidauki_titilsida_yfirlit <- knitr::kable(
  d_vidauki_titilsida_yfirlit,
  caption = "Samræmi leitarorða- og titilsíðuflokkunar, þar sem hvort tveggja er til."
)

display(t_vidauki_titilsida_yfirlit)

d_vidauki_titilsida_osamraemi <- q("
  select university                as \"Skóli\",
         keyword_discipline         as \"Leitarorð\",
         titlepage_discipline       as \"Titilsíða\",
         case when keyword_category <> titlepage_category
              then keyword_category || ' → ' || titlepage_category
              else '(sama)' end     as \"Flokkur\",
         count(*)                  as \"Fjöldi\"
  from v_rq2_discipline_agreement
  where not agrees
  group by 1, 2, 3, 4
  order by \"Flokkur\" <> '(sama)' desc, \"Fjöldi\" desc
", quiet = TRUE)

t_vidauki_titilsida_osamraemi <- knitr::kable(
  d_vidauki_titilsida_osamraemi,
  caption = "Hvar leitarorð og titilsíða greinir á, og hvort það breytir flokki."
)

display(t_vidauki_titilsida_osamraemi)
