# RQ9 -- co-supervision network for engineering MSc theses.

if (!exists(".root")) source("R/global.R")
require_table("v_thesis_msc")

if (!requireNamespace("network", quietly = TRUE) || !requireNamespace("ggnetwork", quietly = TRUE)) {
  p_rq9_leidbeinenda_net <- ggplot() +
    annotate("text", x = 0, y = 0, label = "Tengslanetið bíður uppsetningar á network og ggnetwork.") +
    theme_void()
  display(p_rq9_leidbeinenda_net)
} else {

edges <- q("
  with theses as (
    select distinct tp.thesis_id, tp.person_id
    from thesis_people tp
    join v_thesis_msc m using (thesis_id)
    join v_thesis_discipline d using (thesis_id)
    where tp.role = 'advisor' and d.category = 'engineering'
  )
  select a.person_id as from_id, b.person_id as to_id,
         count(*) as weight
  from theses a join theses b
    on a.thesis_id = b.thesis_id and a.person_id < b.person_id
  group by all", quiet = TRUE)

if (nrow(edges) == 0) {
  p_rq9_leidbeinenda_net <- ggplot() +
    labs(title = "Engar sameiginlegar leiðbeiningar fundust") +
    theme_void()
} else {
  ids <- sort(unique(c(edges$from_id, edges$to_id)))
  net <- network::network(as.matrix(edges[, c("from_id", "to_id")]),
                          directed = FALSE, matrix.type = "edgelist", loops = FALSE,
                          multiple = TRUE)
  network::set.vertex.attribute(net, "label", as.character(ids))
  network::set.vertex.attribute(net, "color", rep("#777777", length(ids)))
  network::set.edge.attribute(net, "weight", edges$weight)
  p_rq9_leidbeinenda_net <- ggplot(ggnetwork::ggnetwork(net, layout = "fruchtermanreingold")) +
    geom_edges(aes(linewidth = weight), alpha = 0.35, colour = "grey55") +
    geom_nodes(aes(size = degree), colour = "#10099F") +
    scale_linewidth_continuous(range = c(0.3, 2)) +
    scale_size_continuous(range = c(2, 8)) +
    theme_void() +
    labs(size = "Sameiginlegar ritgerðir", linewidth = "Sameiginlegar ritgerðir")
}

display(p_rq9_leidbeinenda_net)
}
