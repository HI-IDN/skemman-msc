# RQ9 -- co-supervision network for engineering MSc theses.
#
# Advisors are nodes; two advisors are joined when they supervised the same thesis, and the
# line is as wide as the number of theses they share. A dashed line joins an examiner to the
# advisors of a thesis they examined (see below). Only advisors with at least one line
# appear: a sole supervisor who was never an examiner has nothing to draw.
#
# Each advisor is coloured once, by the strongest evidence of where they work:
#   1. the HÍ and HR staff lists (v_advisor_unit) -- HÍ, HR, or both;
#   2. an outside employer on a title page or in the acknowledgements
#      (v_thesis_advisor_affiliation, #11) -- "Utan háskóla";
#   3. a university named in their title-page block: HÍ, HR, or another university;
#   4. otherwise "Óvíst".
# The staff lists are today's, not the thesis year's, so an advisor who moved between the
# schools, or from industry into a university, shows where they are now.
#
#   source("R/global.R")
#   source("R/plots/rq9-leidbeinenda-net.R")

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_msc")

has_table <- function(name) {
  q(sprintf("select count(*) as n from information_schema.tables where table_name = '%s'",
            name), quiet = TRUE)$n > 0
}

rq9_flokkar <- c(
  "HÍ"            = unname(hi_colors["Háskóli Íslands"]),
  "HR"            = unname(hi_colors["Háskólinn í Reykjavík"]),
  "Báðir skólar"  = "#7A3FA0",
  "Annar háskóli" = "#2DD2C0",
  "Utan háskóla"  = "#FFA05F",
  "Óvíst"         = "#BBBBBB"
)

