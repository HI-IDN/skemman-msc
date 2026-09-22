# TODO

Things found during automated work that need a domain expert's judgment, not another
lookup-table entry. Move an item to "Resolved" with the decision once it's settled, or
delete it once it's also reflected wherever it needs to be (a commit, a GitHub issue
comment, this file's own history in git is the record).

## Open -- needs your verification

- **One remaining tier-3 licence match whose title page does not supply the licence holder's
  middle name: Skemman id 18392.** First name, last name
  and birth year match, but the title page still leaves no middle-name evidence to confirm or
  contradict the licence identity. Review externally before treating individually as certain.

- **One remaining Verkefnastjórnun thesis with a licence afterwards, skemman id 44740** (HR,
  professional; two authors). The match is specifically **Jón Steinar Guðlaugsson** (born 1986),
  not co-author Magnús Árni Gunnarsson (born 1981). Jón's identity match is solid: full name,
  birth year, tier 1; he received a **tæknifræðingur** licence 11.07.2023, 71 days after the
  recorded thesis date. Because this is a technologist rather than engineer title, the likely
  explanation is earlier qualifying technologist education, not that the MPM supplied the
  qualification. Verify Jón's earlier education before treating the timing as causal.
  (33545 was also in this list until the
  three-tier matching below caught it as a different name collision -- see Resolved.)

(Two HR theses, 50850 and 50913, take their advisor's field, Orkuverkfræði, by design:
silicon/ferrosilicon materials-process work, but neither school has a chemical-engineering
programme. Add a `discipline_override` if you ever learn their programme.)

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
- **Licensed-engineer analysis -- built, chapter 8.** `scripts/load_licences.sql` (rebuild step
  `licences`, before `disciplines`) loads `data/processed/engineer_licences.csv` (gitignored; name,
  birth year, licence date only -- never the kennitala) into `engineer_licence`; `scripts/licences.sql`
  matches theses' authors by name + birth year (`v_thesis_author_licence`, `v_thesis_licence`; rel =
  before / after within 6 years / late) and separately builds `v_licence_person`, the licence lists as
  their own population (kyn, aldur). `v_thesis_discipline.licence_promoted` promotes an interdisciplinary
  science thesis to engineering when its author is licensed afterwards -- fires on 0 of 42 Sjálfbær
  orkuvísindi theses today. Chapter `docs/08-verkfraedingsleyfi.qmd`, `references.bib` (lög nr. 8/1996,
  reglur nr. 1105/2015, the two stjórnarráð lists, with access dates), `R/tables/rq8-leyfi.R`,
  `R/tables/rq8-leyfishafar.R`, `R/plots/rq8-*.R` (four plotly-interactive charts in a "Skrárnar
  sjálfar" tabset: new/year, cumulative, cumulative by kyn including óþekkt kyn).
  LEYFI_TIL is now a 4-year buffer from the data's own max licence_year (currently 2022, not 2020):
  96% of matches land within 4 years of the thesis, so a 6-year wait to call a cohort "settled" was
  overcautious. Headline (to 2022): 61% (HÍ) / 49% (HR) of engineering theses end in a licence, median
  ~0.5 years; a quarter of all verkfræðingar are women (24.5%) vs. 4.9% of tæknifræðingar, and no woman
  is on either list before ~1969/mid-1970s. To do: the 2018 HR dip (14 of 52) is unexplained; a short
  note on the batch-granting pattern (~4.7 people/date, roughly monthly, September busiest, August
  quietest) was investigated but not added to the chapter -- ask if wanted; whether to pursue a
  Mannanafnaskrá first-name gender lookup was raised but no public API or bulk dataset was found (the
  island.is search looks client-rendered; would need a headless-browser scrape of ~650 names, not
  attempted).
  Data-quality fixes made along the way (all in `scripts/fetch_engineer_licences.py` /
  `scripts/load_licences.sql`): 320 "hefur ekki sótt leyfi" (listed, never actually licensed) entries
  were being counted as licensed -- dropped at fetch time; one entry leaked a kennitala into `raw_date`
  -- scrubbed at fetch time and again defensively at load time; 3 people were printed twice on the
  source page (date spelled out vs. numeric) -- deduplicated at load time; the kk/kvk surname-ending
  read (`v_licence_person.kyn`, scripts/licences.sql) now matches `-son`/`-dóttir` on *any* name token,
  not just the last, so a patronymic followed by an inherited family name (Rúnarsson Fjeldsted) still
  resolves. `tmp.out` (gitignored) lists the 653 people the surname rule still can't place, for manual
  spot-checking. Explicitly NOT done: hardcoding a fix for a single confirmed source typo
  (`Rúnarssonm`) -- tried it (first inline, then as an override table modelled on
  `discipline_override`), then reverted both: the source is hand-typed and will always have more
  typos, and patching them one at a time in the codebase is not sustainable. A Mannanafnaskrá
  first-name lookup (see below) would fix this kind of case for free, without hardcoding anyone's
  name.
  Matching is now three tiers, not two (`v_thesis_author_licence.how`/`tier`, and
  `v_thesis_licence.match_confidence`, the weakest tier behind any of a thesis's matches -- both
  added on request): **1. full name** (exact); **2. compatible middle name** -- first, last and
  birth year match, and the middle names are compatible (one an initial/prefix of the other, same
  rule as `advisor_identity` in `scripts/advisor_units.sql`), e.g. "Tómas P." for "Tómas Philip" --
  real positive evidence, not just an absence of conflict; **3. first and last name** -- first,
  last and birth year match but at least one side has no middle name at all, so there is nothing to
  confirm or contradict. A licence row belongs to its single best-tier match across the WHOLE
  population, not just within one thesis, so a weak match to thesis A is dropped even when a strong
  match to unrelated thesis B claims the same licence row.
  This caught two real name collisions where a tier-3-only match landed on the wrong person:
  **18555** ("Helgi Guðjónsson", Líffræði/HÍ) actually belongs to 28751's "Helgi Þór Guðjónsson" (HR
  engineering, exact match), both born 1987. **33545** ("Elín Guðný Gunnarsdóttir", Verkefnastjórnun/HR)
  shares a first name, last name and birth year (1983) with a licensed "Elín Birna Gunnarsdóttir" --
  different middle names, incompatible (neither prefixes the other), so tier 2 does not apply either;
  correctly excluded entirely now, not just down-ranked. Together these dropped the "outside
  engineering with a licence afterwards" count from 5 to 3 (docs/08-verkfraedingsleyfi.qmd).
