# TODO

Things found during automated work that need a domain expert's judgment, not another
lookup-table entry. Move an item to "Resolved" with the decision once it's settled, or
delete it once it's also reflected wherever it needs to be (a commit, a GitHub issue
comment, this file's own history in git is the record).

## Open -- needs your verification

Nothing is waiting on you right now. (Two HR theses, 50850 and 50913, take their advisor's field,
Orkuverkfræði, by design: silicon/ferrosilicon materials-process work, but neither school has a
chemical-engineering programme. Add a `discipline_override` if you ever learn their programme.)

## In progress / ideas (no action needed from you yet)

- **Advisor home departments -- built, first results in.** `scripts/advisor_units.sql` (rebuild
  step `advisors`, runs only when `data/processed/hi_staff_units.csv` and `hr_staff_units.csv`
  exist) gives `v_advisor_unit`, `v_advisor_unit_coverage`, `v_thesis_advisor_unit` and an
  `advisor_identity` alias table (same non-null birth year, same first/last name, compatible
  middle names -- 16 aliases, e.g. Guðrún A. / Guðrún Arnbjörg Sævarsdóttir). Coverage: 63% of
  supervisions at both schools, but only 161 of 700 advisors, all current or former staff; result:
  96% (HR) and 90% (HÍ) of engineering theses with a known advisor department are advised from
  engineering/computer science (`R/tables/rq2-leidbeinendur.R`, docs/02). To do: coverage of the
  many departed / adjunct / foreign advisors (HÍ former-staff page, other sources); the
  within-versus-across-faculty question can now be asked properly. The staff scrapers resume by
  name now (person ids change when `people` is rebuilt).
- **Licensed-engineer analysis.** `scripts/fetch_engineer_licences.py` ->
  `data/processed/engineer_licences.csv` (gitignored; name, birth year, licence date only --
  never the kennitala). Preliminary (engineering authors, verkfræðingur list): 49% matched
  (HÍ 60%, HR 41%, a lower bound), median 4.2 months from thesis to licence. Caveats: recent
  cohorts censored, 2026 snapshot, name + birth year matching, and a licence proves *an*
  engineering degree exists, not that this thesis was it (39936: earlier Milan MSc; 12943: MPM
  by an existing engineer). To do: proper script/view, table for the RQ chapter, the
  tæknifræðingar list for applied theses. Engineers who did not come through an engineering deild:
  under 1% of ~613 matches, but our population holds only in-scope theses.
- **HÍ programme catalogue** is in `config/hi_ms_programmes.yaml` (supplied by a domain
  expert); nothing reads it yet -- use it to decide umbrellas and fill `discipline_unit`.
- **Research question:** how often do advisors supervise within vs. across their own faculty?

## Resolved

- **`people`/`thesis_people` were empty after a rebuild** -- nothing in the pipeline created them
  (`metadata-load` does theses and keywords, `clean-people` only tidies). New `skemman people-load`
  (harvester) reads `dc.contributor.author` / `dc.description.advisor` from the cached xoai pages
  and is the `people` step of `rebuild.sh` (data phase, after `metadata`); it fills empty tables
  only, idempotently, and covers every thesis harvested (9,472 people, 18,142 links). It agrees
  with the old Parquet snapshot on 17,609 of 18,108 links, adds the 12 newer theses, finds birth
  years the snapshot lacked, and fixes 46 mangled names in it (`lfar` for Úlfar, `Gudni`). The
  snapshot loader (`scripts/load_people.sql`) stays as a fallback when the xoai pages are not on
  disk. The `disciplines` step warns if no advisors are on file. Optional: re-export the snapshot
  with `scripts/export_db.sql` so `data/db/` carries the corrected names.

- **The last generic HR theses** -- settled one by one with human input; see the comments in
  `scripts/discipline_map.sql` for each: 44748, 46301, 50794, 50803, 50871, 50875, 50907, 50928,
  50984, 50986, 51060, 42324 and 50796 are overrides; 50850 and 50913 take the advisor's field.
  Final tally: 1,718 by title page, 746 by keyword, 18 by override, 2 by advisor; none generic.
  `discipline_override` is now cleared and refilled from the script on every run.