if (!requireNamespace("network", quietly = TRUE) ||
    !requireNamespace("ggnetwork", quietly = TRUE) ||
    !requireNamespace("sna", quietly = TRUE)) {
  p_rq9_leidbeinenda_net <- ggplot() +
    annotate("text", x = 0, y = 0,
             label = "Tengslanetið bíður uppsetningar á network, sna og ggnetwork.") +
    theme_void()
} else {

  advising <- q("
    select distinct tp.thesis_id, tp.person_id
    from thesis_people tp
    join v_thesis_msc m using (thesis_id)
    join v_thesis_discipline d using (thesis_id)
    where tp.role = 'advisor' and d.category = 'engineering'", quiet = TRUE)

  edges <- advising |>
    inner_join(advising, by = "thesis_id", suffix = c("_a", "_b"),
               relationship = "many-to-many") |>
    filter(person_id_a < person_id_b) |>
    count(person_id_a, person_id_b, name = "weight") |>
    mutate(tegund = "Meðleiðbeining")

  # --- examiners: a dashed line to each advisor of the thesis they examined --------------
  # An examiner is impartial, not a partner, but examining someone's student means the two
  # know each other. Examiners are only on the title page (thesis_titlepage.examiner), for a
  # minority of theses -- issue #2 is about reading them from the rest -- and are not in
  # `people`, so the name is matched to an advisor: the full name with accents folded, or
  # first and last name when only one advisor has that pair. Examiners who never advised are
  # not drawn; `rq9_examiners` keeps the counts for the caption.
  norm_name <- function(x) {
    x <- sub("^([^,]*),\\s*(.*)$", "\\2 \\1", x)  # "Winrow, Patrick Karl"
    x <- iconv(x, "UTF-8", "ASCII//TRANSLIT")
    gsub("\\s+", " ", trimws(tolower(gsub("[^A-Za-z ]", "", x))))
  }
  first_last <- function(x) sub("^(\\S+).* (\\S+)$", "\\1 \\2", x)

  examined <- q("
    select t.thesis_id, t.examiner
    from thesis_titlepage t
    join v_thesis_msc m using (thesis_id)
    join v_thesis_discipline d using (thesis_id)
    where d.category = 'engineering' and t.examiner is not null", quiet = TRUE) |>
    mutate(
      # "Dr. Rúnar Unnþórsson, prófdómari; Lektor, Háskóli Íslands; ..." -> the name alone.
      name = sub(",.*$", "", sub(";.*$", "", examiner)),
      name = trimws(gsub("^(Dr|MSc|M\\.Sc|PhD|Prof)\\.?\\s+", "", name)),
      full = norm_name(name)
    )
  people_adv <- q("
    select distinct p.id as person_id, p.name
    from thesis_people tp join people p on p.id = tp.person_id
    where tp.role = 'advisor'", quiet = TRUE) |>
    mutate(full = norm_name(name), fl = first_last(full))
  unique_fl <- people_adv |> count(fl) |> filter(n == 1) |> pull(fl)
  examined <- examined |>
    left_join(select(people_adv, full, pid_full = person_id) |> distinct(full, .keep_all = TRUE),
              by = "full") |>
    mutate(fl = first_last(full)) |>
    left_join(filter(people_adv, fl %in% unique_fl) |> select(fl, pid_fl = person_id),
              by = "fl") |>
    mutate(examiner_id = coalesce(pid_full, pid_fl))

  exam_edges <- examined |>
    filter(!is.na(examiner_id)) |>
    inner_join(advising, by = "thesis_id", relationship = "many-to-many") |>
    filter(person_id != examiner_id) |>
    transmute(person_id_a = pmin(person_id, examiner_id),
              person_id_b = pmax(person_id, examiner_id)) |>
    count(person_id_a, person_id_b, name = "weight") |>
    mutate(tegund = "Prófdómari")

  rq9_examiners <- list(
    theses = n_distinct(examined$thesis_id),
    matched = sum(!is.na(examined$examiner_id)),
    lines = nrow(exam_edges)
  )
  edges <- bind_rows(edges, exam_edges)

  # --- where each advisor works ---------------------------------------------------------
  staff <- if (has_table("v_advisor_unit")) {
    q("select person_id,
              case when count(distinct page_school) > 1 then 'Báðir skólar'
                   else any_value(page_school) end as staff_flokkur
       from v_advisor_unit group by person_id", quiet = TRUE)
  } else {
    tibble(person_id = integer(), staff_flokkur = character())
  }
  affiliation <- if (has_table("v_thesis_advisor_affiliation")) {
    q("select person_id,
              bool_or(kind = 'outside') as outside,
              bool_or(kind = 'academic' and sector = 'university') as other_uni,
              bool_or(kind = 'academic' and regexp_matches(coalesce(titlepage_block, ''),
                '(?i)reykjav[ií]k university|university of reykjav|háskól\\w* í reykjavík')) as hr,
              bool_or(kind = 'academic' and regexp_matches(coalesce(titlepage_block, ''),
                '(?i)university of iceland|háskól\\w* íslands')) as hi
       from v_thesis_advisor_affiliation group by person_id", quiet = TRUE)
  } else {
    tibble(person_id = integer(), outside = logical(), other_uni = logical(),
           hr = logical(), hi = logical())
  }

  nodes <- tibble(person_id = sort(unique(c(edges$person_id_a, edges$person_id_b)))) |>
    left_join(count(advising, person_id, name = "ritgerdir"), by = "person_id") |>
    mutate(ritgerdir = coalesce(ritgerdir, 0L)) |>
    left_join(staff, by = "person_id") |>
    left_join(affiliation, by = "person_id") |>
    mutate(
      flokkur = case_when(
        !is.na(staff_flokkur)          ~ staff_flokkur,
        coalesce(outside, FALSE)       ~ "Utan háskóla",
        coalesce(hi, FALSE) & coalesce(hr, FALSE) ~ "Báðir skólar",
        coalesce(hi, FALSE)            ~ "HÍ",
        coalesce(hr, FALSE)            ~ "HR",
        coalesce(other_uni, FALSE)     ~ "Annar háskóli",
        TRUE                           ~ "Óvíst"
      ),
      flokkur = factor(flokkur, levels = names(rq9_flokkar)),
      # network() wants vertices numbered 1..n, not database ids.
      vid = row_number()
    )

  el <- edges |>
    left_join(select(nodes, person_id_a = person_id, from = vid), by = "person_id_a") |>
    left_join(select(nodes, person_id_b = person_id, to = vid), by = "person_id_b")

  net <- network::network.initialize(nrow(nodes), directed = FALSE)
  network::add.edges(net, tail = el$from, head = el$to)
  network::set.edge.attribute(net, "weight", el$weight)
  network::set.edge.attribute(net, "tegund", el$tegund)
  network::set.vertex.attribute(net, "flokkur", as.character(nodes$flokkur))
  network::set.vertex.attribute(net, "ritgerdir", nodes$ritgerdir)

  set.seed(20260922)  # the layout is random; fix it so the figure is the same every render
  # Two advisors who co-supervised and also examined each other's students have two lines,
  # one of each kind. ggnetwork warns about "duplicated edges"; here they are the point.
  d_rq9_net <- withCallingHandlers(
    ggnetwork::ggnetwork(net, layout = "fruchtermanreingold"),
    warning = function(w) {
      if (grepl("duplicated edges", conditionMessage(w))) invokeRestart("muffleWarning")
    }
  ) |>
    mutate(flokkur = factor(flokkur, levels = names(rq9_flokkar)))

  p_rq9_leidbeinenda_net <- ggplot(d_rq9_net, aes(x = x, y = y, xend = xend, yend = yend)) +
    ggnetwork::geom_edges(aes(linewidth = weight, linetype = tegund),
                          data = function(d) filter(d, tegund == "Meðleiðbeining"),
                          alpha = 0.3, colour = "grey55") +
    # Examiner lines on top and darker: there are far fewer of them.
    ggnetwork::geom_edges(aes(linewidth = weight, linetype = tegund),
                          data = function(d) filter(d, tegund == "Prófdómari"),
                          alpha = 0.7, colour = "grey20") +
    ggnetwork::geom_nodes(aes(size = ritgerdir, colour = flokkur), alpha = 0.85) +
    scale_colour_manual(values = rq9_flokkar) +
    scale_linetype_manual(values = c("Meðleiðbeining" = "solid", "Prófdómari" = "22")) +
    scale_linewidth_continuous(range = c(0.2, 1.8), guide = "none") +
    scale_size_continuous(range = c(1, 7)) +
    theme_void() +
    theme(legend.position = "bottom", legend.box = "vertical") +
    labs(colour = NULL, linetype = NULL, size = "Ritgerðir sem leiðbeinandi")
}

display(p_rq9_leidbeinenda_net)