- **Distribution work (resolved).** No fitted normal or lognormal distribution is used. Licence
  years are shown as empirical counts and cumulative shares, and the lag plot uses empirical
  quantiles only. The historical female and male series are not treated as stationary bell-shaped
  populations; recent female counts are still affected by the truncated final years.
- **`date_accepted` can differ from Skemman's own "Samþykkt" date -- systemic, not a one-off.**
  97,7% of the whole population's `date_accepted` (2,427 of 2,484 theses) falls on the 1st of a
  month: OAI's `dc.date` is essentially never day-precise, so this is the norm, not the exception.
  Three human-confirmed cases so far, all in the same direction (our `date_accepted` earlier than
  the true Samþykkt date, sometimes by months): **12943** (134-day gap; true lag to the licence is
  8 days, not the 142 `lag_days` showed). **23679** (Skemman: Samþykkt 4.2.2016; our date_accepted
  ~2015-09-01) -- this one is a genuine sign flip: at 55 days our system called it "after" the
  thesis, but the true gap (verkfræðingur licence 26.10.15, before the real Samþykkt) is -101
  days, "before". **49145** (LinkedIn-confirmed programme ran to Jan 2025; Skemman Samþykkt
  3.2.2025) -- direction doesn't flip here (already "before"), but magnitude does: -243 real days,
  not the -210 `lag_days` showed. Classification (before/after/late) is *usually* robust to this,
  but 23679 shows it is not always -- how often a flip like that happens across the population is
  unknown. Properly fixing this means scraping the real Samþykkt date from every Skemman item page
  (~2,500 pages) -- a real project, not started, raised with the user but not yet decided. Noted in
  the chapter now with the 97,7% figure, not just the single-case framing (`docs/08-verkfraedingsleyfi.qmd`,
  @sec-dreifing and Takmarkanir).
- **MPM and the engineer's title -- confirmed exception, 12943.** Author of this MPM (Verkefnastjórnun,
  HR) thesis received the verkfræðingur title 8 days after the thesis was accepted per Skemman's own
  date (see above), and has no other Skemman entry that could explain it independently (unlike 39936's
  Politecnico di Milano case). Whether the MPM itself was accepted as sufficient, or the author had
  unlisted prior training, can't be determined from this data -- flagged in the chapter as a
  confirmed one-off, not generalised.