- **Matvæla- og næringarfræðideild (2 HÍ theses: 20573, 33474)** -- belongs to Heilbrigðisvísindasvið,
  not VoN; treated as mis-filed and out of scope (`out_of_scope`, like Menntavísindadeild).
  (Before HÍ's 2008 restructuring the deild may have been organised differently; irrelevant here.)
- **Umbrellas** -- Skipulagsfræði og samgöngur -> Umhverfisverkfræði (HÍ track "Sjálfbær byggð og
  öruggar samgöngur"). Orkuverkfræði stays ungrouped; its 6 HÍ theses stay in IVT.

- **Sustainable Energy Science (42 HR theses)** -- interdisciplinary (human call): science by
  default, engineering when the author applies for the engineer title. Today 0 of 31 authors
  with a known birth year are licensed, so all are science (`Sjálfbær orkuvísindi`); marked with
  `discipline_keyword.flag = 'interdisciplinary'` and `v_thesis_discipline.is_interdisciplinary`
  so the licence rule can be applied per thesis once the licence list is joined in.

- **Human confirmations (this round)** -- 39936 stays Tölfræði/science (author's licence rests
  on an earlier Politecnico di Milano MSc, unrelated to the MAS: MAS does not lead to the
  title); 49125 is Umhverfisverkfræði/engineering (title page: "M.S. ritgerð í
  Umhverfisverkfræði", Umhverfis- og byggingarverkfræðideild -- unambiguous, only flagged
  because the keyword pass disagreed; parser fix reads it); 44748, 50728, 50737, 50739
  Fjármálaverkfræði (clear keywords); 50796 Heilbrigðisverkfræði; 50798 Mechatronic
  Engineering; 50792 Electric Power Engineering (niche, merge under an umbrella later);
  18738 and the 6 other Landupplýsinga- og umhverfisfræði theses: department is
  Líf- og umhverfisvísindadeild (Faculty of Life and Environmental Sciences), same faculty
  as the advisor's tourism studies.

- **12943 (HR 2012, MPM)** -- stays `Verkefnastjórnun`/professional: title page says "Ritgerð til
  meistaraprófs (MPM)", a pure Master of Project Management. Note: the author (b. 1978) *is*
  on the verkfræðingur list (licence 20.09.12, same year as the thesis), contrary to a first
  check by hand -- most likely licensed on an earlier engineering education, so the licence
  does not make this thesis an engineering degree. Same pattern as the 9 other MPM authors
  whose licence predates the thesis; confirms that "licensed" alone must not promote a
  thesis (the 0-3-years-after rule would wrongly catch this one).

- **Engineering Physics (Verkfræðileg eðlisfræði), 4 HÍ theses: 27933, 24952, 42878, 29517**
  -- an engineering degree hosted by Raunvísindadeild (27933's author is a licensed
  verkfræðingur, licence 06.07.18). New discipline `Verkfræðileg eðlisfræði`, category
  `engineering`, unit Raunvísindadeild, `in_core`; was `Eðlisfræði`/science. Keywords
  `verkfræðileg eðlisfræði` and `engineering physics` remapped.

- **Advisor-suggestion views verified against real data.** They now also target theses with
  only a generic discipline, and feed the advisor tier of `v_thesis_discipline`.

- **Framkvæmdastjórnun (HR, 15 theses)** — engineering, not professional (human call, from
  10906: an 85-page MSc thesis, the engineering counterpart of the professional
  programmes, industrial-engineering related or closely adjacent). Category changed in
  `discipline_keyword`; they now land in HR's `Verkfræðideild` (was `Annað`), `in_core`.
  HÍ's `discipline_unit` already had it under UmBygg. Also made `v_thesis_unit.in_core`
  null-safe for theses with no HR `study_category`. `Annað` now holds only 31238.
  Doc prose still says 16 in `Annað` (`docs/02-rq2-disciplines.qmd`) and describes
  `Construction Management` as `professional` (`docs/vidauki-adferd.qmd`) -- update when
  rebuilding the docs.
- **53766** — override to Rekstrarverkfræði/engineering: MSc in engineering management,
  keyword order let Verkefnastjórnun win. Not yet on the licence list (accepted 2026-06-12).
- **23908** — override to Byggingarverkfræði/engineering via the advisor suggestion.
- **5597, 7548, 8904, 8914, 13221, 13257, 18530, 39991 and 21 more HR theses** — the generic
  title page ("MSc in engineering") now yields to a specific keyword, and generic keywords
  rank last (`v_thesis_discipline`, `v_thesis_discipline_candidate`). 13257 confirmed
  Umhverfisverkfræði against the licence list. 50888 stays Máltækni (engineering).

- **31238** — new `out_of_scope` category (alongside engineering/professional/applied/
  science): title page (MSc in Marketing) matches its keywords, but per human review the
  HR `study_category` breadcrumb ("MSc Tölvunarfræðideild") is itself an incorrect
  submission. `Markaðsfræði` mapped as a keyword, not a one-off override, since any other
  thesis carrying it is presumably the same kind of mis-filed record.
- **Menntavísindadeild theses (8)** — moved from `science` to the new `out_of_scope`
  category: a different school (Menntavísindasvið) entirely, not a natural science.
- **21992, 21584, 28347, 28285, 18738, 18739, 33203** — the "Geo-information Science and
  Earth Observation..." programme cluster: was a title-page parser bug (line-wrap + a
  60-character cap that still truncated the joined result), not a data issue. Fixed in
  skemman-harvester `f30c962`; four spelling variants mapped once the parser read them
  whole.
- **31878** — `Energy Systems` (IVT) was correctly read off the title page already;
  just missing from the crosswalk. Added, maps to Orkuverkfræði.
- **41556** — title page uses "Magister Scientiarum gráðu í X" rather than
  "meistaraprófs ... í X" -- a third Icelandic degree-statement form the parser didn't
  recognize. Fixed in skemman-harvester `2fd6b10` (anchored on "Magister ... gráðu", not
  bare "gráðu í X", which is ordinary prose about someone else's degree -- see 42047 in
  the same fix's test suite).
- **47700** — keyword `Verkefnastjórar` (plural, "project managers") was a variant of
  `Verkefnastjórnun` missing from the crosswalk. Added.
- **47224** — keyword `Líftölfræði` (biostatistics) was missing from the crosswalk.
  Added, maps to Tölfræði.
- **31876** — keyword `Náttúrulandfræði` (physical geography) was missing from the
  crosswalk, not a case needing advisor inference: added, maps to Landfræði.
- **33203** *(candidate-false-negative sweep, resolved earlier)* — none outstanding.
- **38678** — Menntavísindadeild confirmed correct: námsbraut is Menntun
  framhaldsskólakennara (School of Education), kjörsvið tölvunarfræði; IVT is only the
  kjörsvið's supervising department, not the degree's home faculty.
- **24869** — one-off override to Orkuverkfræði/engineering: title-page subject was
  truncated ("Innovative and Sustainable") by a line-wrap bug, human-confirmed full
  degree is Innovative and Sustainable Energy Engineering, Faculty of Industrial
  Engineering, Mechanical Engineering and Computer Science.
- **36353** — override to Verkefnastjórnun/professional: title-page subject
  "computer science" was a confirmed parser bug (pulled from an interviewee's biography,
  not the title page).
- **4446** — override to Fjármálaverkfræði/engineering: PDF access is `Lokaður`
  (closed), so no title page was ever fetchable; keywords (Fjármál, Stjórnun, Bestun)
  are all topical, none name the study line. Human-confirmed from outside the automated
  signals entirely.
- **Umhverfis- og auðlindafræði cluster (10 theses)** — confirmed as science, not
  engineering, even where the title page names an engineering faculty (Civil/Mechanical/
  Industrial Engineering): genuinely cross-disciplinary, housed under SENS/VoN, but not
  an engineering degree itself.
- **Íþróttavísindi / HR "Tækni- og verkfræðideild" (6 theses)** — not a signal; a
  pre-2019 shared HR collection, unrelated to the discipline.

Full investigation trail for all of the above: [issue #5](https://github.com/HI-IDN/skemman-msc/issues/5).
