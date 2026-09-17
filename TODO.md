# TODO

Things found during automated work that need a domain expert's judgment, not another
lookup-table entry. Move an item to "Resolved" with the decision once it's settled, or
delete it once it's also reflected wherever it needs to be (a commit, a GitHub issue
comment, this file's own history in git is the record).

## Open

None currently. All 2,484 theses in the population have a discipline (see issue #5).

## Ideas, not yet built

- **Advisor-based discipline inference for closed/unclassifiable theses.** An advisor's
  most common discipline across their *other* supervised theses could suggest one for a
  thesis with no keyword match and no fetchable title page. Needs care: a thesis can have
  advisors from different departments, so this is a plurality/majority signal, not a
  certain one -- likely a human-reviewed suggestion, not another automated tier in
  `v_thesis_discipline`. Not needed for any case seen so far -- the closed theses found
  (4446) were resolved by other means -- but worth building if more turn up.
- **Follow-up research question: how often do advisors supervise within vs. across
  their own faculty?** Falls out of the idea above almost for free once advisor identity
  and home department are both resolved. Worth its own issue if pursued -- not scoped as
  part of #5.

## Resolved

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