- **Framkvæmdastjórnun reclassified engineering -> professional.** Reverses an earlier call (made
  from a single 85-page thesis, 10906, judged "the engineering counterpart of the professional
  programmes" on length alone). Framkvæmdastjórnun is the Icelandic term for MPM (human-confirmed);
  same category as Verkefnastjórnun now, `scripts/discipline_map.sql`. Consequences fixed alongside
  it: removed from the engineering-only `discipline_group` umbrella table; added to the HR "MPM"
  unit-label/in_core exclusion logic next to Verkefnastjórnun; a new outside-engineering-with-a-
  licence case appeared (14234) once the category changed, caught by a `stopifnot` guard added to
  `R/tables/rq8-leyfi.R`'s scalar block specifically so a future reclassification like this can't
  silently go unmentioned in the chapter prose again.
- **"Fyrri leyfi" (prior-licence) plot was double-counting -- fixed.** `R/plots/rq8-fyrri-leyfi.R`
  used to count every licence-before-thesis row with lag < -60 days as if it were a separate earlier
  credential (reported as "71 verkfræðiritgerð"). Investigated on request (why would an already-
  licensed engineer write ANOTHER engineering thesis?): 49 of those 71 were `taeknifraedingur`-before
  rows belonging to a thesis that ALSO has a later `verkfraedingur`-after match for the same
  thesis -- the ordinary tæknifræðingur-then-verkfræðingur progression of one degree, already counted
  as "bæði" (`R/tables/rq8-leyfi.R`), not a second, unrelated credential. The plot now excludes any
  thesis with a same-thesis "after" match, and buckets what remains by Verkfræðiritgerð / MPM
  (Verkefnastjórnun + Framkvæmdastjórnun, now the same category) / other. Left after the fix: 52
  genuine cases (17 verkfræði, 35 MPM), human-confirmed with two examples -- 23749 (Fjármálaverkfræði
  1988 licence, thesis from 2016, 28-year gap, "obviously a second thesis") and 49145 (Orkuverkfræði,
  LinkedIn-confirmed the programme ran independently of the licence date).
- **Mannanafnaskrá (Þjóðskrá's given-name registry) -- built and wired in.** A persisted GraphQL
  query behind island.is/leit-i-mannanafnaskra, reachable with a plain HTTP GET (no browser needed):
  `GET https://island.is/api/graphql?operationName=GetIcelandicNameBySearch&variables={"input":{"q":"<name>"}}&extensions={"persistedQuery":{"version":1,"sha256Hash":"9ad0fe7dfad99b8acf592ad0ed4c9052d431e3a10fce79979d113c3b22f5bd73"}}`,
  with headers `apollo-require-preflight: true`, `content-type: application/json`,
  `apollographql-client-name: cms-web-client`, `apollographql-client-version: 0.1`, a normal
  `User-Agent` and `Referer: https://island.is/leit-i-mannanafnaskra`. Response entries:
  `{"id":...,"icelandicName":"...","type":"DR"|"RDR"|"ST"|"RST"|"MI"|..., "status":"Sam"|"Haf", ...}`
  -- `DR`/`RDR` = drengjanafn (boy), `ST`/`RST` = stúlknanafn (girl). A single-letter query returns
  thousands of rows (substring match), so the whole registry (5,859 entries) is one pass of ~36
  queries (Icelandic alphabet) deduped by `id`.
  Built **portable**, as asked: the client (`search()`, `fetch_all()`, `gender_of()`) lives in a
  standalone tool outside this repo, `~/Documents/mannanafnaskra/mannanafnaskra.py` (stdlib +
  `requests` only, no icelandic-thesis-comparison-specific code, reusable from any project), and is
  vendored verbatim into `scripts/mannanafnaskra.py` here. `scripts/fetch_mannanafnaskra.py` is the
  project-specific wrapper (writes `data/processed/mannanafnaskra.csv`, gitignored, not part of
  `rebuild.sh` -- run by hand like the other `fetch_*` scripts). `scripts/load_mannanafnaskra.sql`
  loads it into `mannanafnaskra_name`; `v_licence_person.kyn` (`scripts/licences.sql`) now falls
  back to it -- checking EVERY given name (first and any middle names), not just the first, so a
  typo'd first name ("Ármannn" for "Ármann") still resolves via a clean middle name ("Einar") --
  when the surname-ending rule finds nothing. Cut "óþekkt kyn" from 653 to 267 (mostly genuinely
  foreign names, out of scope per the user: no comparable registry exists to verify those with
  confidence). Cited in the chapter now (`@manna_nafnaskra`, `references.bib`).
- **HÍ programme catalogue -- in use.** `config/hi_ms_programmes.yaml` (from a domain expert) is
  loaded into `hi_programme` by `scripts/load_hi_programmes.py` (rebuild step `disciplines`);
  `hi_programme_map` in `scripts/discipline_map.sql` says which programme and track each discipline
  is, and `v_thesis_hi_programme` / `v_hi_programme_disagreement` compare the catalogue's deild with
  the crosswalk's: **no disagreement** across the 1,138 HÍ theses that map to a programme, so
  `discipline_unit` stands. `R/plots/vidauki-hi-tre.R` now draws the tree in the catalogue's terms.
  Six lines (71 theses) are not in today's catalogue and are marked in the plot.
- **Industry advisors / co-supervisors** (from a human note: e.g. Efla engineers as
  co-supervisors). Some of the advisors without a staff page are industry people, not departed
  academics: 416 of 2,022 advisors have no birth year (typical of external supervisors), and
  `sponsor` is empty for every thesis. Classifying advisors as academic vs. industry, and by employer
  (title-page advisor lines and acknowledgements name the company), is the missing piece for RQ5 and
  RQ7 and would tighten the advisor-department coverage claim. Not started.
- **Research question:** how often do advisors supervise within vs. across their own faculty?

## Resolved

- **22691 (Jón Einarsson) is not licence holder Jón Helgi Einarsson.** The thesis title page gives
  the full author name Jón Smári Einarsson, while the licence holder's education is BS Electrical
  Engineering (HÍ, 1984–1988) and MSEE Electrical Engineering (Purdue, 1988–1990). The incompatible
  middle names disprove the tier-3 match that incomplete Skemman metadata had allowed. Added to
  `licence_match_exclusion` in `scripts/licences.sql`.
- **Tier-3 licence matches checked against cached title pages.** Title-page names now override
  incomplete OAI author names for licence matching only (`thesis_author_name_override` in
  `scripts/licences.sql`). This confirms 39445 as Valur I. Örnólfsson = Valur Indriði Örnólfsson,
  rejects 22691 (Jón Smári ≠ Jón Helgi), and makes 23416 match Guðmundur Örn only rather than both
  Guðmundur Örn and Guðmundur Þórir. Eight other omitted middle names were likewise recovered.
  For 39445, the title-page initial is also consistent with the human-supplied education history:
  RU Diploma in Construction Technology (2013–2015), BSc in Constructing Architecture
  (2016–2017), tæknifræðingur licence in January 2017, then MPM (2019–2021). This is a confirmed
  example of an already licensed technologist later taking MPM continuing education, not evidence
  that the MPM itself led to the licence.
- **17343 is Samuel Nicholas Perkin.** Human confirmation against the government record
  (kennitala 250788-4289, licence 24.04.2019) establishes that Skemman's "Samuel Perkin", born
  1988, is the same person. Added the confirmed full name to `thesis_author_name_override`.
- **The supplied LinkedIn education history for a Tómas Þorsteinsson is not evidence for 18392.**
  That profile attended MR in 1990–1994 and completed a BSc in 1994–1997, whereas the thesis
  author and licence candidate for 18392 are recorded as born in 1988. It is therefore a different
  generation/person. Thesis 18392 is itself an MSc in Byggingarverkfræði, not MPM, and its identity
  match to "Tómas Joð Þorsteinsson" remains unresolved.
- **23113 (Fannar Benedikt Guðmundsson) is not safely matched to licence holder Fannar
  Guðmundsson.** The title page confirms the middle name Benedikt, while the government list is
  treated as carrying the licence holder's full name. A domain-expert check found at least three
  people named Fannar Guðmundsson born in 1986, so first name + last name + birth year is not
  identifying evidence here. Added to `licence_match_exclusion`.
- **26927 is Alasdair Paul Brewer.** Human confirmation against the government record
  (kennitala 270982-2719, licence 20.11.2017) establishes that Skemman's "Alasdair Brewer",
  born 1982, is the same person. Added the confirmed full name to
  `thesis_author_name_override`.
- **36416 is Brandon Nicholas Velasquez.** Human confirmation against the government record
  (kennitala 230296-4569, licence 24.10.2022) establishes that Skemman's "Brandon Velasquez",
  born 1996, is the same person. Added the confirmed full name to
  `thesis_author_name_override`.
- **26950 is not matched to Emilía Maí Valdimarsdóttir.** Skemman and the title page say only
  Emilía Valdimarsdóttir, born 1986; the government list says Emilía Maí Valdimarsdóttir,
  kennitala 070586-2669. The timing is plausible (licence 21.02.2017; Skemman acceptance
  23.03.2017), but first name + last name + birth year without the middle name remains too vague.
  Added to `licence_match_exclusion`; no timing correction is applied to a rejected identity match.

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
