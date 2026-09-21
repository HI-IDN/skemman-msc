-- Discipline mapping for RQ2/RQ3.
--
-- Neither university exposes a department field in the Skemman item metadata:
-- HÍ files every thesis under "Meistaraprófsritgerðir - Verkfræði- og
-- náttúruvísindasvið" and HR under a handful of broad department collections.
-- The only per-thesis discipline signal is the subject keyword list, where both
-- schools tag the námsgrein (Vélaverkfræði, Tölvunarfræði, ...).
--
-- This file seeds a keyword -> discipline lookup. A thesis takes the discipline
-- of its lowest-priority matching keyword. `category` defines the population
-- boundary for issue #1, in five tiers:
--
--   engineering   -- core verkfrædi/taeknigreinar, always in scope
--   professional  -- professional master's adjacent to engineering (MPM). In
--                    scope for the broad population, out for the strict one:
--                    report both rather than picking one.
--   applied       -- idnfraedi: HR's applied-engineering diplomas. Out of the
--                    engineering population, kept separate so HR's mix stays visible.
--   science       -- natural, earth and social sciences. HI's listing is the
--                    whole Verkfraedi- og natturuvisindasvid, so these have to
--                    be excluded by name.
--   out_of_scope  -- not a discipline at all, and not "science" either: a degree
--                    from a different school entirely (Menntavisindasvid), or a
--                    thesis filed in the wrong collection by mistake. Distinct from
--                    science so it is never silently counted as natural-science
--                    output when someone reports that category.
--
--   duckdb data/processed/thesis.db < scripts/discipline_map.sql

-- Rebuilt from scratch on every run so the seed below is the single source of
-- truth. Dropped view-first because v_thesis_discipline depends on the table.
drop view if exists v_thesis_discipline;
drop table if exists discipline_keyword;

create table discipline_keyword
(
    keyword_norm   varchar,
    discipline     varchar,
    category       varchar,
    priority       integer default 100,
    -- Cuts across category: a degree whose home faculty is not the one its thesis
    -- topic and supervising department suggest. 'teacher_education' is Menntavísindadeild
    -- (School of Education) theses with a science/engineering kjörsvið (elective
    -- specialization) -- the thesis is cross-listed into that subject's collection
    -- and can even be supervised there, but the náms­braut (degree programme) is the
    -- School of Education's, not SENS's. See issue #5 (thesis 38678).
    flag           varchar
);

create unique index discipline_keyword_uq on discipline_keyword (keyword_norm);

insert into discipline_keyword (keyword_norm, discipline, category, priority) values
-- Mechanical / mechatronics
('vélaverkfræði',                  'Vélaverkfræði',              'engineering', 10),
('mechanical engineering',         'Vélaverkfræði',              'engineering', 10),
('mechatronics engineering',       'Mekatróník',                 'engineering', 10),
('hátækniverkfræði',               'Hátækniverkfræði',           'engineering', 10),

-- Chemical / biochemical engineering
('efnaverkfræði',                  'Efnaverkfræði',              'engineering', 10),
('chemical engineering',           'Efnaverkfræði',              'engineering', 10),
('lífefnaverkfræði',               'Lífefnaverkfræði',           'engineering', 15),

-- Civil / environmental / structural
('byggingarverkfræði',             'Byggingarverkfræði',         'engineering', 10),
('civil engineering',              'Byggingarverkfræði',         'engineering', 10),
('umhverfis- og byggingarverkfræði','Byggingarverkfræði',        'engineering', 10),
('mannvirkjagerð',                 'Byggingarverkfræði',         'engineering', 30),
('umhverfisverkfræði',             'Umhverfisverkfræði',         'engineering', 10),

-- Industrial / operations / financial engineering
('iðnaðarverkfræði',               'Iðnaðarverkfræði',           'engineering', 10),
('industrial engineering',         'Iðnaðarverkfræði',           'engineering', 10),
('rekstrarverkfræði',              'Rekstrarverkfræði',          'engineering', 10),
('engineering management',         'Rekstrarverkfræði',          'engineering', 10),
('fjármálaverkfræði',              'Fjármálaverkfræði',          'engineering', 10),
('financial engineering',          'Fjármálaverkfræði',          'engineering', 10),
('ákvarðanaverkfræði',             'Ákvarðanaverkfræði',         'engineering', 20),

-- Project management (HR's MPM -- a professional master's, see note below)
('verkefnastjórnun',               'Verkefnastjórnun',           'professional', 15),
('verkefnastjórar',                 'Verkefnastjórnun',           'professional', 15),
('project management',             'Verkefnastjórnun',           'professional', 15),
('master of project management',   'Verkefnastjórnun',           'professional', 15),
('mpm',                            'Verkefnastjórnun',           'professional', 15),

-- Electrical / power
('rafmagnsverkfræði',              'Rafmagnsverkfræði',          'engineering', 10),
('electrical engineering',         'Rafmagnsverkfræði',          'engineering', 10),
('rafmagns- og tölvuverkfræði',    'Rafmagnsverkfræði',          'engineering', 10),
('raforkuverkfræði',               'Raforkuverkfræði',           'engineering', 10),
('electric power engineering',     'Raforkuverkfræði',           'engineering', 10),
-- Tolvuverkfraedi is a discipline in its own right; both it and
-- Rafmagnsverkfraedi belong to Rafmagns- og tolvuverkfraedideild (RT). The
-- combined keyword names the deild rather than the discipline, so it stays on
-- Rafmagnsverkfraedi -- the unit is RT either way.
('tölvuverkfræði',                 'Tölvuverkfræði',             'engineering', 10),
('computer engineering',           'Tölvuverkfræði',             'engineering', 10),

-- Computing
('tölvunarfræði',                  'Tölvunarfræði',              'engineering', 10),
('computer science',               'Tölvunarfræði',              'engineering', 10),
('tölvufræði',                     'Tölvunarfræði',              'engineering', 20),
('hugbúnaðarverkfræði',            'Hugbúnaðarverkfræði',        'engineering', 10),
('software engineering',           'Hugbúnaðarverkfræði',        'engineering', 10),
('hugbúnaðargerð',                 'Hugbúnaðarverkfræði',        'engineering', 20),
('software development',           'Hugbúnaðarverkfræði',        'engineering', 20),
('reikniverkfræði',                'Reikniverkfræði',            'engineering', 10),
('computational engineering',      'Reikniverkfræði',            'engineering', 10),

-- Energy
('orkuverkfræði',                  'Orkuverkfræði',              'engineering', 10),
('sustainable energy engineering', 'Orkuverkfræði',              'engineering', 10),
('orkuvísindi',                    'Orkuverkfræði',              'engineering', 12),
('sustainable energy',             'Orkuverkfræði',              'engineering', 12),
('energy systems',                 'Orkuverkfræði',              'engineering', 12),
-- "Sustainable Energy Science" (Iceland School of Energy) is a science programme, not the
-- engineering one: none of its 31 HR authors with a known birth year is a licensed engineer
-- (0 of 31, against 15 of 72 for the "Sustainable Energy Engineering" wording; p = 0.003).
-- The bare "sustainable energy" wording stays Orkuverkfraedi.
('sustainable energy sciences',    'Sjálfbær orkuvísindi',              'science', 12),
('sustainable energy science',     'Sjálfbær orkuvísindi',              'science', 12),

-- Biomedical / bioengineering
('heilbrigðisverkfræði',           'Heilbrigðisverkfræði',       'engineering', 10),
('biomedical engineering',         'Heilbrigðisverkfræði',       'engineering', 10),
('lífverkfræði',                   'Heilbrigðisverkfræði',       'engineering', 20),
('stafræn heilbrigðistækni',       'Heilbrigðisverkfræði',       'engineering', 12),
('heilbrigðistækni',               'Heilbrigðisverkfræði',       'engineering', 15),

-- Data science / language technology
('gagnavísindi',                   'Gagnavísindi',               'engineering', 10),
('data science',                   'Gagnavísindi',               'engineering', 10),
('hagnýtt gagnavísindi',           'Gagnavísindi',               'engineering', 12),
('hagnýt gagnavísindi',            'Gagnavísindi',               'engineering', 12),
('applied data science',           'Gagnavísindi',               'engineering', 12),
('máltækni',                       'Máltækni',                   'engineering', 10),
('gervigreind og máltækni',        'Máltækni',                   'engineering', 12),
('language technology',            'Máltækni',                   'engineering', 10),

-- Construction management -- an engineering MSc (human-confirmed via 10906: an 85-page MSc
-- thesis, the engineering counterpart of the professional programmes; industrial-engineering
-- related or closely adjacent), NOT a professional master's like MPM. Same category as the
-- other verkfraedi disciplines; HI already files it under UmBygg in discipline_unit.
('framkvæmdastjórnun',             'Framkvæmdastjórnun',         'engineering', 15),
('construction management',        'Framkvæmdastjórnun',         'engineering', 15),

-- Energy, additional spellings
('sjálfbær orkuvísindi - reyst',   'Sjálfbær orkuvísindi',              'science', 12),
('sjálfbær orkuvísindi',           'Sjálfbær orkuvísindi',              'science', 12),
('sjálfbær orka',                  'Orkuverkfræði',              'engineering', 12),
('sjálfbær orka og verkfræði',     'Orkuverkfræði',              'engineering', 12),

-- Idnfraedi -- HR's Dip Taeknifraedideild / Department of Applied Engineering.
-- A professional diploma taken alongside work, not a verkfraedi degree; the same
-- kind of boundary as MPM, so it gets its own category rather than being folded
-- into engineering or dropped. Almost all of these sit at BS level.
('rafiðnfræði',                    'Rafiðnfræði',                'applied', 12),
('véliðnfræði',                    'Véliðnfræði',                'applied', 12),
('byggingariðnfræði',              'Byggingariðnfræði',          'applied', 12),
('byggingariðfræði',               'Byggingariðnfræði',          'applied', 12),
('bygingariðnfræði',               'Byggingariðnfræði',          'applied', 12),
('iðnfræði',                       'Iðnfræði (ótilgreind)',      'applied', 90),

-- Taeknifraedi -- HR's BSc applied-engineering programmes. Same footing as
-- idnfraedi: practice-oriented and outside the verkfraedi population, so they
-- share the 'applied' category. Spelling varies a lot in Skemman, so the
-- variants are folded onto one name per programme.
('byggingartæknifræði',            'Byggingartæknifræði',        'applied', 12),
('rafmagnstæknifræði',             'Rafmagnstæknifræði',         'applied', 12),
('vél- og orkutæknifræði',         'Vél- og orkutæknifræði',     'applied', 12),
('vél-og orkutæknifræði',          'Vél- og orkutæknifræði',     'applied', 12),
('vél og orkutæknifræði',          'Vél- og orkutæknifræði',     'applied', 12),
('orku- og véltæknifræði',         'Vél- og orkutæknifræði',     'applied', 12),
('véltæknifræði',                  'Vél- og orkutæknifræði',     'applied', 12),
('orku- og umhverfistæknifræði',   'Orku- og umhverfistæknifræði', 'applied', 12),
('orku og umhverfis tæknifræði',   'Orku- og umhverfistæknifræði', 'applied', 12),
('umhverfis- og orkutæknitæknifræði', 'Orku- og umhverfistæknifræði', 'applied', 12),
('mekatróník hátæknifræði',        'Hátæknifræði (mekatróník)',  'applied', 12),
('hátæknifræði mekatróník',        'Hátæknifræði (mekatróník)',  'applied', 12),
('mekatrónísk tæknifræði',         'Hátæknifræði (mekatróník)',  'applied', 12),
('hátæknifræði',                   'Hátæknifræði (mekatróník)',  'applied', 15),
('iðnaðartæknifræði',              'Iðnaðartæknifræði',          'applied', 12),
('tæknifræði',                     'Tæknifræði (ótilgreind)',    'applied', 90),

-- BOUNDARY CALL -- still open. A technical programme, arguably outside
-- "verkfraedi og taeknigreinar". Move to 'applied' or 'science' to narrow.
('skipulagsfræði og samgöngur',    'Skipulagsfræði og samgöngur', 'engineering', 15),
('samgöngur',                      'Skipulagsfræði og samgöngur', 'engineering', 25),

-- Generic engineering fallback
('verkfræði',                      'Verkfræði (ótilgreind)',     'engineering', 90),
('engineering',                    'Verkfræði (ótilgreind)',     'engineering', 90),

-- Explicitly NOT engineering: HÍ's listing is the whole Verkfræði- og
-- náttúruvísindasvið, so the natural sciences have to be excluded by name.
('líffræði',                       'Líffræði',                   'science', 10),
('sjávarlíffræði',                 'Líffræði',                   'science', 15),
('lífefnafræði',                   'Lífefnafræði',               'science', 10),
('lífupplýsingafræði',             'Lífupplýsingafræði',         'science', 10),
('jarðfræði',                      'Jarðfræði',                  'science', 10),
-- Bergfræði (petrology) is a Jarðfræði subfield, not its own discipline.
('bergfræði',                      'Jarðfræði',                  'science', 15),
('jarðeðlisfræði',                 'Jarðeðlisfræði',             'science', 10),
('jarðvísindi',                    'Jarðvísindi',                'science', 15),
('jarðefnafræði',                  'Jarðefnafræði',              'science', 15),
('efnafræði',                      'Efnafræði',                  'science', 10),
('lífræn efnafræði',               'Efnafræði',                  'science', 12),
('ólífræn efnafræði',              'Efnafræði',                  'science', 12),
('eðlisfræði',                     'Eðlisfræði',                 'science', 10),
('stærðfræði',                     'Stærðfræði',                 'science', 10),
('tölfræði',                       'Tölfræði',                   'science', 15),
('líftölfræði',                    'Tölfræði',                   'science', 15),
('hagnýt tölfræði',                'Tölfræði',                   'science', 15),
('landfræði',                      'Landfræði',                  'science', 10),
('náttúrulandfræði',                'Landfræði',                  'science', 12),
('ferðamálafræði',                 'Ferðamálafræði',             'science', 10),
('umhverfis- og auðlindafræði',    'Umhverfis- og auðlindafræði','science', 10),
('umhverfisfræði',                 'Umhverfis- og auðlindafræði','science', 15),
('íþróttavísindi og þjálfun',      'Íþróttavísindi',             'science', 10),
('exercise science and coaching',  'Íþróttavísindi',             'science', 10),
('skammtafræði',                   'Eðlisfræði',                 'science', 20),
('iðnaðarlíftækni',                'Líftækni',                   'science', 15),
-- The discipline's own bare name was missing -- only its 'iðnaðar-' compound was mapped.
('líftækni',                       'Líftækni',                   'science', 10),
('sameindalíffræði',               'Líffræði',                   'science', 15),
('landafræði',                     'Landfræði',                  'science', 10),
('verkfræðileg eðlisfræði',        'Verkfræðileg eðlisfræði',                 'engineering', 12),
('stjarneðlisfræði',               'Eðlisfræði',                 'science', 15),
('lífeðlisfræði',                  'Eðlisfræði',                 'science', 15),
('hljóðeðlisfræði',                'Eðlisfræði',                 'science', 15),
('menntun framhaldsskólakennara',  'Menntavísindadeild',         'out_of_scope', 10),
('matvælafræði',                   'Matvælafræði',               'science', 10),
('næringarfræði',                  'Næringarfræði',              'science', 10),
('heilsuþjálfun og kennsla',       'Íþróttavísindi',             'science', 12),
-- Thesis 31238 (title page: MSc in Marketing) is genuinely out of scope, not a
-- discipline this study should count at all -- see issue #5 and TODO.md. Mapped as
-- a keyword rather than a one-off override because "Markaðsfræði" as a term is
-- unambiguous on its own; any other thesis carrying it is presumably the same kind
-- of mis-filed record, not a marketing specialization worth its own tier.
('markaðsfræði',                   'Markaðsfræði',               'out_of_scope', 10);

-- Teacher-education theses (see the `flag` column's own comment above): 7 in the
-- population, all correctly resolved to Menntavísindadeild already because Skemman lists
-- this keyword first every time -- the flag makes that visible rather than implicit.
update discipline_keyword set flag = 'teacher_education'
where keyword_norm = 'menntun framhaldsskólakennara';

-- Titilsíðugreinar (title-page subjects) --------------------------------------
--
-- thesis_titlepage.subject (skemman-harvester's titlepage_load.py) states what the
-- thesis's own title page says the degree is in -- "degree in X" / "meistaraprófs í
-- X" -- independent of Skemman's subject keywords. It is mostly English and names
-- programmes the way a degree certificate would, not the way a submitter tagged
-- keywords, so it needs its own vocabulary rather than reusing the keyword forms
-- above verbatim. Discipline and category stay the same either way; this batch adds
-- the English/inflected forms the title page uses for disciplines already listed.
--
-- Threshold: added where a normalized subject occurred at least twice among
-- population theses and named an existing discipline unambiguously. A bare,
-- one-off, or truncated-past-recognition string ("iceland before she", "geo-") is
-- left unmapped; such a thesis falls back to its keyword-based discipline instead
-- of being guessed at.
insert into discipline_keyword (keyword_norm, discipline, category, priority) values
-- Earth and physical sciences -- HÍ states these in English on the title page far
-- more often than the Icelandic keyword list does.
('geology',                            'Jarðfræði',                    'science', 10),
('geophysics',                         'Jarðeðlisfræði',               'science', 10),
('earth sciences',                     'Jarðvísindi',                  'science', 15),
('earth science',                      'Jarðvísindi',                  'science', 15),
('geosciences',                        'Jarðvísindi',                  'science', 15),
('chemistry',                          'Efnafræði',                    'science', 10),
('organic chemistry',                  'Efnafræði',                    'science', 12),
('inorganic chemistry',                'Efnafræði',                    'science', 12),
('physics',                            'Eðlisfræði',                   'science', 10),
('engineering physics',                'Verkfræðileg eðlisfræði',                   'engineering', 12),
('theoretical physics',                'Eðlisfræði',                   'science', 15),
('astrophysics',                       'Eðlisfræði',                   'science', 15),
('mathematics',                        'Stærðfræði',                   'science', 10),
('statistics',                         'Tölfræði',                     'science', 10),
('applied statistics',                 'Tölfræði',                     'science', 15),
('geography',                          'Landfræði',                    'science', 10),
('biology',                            'Líffræði',                     'science', 10),
('marine biology',                     'Líffræði',                     'science', 15),
('molecular biology',                  'Líffræði',                     'science', 15),
('biochemistry',                       'Lífefnafræði',                 'science', 10),
('bioinformatics',                     'Lífupplýsingafræði',           'science', 10),
('industrial biotechnology',           'Líftækni',                     'science', 15),
('food science',                       'Matvælafræði',                 'science', 10),
('tourism studies',                    'Ferðamálafræði',               'science', 10),
('environment and natural resources',  'Umhverfis- og auðlindafræði',  'science', 10),
('environment and natural',            'Umhverfis- og auðlindafræði',  'science', 15),
('environmental and natural resources','Umhverfis- og auðlindafræði',  'science', 12),
('íþróttavísindum og þjálfun',         'Íþróttavísindi',               'science', 10),
-- No Icelandic keyword names this programme; the title page is the only source.
-- The full programme name, now that the title-page parser reads it whole (see
-- issue #5) rather than truncated at a line wrap. Four spellings on record:
-- with/without "and Management" (once doubled, on the title page itself, not an
-- extraction bug -- thesis 33203), British/American "Modelling"/"Modeling", and
-- hyphenated/unhyphenated "Geo-information"/"Geoinformation".
('geo-information science and earth observation for environmental modelling and management',
                                        'Landupplýsinga- og umhverfisfræði', 'science', 12),
('geo-information science and earth observation for environmental modeling and management',
                                        'Landupplýsinga- og umhverfisfræði', 'science', 12),
('geoinformation science and earth observation for environmental management and management',
                                        'Landupplýsinga- og umhverfisfræði', 'science', 12),
('geo-information science and earth observation for environmental modelling',
                                        'Landupplýsinga- og umhverfisfræði', 'science', 12),

-- Engineering -- combined English programme names fold onto the same discipline
-- their combined Icelandic keywords already do, for the same reason: the name
-- describes the deild, not a separate field.
('environmental engineering',              'Umhverfisverkfræði', 'engineering', 10),
('civil and environmental engineering',    'Byggingarverkfræði', 'engineering', 10),
('structural engineering',                 'Byggingarverkfræði', 'engineering', 20),
('civil engineering with',                 'Byggingarverkfræði', 'engineering', 15),
('byggingarverkfræði með',                 'Byggingarverkfræði', 'engineering', 15),
('byggingarverkfræði með sérhæfingu í',    'Byggingarverkfræði', 'engineering', 15),
('byggingarverkfræði við háskóla íslands', 'Byggingarverkfræði', 'engineering', 20),
('electrical and computer engineering',       'Rafmagnsverkfræði', 'engineering', 10),
('electrical and computer engineering at the','Rafmagnsverkfræði', 'engineering', 15),
('computational en-',                      'Reikniverkfræði',    'engineering', 20),
('bioengineering',                         'Heilbrigðisverkfræði', 'engineering', 20),
('decision engineering',                   'Ákvarðanaverkfræði', 'engineering', 20),
('renewable energy sciences',              'Sjálfbær orkuvísindi',      'science', 12),
('energy engineering -',                   'Orkuverkfræði',      'engineering', 12),
('sustainable energy engineering - ise',   'Orkuverkfræði',      'engineering', 12),
('skipulagsfræði og samgöngum',            'Skipulagsfræði og samgöngur', 'engineering', 15),

-- Spelling variants of what is already mapped above -- no new judgment, just a
-- typo the title page carries that the keyword list does not.
('verkefnastjórnum',                       'Verkefnastjórnun',   'professional', 15),
('rekstarverkfræði',                       'Rekstrarverkfræði',  'engineering', 10),

-- Title-page subjects that turned up once the parser learned Reykjavik University's newer
-- template (skemman-harvester, icelandic-thesis-comparison#5). Each names a programme the
-- title page states outright; the niche label is kept, grouping is discipline_group's job.
('mechatronic engineering',                'Mekatróník',         'engineering', 10),
('mechatronics',                           'Mekatróník',         'engineering', 12),
('electrical power engineering',           'Raforkuverkfræði',   'engineering', 10),
('electrical energy engineering',          'Raforkuverkfræði',   'engineering', 12),
('management engineering',                 'Rekstrarverkfræði',  'engineering', 12),
('energy engineering',                     'Orkuverkfræði',      'engineering', 12),
('byggingaverkfræði',                      'Byggingarverkfræði', 'engineering', 10);

-- One CANDIDATE discipline per thesis: the FIRST matching keyword in Skemman's own
-- subject order wins. This is a cheap first guess, not a final answer -- see issue #5.
-- Both schools usually list the namsgrein first and topical terms after, so sort_order
-- carries real signal, but Skemman does not always follow that convention, and this view
-- has no way to notice when it does not. That is fine: it only has to be good enough to
-- decide what is worth reading a title page for, not to be the last word on any one
-- thesis. A generic `(ótilgreind)` match (bare "verkfræði") ranks after every specific
-- one regardless of position (53775 lists Verkfræði before Rekstrarverkfræði).
-- `priority` only breaks ties within one sort_order position. The earlier rule
-- ordered by priority and fell back to alphabetical, which was arbitrary --
-- "Idnadarverkfraedi; Fjarmalaverkfraedi; ..." was filed under Fjarmalaverkfraedi purely
-- because F sorts before I.
create or replace view v_thesis_discipline_candidate as
with matches as (
    select
        tk.thesis_id,
        d.discipline,
        d.category,
        d.flag,
        row_number() over (
            partition by tk.thesis_id
            order by (d.discipline like '%(ótilgreind)'), tk.sort_order, d.priority, d.discipline
        ) as rn
    from thesis_keywords tk
    join keywords k on k.id = tk.keyword_id
    -- Skemman merkir sum leitarord "X (namsgrein)". Svigann er strokinn
    -- hér svo fraedin thurfi adeins eina rod i toflunni ad ofan.
    join discipline_keyword d
      on d.keyword_norm = regexp_replace(k.keyword_norm, '\s*\(námsgrein\)$', '')
)
-- Built on the population, not on `thesis`: every row here is a master's
-- thesis in the analysis years. Bachelor's theses and diplomas carry the same
-- keywords and would be classified just as happily, so leaving them in meant
-- every query downstream had to remember to filter them out again.
select
    m.thesis_id,
    m.yr,
    m.university,
    x.discipline,
    x.category,
    x.flag,
    x.discipline is null as unclassified
from v_thesis_msc m
left join matches x on x.thesis_id = m.thesis_id and x.rn = 1;

-- The same crosswalk, matched on the title page's own stated subject instead of
-- Skemman's keywords -- see issue #5. `subject` is one string per thesis, not a
-- ranked list, so there is no tie-break to make: at most one discipline_keyword
-- row can match a given normalized subject, because keyword_norm is unique.
create or replace view v_thesis_discipline_titlepage as
-- A title-page subject matches a keyword exactly, or begins with it at a word boundary:
-- "civil engineering with specialization in structural design" is Byggingarverkfræði,
-- "sustainable energy iceland school of energy" is Orkuverkfræði. The longest keyword
-- wins, so "engineering management ..." is not read as the generic "engineering".
with matched as (
    select
        m.thesis_id,
        m.yr,
        m.university,
        d.discipline,
        d.category,
        d.flag,
        row_number() over (
            partition by m.thesis_id
            order by length(d.keyword_norm) desc, d.priority, d.discipline
        ) as rn
    from v_thesis_msc m
    join thesis_titlepage p on p.thesis_id = m.thesis_id
    join discipline_keyword d
      on lower(trim(p.subject)) = d.keyword_norm
      or starts_with(lower(trim(p.subject)), d.keyword_norm || ' ')
    where p.subject is not null
)
select thesis_id, yr, university, discipline, category, flag
from matched
where rn = 1;

-- Where both signals exist, how often they agree -- and where they do not, what
-- each one said. 990/1,031 agree; the appendix table in vidauki-titilsida.R reads
-- straight off this view. Compares the two RAW signals, before either the parser-bug
-- correction or the override table below apply -- it is the diagnostic, not the answer.
create or replace view v_rq2_discipline_agreement as
select
    kd.thesis_id,
    kd.university,
    kd.discipline as keyword_discipline,
    kd.category   as keyword_category,
    tp.discipline as titlepage_discipline,
    tp.category   as titlepage_category,
    kd.discipline is not distinct from tp.discipline as agrees
from v_thesis_discipline_candidate kd
join v_thesis_discipline_titlepage tp on tp.thesis_id = kd.thesis_id
where kd.discipline is not null;

-- Manual corrections from reviewing issue #5's disagreement list -- a thesis where
-- neither automated signal is trusted as-is. Currently just the one confirmed parser
-- bug; grows as review of outputs/rq2-*.csv turns up more. `reason` is for humans, not
-- read by any view.
create table if not exists discipline_override
(
    thesis_id  integer,
    discipline varchar,
    category   varchar,
    reason     varchar
);

create unique index if not exists discipline_override_pk on discipline_override (thesis_id);

insert into discipline_override (thesis_id, discipline, category, reason)
values
(
    36353, 'Verkefnastjórnun', 'professional',
    'titlepage subject "computer science" is a confirmed parser bug -- pulled from an '
    'interviewee''s biography, not the actual title page. All four keywords '
    '(Verkefnastjórnun, MPM, Project management, Master of project management) agree '
    'with each other and with the true title page text ("9 ECTS for the degree of '
    'Master of Project Management (MPM)"). See issue #5.'
),
(
    -- No keyword matched at all. Title-page subject truncated to "Innovative and
    -- Sustainable" (parser bug, same class as 36353's but a cut-off rather than a wrong
    -- page). Human-confirmed full degree: Magister Scientiarum in Innovative and
    -- Sustainable Energy Engineering, Faculty of Industrial Engineering, Mechanical
    -- Engineering and Computer Science. Treated as Orkuverkfraedi for now, same as HR's
    -- "sustainable energy engineering - ise" -- a one-off override, not a vocabulary
    -- entry, because only this thesis's subject is known to be this specific truncation.
    -- If this faculty name recurs for other theses, it deserves its own crosswalk
    -- (like discipline_unit) rather than more one-off overrides -- not done yet.
    24869, 'Orkuverkfræði', 'engineering',
    'titlepage subject truncated to "Innovative and Sustainable"; full degree confirmed '
    'human-side as Innovative and Sustainable Energy Engineering, Faculty of Industrial '
    'Engineering, Mechanical Engineering and Computer Science. See issue #5.'
),
(
    -- No keyword matched (only generic Fjármál/Stjórnun/Bestun -- none of them the
    -- námsgrein itself), and no title page exists to check: the PDF's access is
    -- "Lokaður" (closed), so titlepage-load could never fetch it. Human-confirmed from
    -- outside the automated signals entirely.
    4446, 'Fjármálaverkfræði', 'engineering',
    'closed/restricted PDF, no title page ever fetchable; keywords (Fjármál, Stjórnun, '
    'Bestun) are all topical, none name the study line. Human-confirmed. See issue #5.'
),
(
    -- Title page generic ("MS in engineering") and the only keywords are the bare
    -- "verkfræði" plus "klæðningar vega" (road pavements). Resolved from the advisor
    -- suggestion: both advisors' own plurality is Byggingarverkfræði (Sigurdur
    -- Erlingsson 25 of 27 theses, Thorsteinn Thorsteinsson 7 of 12).
    23908, 'Byggingarverkfræði', 'engineering',
    'generic title page, no specific keyword; advisor suggestion (both advisors '
    'plurality Byggingarverkfræði) plus topic (road pavements). See issue #5.'
),
(
    -- Keywords list Verkefnastjornun (position 2) before Rekstrarverkfraedi (3) and
    -- Engineering management (6), so the keyword pass files it as professional. The
    -- degree is an MSc in engineering management, i.e. Rekstrarverkfraedi: the thesis
    -- topic (project prioritisation) is project-management-flavoured, but the programme is
    -- engineering. Human-confirmed; 92 of 135 HR authors with an engineering-management /
    -- Rekstrarverkfraedi keyword are on the government verkfraedingur list. The author has
    -- not applied yet (thesis accepted 2026-06-12), so no licence to check.
    53766, 'Rekstrarverkfræði', 'engineering',
    'MSc in engineering management; keyword order made Verkefnastjórnun win. '
    'Human-confirmed engineering degree. See issue #5.'
),
(
    -- Title page reads "MSc thesis in Biomedical Engineering" (Heilbrigdisverkfraedi), but
    -- titlepage_load left `subject` empty (it read junk into `deild`), and the only
    -- keyword is the bare "verkfraedi". Human-confirmed from the title page.
    50796, 'Heilbrigðisverkfræði', 'engineering',
    'title page: MSc in Biomedical Engineering; title-page parser left subject NULL. '
    'Human-confirmed. See issue #5.'
),
(
    -- Title page says only "Master of Science in Engineering" (subject "Engineering", so
    -- the generic discipline), and no Skemman keyword names the study line, but the topic
    -- keywords (venture capital, econometric models of finance) are clearly financial
    -- engineering. Human-confirmed; advisor Sverrir Olafsson agrees.
    44748, 'Fjármálaverkfræði', 'engineering',
    'generic title page; topic keywords are clearly financial engineering. '
    'Human-confirmed. See issue #5.'
),
(
    -- The PDF's font is garbled, so the parser cannot read the title page; a human read it:
    -- "30 ECTS submitted to the Department of Engineering at Reykjavik University for the degree
    -- of Master of Science in Electric Power Management". "Management", not "Engineering", and
    -- the advisor (Hlynur Stefansson) supervises engineering-management theses, so
    -- Rekstrarverkfraedi; Raforkuverkfraedi is the alternative if that title is read as an
    -- electric-power programme. Topic: net-metering utility valuation in the Arctic.
    50986, 'Rekstrarverkfræði', 'engineering',
    'garbled PDF font; title page read by a human: MSc in Electric Power Management, Department '
    'of Engineering. Advisor supervises engineering management. See issue #5.'
),
(
    -- No title page in the cache, and the keywords mislead ("Geothermal brines" looks like a
    -- stray tag; the advisor suggestion, Orkuverkfraedi, follows it). The abstract is a study of
    -- Elkem Iceland's ferrosilicon furnaces: physical and chemical attributes of silica fume
    -- against raw-material selection -- a chemical/process-engineering thesis. The author is a
    -- licensed verkfraedingur (licence 2025), so it is an engineering degree. Human's guess
    -- (chemical engineering) matches the abstract.
    50850, 'Efnaverkfræði', 'engineering',
    'ferrosilicon furnace silica fume (Elkem Iceland): chemical/process engineering; author '
    'licensed engineer; advisor suggestion (Orkuverkfraedi) followed a stray keyword. See issue #5.'
)
on conflict (thesis_id) do update set
    discipline = excluded.discipline, category = excluded.category, reason = excluded.reason;

-- Niche label first, umbrella second. `discipline` reports what the title page (or, failing
-- that, the keywords) says -- Mekatróník, Fjármálaverkfræði, Raforkuverkfræði -- and this table
-- says which broader discipline each rolls up into, for comparing HI and HR (which name and
-- split their programmes differently). A discipline with no row is its own umbrella.
-- Judgment calls, revisit freely: Framkvæmdastjórnun is "industrial-engineering related or
-- closely adjacent". At HI the Rafmagns- og tölvuverkfræði deild has three tracks
-- (læknisfræðileg verkfræði = HR's Heilbrigðisverkfræði, rafmagnsverkfræði, tölvuverkfræði)
-- and its MS lists renewable energy as a main track, hence both roll up to Rafmagnsverkfræði.
--
-- HI's MS programmes (all 120 ECTS), for reference when deciding umbrellas:
--   Hugbúnaðarverkfræði: Almenn hugbúnaðarverkfræði | Nýsköpun og viðskiptaþróun | Netöryggi
--   Iðnaðarverkfræði
--   Reikniverkfræði
--   Tölvunarfræði: Almenn tölvunarfræði | Máltækni | Netöryggi
--   Vélaverkfræði: Vélaverkfræði | Endurnýjanleg orka - jarðhitaverkfræði
--   Rafmagns- og tölvuverkfræði: incl. Endurnýjanleg orka - vistvæn orkuverkfræði as a main track
--   Byggingarverkfræði: Mannvirkja- og jarðskjálftaverkfræði | Jarðtækni og samgönguverkfræði |
--                       Endurnýjanleg orka - orkuverkfræði
--   Umhverfisverkfræði: Umhverfisgæði | Vatnaverkfræði | Sjálfbær byggð og öruggar samgöngur |
--                       Endurnýjanleg orka - orkuverkfræði
-- (full list in config/hi_ms_programmes.yaml.) Renewable energy therefore has a track in four
-- MS programmes across three engineering deilds (IVT, RT, UmBygg); Orkuverkfræði is a
-- cross-cutting field, left as its own discipline (its 6 HI theses sit in IVT), not grouped.
create table if not exists discipline_group
(
    discipline varchar,
    umbrella   varchar,
    note       varchar
);

create unique index if not exists discipline_group_pk on discipline_group (discipline);

insert into discipline_group (discipline, umbrella, note) values
('Fjármálaverkfræði',   'Iðnaðarverkfræði', 'a study line inside the industrial engineering department'),
('Rekstrarverkfræði',   'Iðnaðarverkfræði', 'engineering management'),
('Ákvarðanaverkfræði',  'Iðnaðarverkfræði', 'decision engineering'),
('Framkvæmdastjórnun',  'Iðnaðarverkfræði', 'construction management; industrial-engineering related or adjacent'),
('Mekatróník',          'Vélaverkfræði',    'mechatronics'),
('Hátækniverkfræði',    'Vélaverkfræði',    'HR high-tech engineering'),
('Raforkuverkfræði',    'Rafmagnsverkfræði', 'electric power engineering; HI: a track of Rafmagns- og tölvuverkfræði'),
('Heilbrigðisverkfræði','Rafmagnsverkfræði', 'HI: læknisfræðileg verkfræði is a track of the single Rafmagns- og tölvuverkfræði deild'),
('Máltækni',           'Tölvunarfræði',    'HI: Máltækni is a track of the Tölvunarfræði MS (with Almenn tölvunarfræði, Netöryggi)'),
('Lífefnaverkfræði',    'Efnaverkfræði',    'biochemical engineering')
on conflict (discipline) do update set umbrella = excluded.umbrella, note = excluded.note;

-- The OFFICIAL discipline: what every other chapter, table and figure should read.
-- Precedence is override > title page > keyword candidate -- the title page is the
-- authority the harvester itself claims ("states the faculty, the credits and the
-- degree outright"), the keyword guess is only ever a fallback for the ~55% of the
-- population a title page has not (yet) resolved a subject for, and an override exists
-- only where a human has looked at a specific thesis and said neither automated signal
-- is right. Because the title page wins on disagreement, the "first keyword wins" quirk
-- in v_thesis_discipline_candidate (see issue #5: sort_order picks the wrong sibling
-- keyword for a handful of theses) never reaches here -- it is a candidate-only problem.
create or replace view v_thesis_discipline as
with resolved as (
    select
        c.thesis_id,
        c.yr,
        c.university,
        o.discipline as o_discipline, o.category as o_category,
        -- A generic title page ("... degree of master of science in engineering", no study
        -- line named) says less than a specific keyword (e.g. 5597: title page generic,
        -- keywords Fjarmalaverkfraedi; Idnadarverkfraedi), so it yields to the keyword.
        case when tp.discipline like '%(ótilgreind)' and c.discipline is not null
                  and c.discipline not like '%(ótilgreind)'
             then null else tp.discipline end as tp_discipline,
        case when tp.discipline like '%(ótilgreind)' and c.discipline is not null
                  and c.discipline not like '%(ótilgreind)'
             then null else tp.category end   as tp_category,
        c.discipline as c_discipline, c.category as c_category,
        coalesce(tp.flag, c.flag) as flag
    from v_thesis_discipline_candidate c
    left join v_thesis_discipline_titlepage tp on tp.thesis_id = c.thesis_id
    left join discipline_override o on o.thesis_id = c.thesis_id
)
select
    thesis_id,
    yr,
    university,
    coalesce(o_discipline, tp_discipline, c_discipline)                    as discipline,
    coalesce(g.umbrella, coalesce(o_discipline, tp_discipline, c_discipline))
                                                                            as umbrella,
    coalesce(o_category, tp_category, c_category)                          as category,
    coalesce(o_category, tp_category, c_category) = 'engineering'          as is_engineering,
    coalesce(o_category, tp_category, c_category) in ('engineering', 'professional')
                                                                            as in_scope_broad,
    coalesce(o_discipline, tp_discipline, c_discipline) is null            as unclassified,
    case
        when o_discipline is not null  then 'override'
        when tp_discipline is not null then 'titlepage'
        when c_discipline is not null  then 'keyword'
        else null
    end                                                                    as discipline_source,
    -- No override column for this -- an override always names a specific discipline
    -- and a human already looked at the thesis, so the flag's job (flagging something
    -- worth a second look) is already done for those rows.
    flag = 'teacher_education'                                             as is_teacher_education
from resolved r
left join discipline_group g
       on g.discipline = coalesce(r.o_discipline, r.tp_discipline, r.c_discipline);

-- ---------------------------------------------------------------------------
-- Advisor-based discipline suggestion (TODO.md idea)
--
-- For a thesis with no keyword match, no fetchable title page, and no
-- override -- i.e. still `unclassified` above, or resolved only to a generic
-- `(ótilgreind)` discipline (e.g. 23908) -- an advisor's own supervision
-- history is a signal: what discipline do their *other* population theses
-- mostly sit in? This is a human-reviewed suggestion, not a
-- v_thesis_discipline tier: a thesis can have advisors from different
-- departments, so it is a plurality vote across advisors, not a certain
-- answer. Read v_thesis_discipline_advisor_suggestion, look at `advisors`,
-- and either add a discipline_override row or a discipline_keyword entry --
-- whichever the review shows is right. See TODO.md and issue #5.
--
-- "Other theses" means other population master's theses this advisor
-- supervised, already resolved by keyword/titlepage/override
-- (v_thesis_discipline) -- not bachelor's theses or years outside the
-- analysis window, neither of which get a discipline row to count here.

-- Per advisor, how many of their already-resolved population theses fall
-- into each discipline.
create or replace view v_advisor_discipline_history as
select
    tp.person_id,
    p.name as advisor_name,
    d.discipline,
    d.category,
    count(*) as thesis_count
from thesis_people tp
join people p on p.id = tp.person_id
join v_thesis_discipline d on d.thesis_id = tp.thesis_id
where tp.role = 'advisor'
  and d.discipline is not null
  -- a generic discipline says nothing about the advisor's field
  and d.discipline not like '%(ótilgreind)'
group by tp.person_id, p.name, d.discipline, d.category;

-- Each advisor's own plurality discipline: the top by thesis_count. Ties are
-- broken alphabetically -- arbitrary, so `advisor_tied` flags it for a human
-- reviewing a suggestion, rather than silently picking one.
create or replace view v_advisor_discipline_plurality as
with ranked as (
    select
        *,
        sum(thesis_count) over (partition by person_id) as advisor_total,
        max(thesis_count) over (partition by person_id) as max_count,
        row_number() over (
            partition by person_id order by thesis_count desc, discipline
        ) as rn
    from v_advisor_discipline_history
)
select
    person_id,
    advisor_name,
    discipline,
    category,
    thesis_count,
    advisor_total,
    (count(*) filter (where thesis_count = max_count)
        over (partition by person_id)) > 1                as advisor_tied
from ranked
where rn = 1;

-- One suggested discipline per still-unclassified thesis, from a plurality
-- vote across its advisors' own top disciplines.
create or replace view v_thesis_discipline_advisor_suggestion as
with thesis_advisors as (
    select tp.thesis_id, tp.person_id, p.name as advisor_name
    from thesis_people tp
    join people p on p.id = tp.person_id
    join v_thesis_discipline u on u.thesis_id = tp.thesis_id
        and (u.unclassified or u.discipline like '%(ótilgreind)')
    where tp.role = 'advisor'
),
candidates as (
    select
        ta.thesis_id,
        ap.discipline,
        ap.category,
        count(distinct ta.person_id)        as advisor_votes,
        sum(ap.thesis_count)                as supporting_theses,
        array_agg(distinct ta.advisor_name) as advisors,
        bool_or(ap.advisor_tied)            as any_advisor_tied
    from thesis_advisors ta
    join v_advisor_discipline_plurality ap on ap.person_id = ta.person_id
    group by ta.thesis_id, ap.discipline, ap.category
),
ranked as (
    select
        *,
        row_number() over (
            partition by thesis_id
            order by advisor_votes desc, supporting_theses desc, discipline
        ) as rn,
        count(*) over (partition by thesis_id) as n_candidates
    from candidates
)
select
    thesis_id,
    discipline as suggested_discipline,
    category   as suggested_category,
    advisor_votes,
    supporting_theses,
    advisors,
    any_advisor_tied,
    n_candidates > 1 as advisors_disagree
from ranked
where rn = 1;


-- ---------------------------------------------------------------------------
-- Deildarlag (RQ0)
--
-- The two schools expose different things, so the unit is derived differently
-- for each -- which is itself the point of RQ0:
--
--   HR  -- study_category IS the department (MSc Tolvunarfraedideild, Dip
--          Taeknifraedideild, ...), so it is used directly in the view below.
--   HI  -- every VoN thesis lands in one collection and `faculty` is empty, so
--          the deild has to be inferred from the discipline. That is this table.
--
-- Department assignments confirmed by HI: Heilbrigdisverkfraedi belongs to RT;
-- Fjarmalaverkfraedi, Reikniverkfraedi and Hugbunadarverkfraedi to IVT.
-- ---------------------------------------------------------------------------

drop view if exists v_thesis_unit;
drop table if exists discipline_unit;

create table discipline_unit
(
    university varchar,
    discipline varchar,
    unit       varchar,
    unit_label varchar,
    in_core    boolean
);

create unique index discipline_unit_uq on discipline_unit (university, discipline);

insert into discipline_unit values
('Háskóli Íslands', 'Iðnaðarverkfræði',    'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Vélaverkfræði',       'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Tölvunarfræði',       'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Hugbúnaðarverkfræði', 'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Fjármálaverkfræði',   'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Mekatróník',          'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Ákvarðanaverkfræði',  'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Reikniverkfræði',     'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Gagnavísindi',        'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Máltækni',            'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Byggingarverkfræði',  'UMBYGG', 'Umhverfis- og byggingarverkfræðideild', true),
('Háskóli Íslands', 'Umhverfisverkfræði',  'UMBYGG', 'Umhverfis- og byggingarverkfræðideild', true),
('Háskóli Íslands', 'Framkvæmdastjórnun',  'UMBYGG', 'Umhverfis- og byggingarverkfræðideild', true),
('Háskóli Íslands', 'Skipulagsfræði og samgöngur', 'UMBYGG', 'Umhverfis- og byggingarverkfræðideild', true),
('Háskóli Íslands', 'Rafmagnsverkfræði',   'RT', 'Rafmagns- og tölvuverkfræðideild', true),
('Háskóli Íslands', 'Raforkuverkfræði',    'RT', 'Rafmagns- og tölvuverkfræðideild', true),
('Háskóli Íslands', 'Heilbrigðisverkfræði','RT', 'Rafmagns- og tölvuverkfræðideild', true),
('Háskóli Íslands', 'Tölvuverkfræði',      'RT', 'Rafmagns- og tölvuverkfræðideild', true),
('Háskóli Íslands', 'Stærðfræði',          'RAUN', 'Raunvísindadeild', false),
('Háskóli Íslands', 'Eðlisfræði',          'RAUN', 'Raunvísindadeild', false),
-- Engineering Physics: an engineering degree (its graduates get the verkfraedingur title, e.g.
-- 27933) hosted by the physical-sciences department: engineering scope, but not an engineering deild.
('Háskóli Íslands', 'Verkfræðileg eðlisfræði', 'RAUN', 'Raunvísindadeild', true),
('Háskóli Íslands', 'Efnafræði',           'RAUN', 'Raunvísindadeild', false),
('Háskóli Íslands', 'Tölfræði',            'RAUN', 'Raunvísindadeild', false),
('Háskóli Íslands', 'Jarðfræði',           'JARD', 'Jarðvísindadeild', false),
('Háskóli Íslands', 'Jarðeðlisfræði',      'JARD', 'Jarðvísindadeild', false),
('Háskóli Íslands', 'Jarðvísindi',         'JARD', 'Jarðvísindadeild', false),
('Háskóli Íslands', 'Jarðefnafræði',       'JARD', 'Jarðvísindadeild', false),
('Háskóli Íslands', 'Líffræði',            'LIF', 'Líf- og umhverfisvísindadeild', false),
-- 18738 and six more: Faculty of Life and Environmental Sciences (human-confirmed; the advisor,
-- tourism studies, is in the same faculty).
('Háskóli Íslands', 'Landupplýsinga- og umhverfisfræði', 'LIF', 'Líf- og umhverfisvísindadeild', false),
('Háskóli Íslands', 'Lífefnafræði',        'LIF', 'Líf- og umhverfisvísindadeild', false),
('Háskóli Íslands', 'Lífupplýsingafræði',  'LIF', 'Líf- og umhverfisvísindadeild', false),
('Háskóli Íslands', 'Líftækni',            'LIF', 'Líf- og umhverfisvísindadeild', false),
('Háskóli Íslands', 'Umhverfis- og auðlindafræði', 'LIF', 'Líf- og umhverfisvísindadeild', false),
('Háskóli Íslands', 'Landfræði',           'LIF', 'Líf- og umhverfisvísindadeild', false),
('Háskóli Íslands', 'Ferðamálafræði',      'LIF', 'Líf- og umhverfisvísindadeild', false),
('Háskóli Íslands', 'Orkuverkfræði',       'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Efnaverkfræði',       'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
-- Matvaela- og naeringarfraedideild heyrir undir Heilbrigdisvisindasvid, ekki
-- VoN. Sex ritgerdir eru krosstengdar inn i VoN-safnid, svo deildin er nefnd
-- hér til ad thaer teljist ekki oflokkadar -- en hun stendur utan sviđsins.
('Háskóli Íslands', 'Matvælafræði',        'MATV', 'Matvæla- og næringarfræðideild', false),
('Háskóli Íslands', 'Næringarfræði',       'MATV', 'Matvæla- og næringarfræðideild', false);

-- ---------------------------------------------------------------------------
-- Nafnavarp
--
-- Skemman geymir full nofn en toflur og myndir thurfa skammstafanir. Tha er
-- haldid hér, ekki i hverri fyrirspurn fyrir sig: 'case when university =
-- ''Haskoli Islands'' then ...' var aður endurtekid i hverjum kafla.
--
-- kind = 'university' eda 'unit'. Deildir HI eiga skammstofunina thegar i
-- discipline_unit.unit; hun er endurtekin hér svo eitt uppflettiborð dugi.
-- ---------------------------------------------------------------------------

drop table if exists org_short_name;

create table org_short_name
(
    kind       varchar,
    name       varchar,
    short_name varchar
);

create unique index org_short_name_uq on org_short_name (kind, name);

insert into org_short_name values
('university', 'Háskóli Íslands',       'HÍ'),
('university', 'Háskólinn í Reykjavík', 'HR'),
('unit', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', 'IVT'),
('unit', 'Umhverfis- og byggingarverkfræðideild',                   'UmBygg'),
('unit', 'Rafmagns- og tölvuverkfræðideild',                        'RT'),
('unit', 'Raunvísindadeild',                                        'Raun'),
('unit', 'Jarðvísindadeild',                                        'Jarð'),
('unit', 'Líf- og umhverfisvísindadeild',                           'Líf'),
('unit', 'Matvæla- og næringarfræðideild',                          'Matv'),
('unit', 'Verkfræðideild',                                          'Verkfr.'),
('unit', 'Tölvunarfræðideild',                                      'Tölv.'),
('unit', 'Iðnfræði (diplóma)',                                      'Iðnfr.'),
('unit', 'MPM',                                                     'MPM'),
('unit', 'Íþróttafræði',                                            'Íþr.');

create or replace view v_thesis_unit as
select
    d.*,
    us.short_name as university_short,
    case
        when d.university = 'Háskólinn í Reykjavík' then
            case
                when m.study_category like 'Dip %'                    then 'Iðnfræði (diplóma)'
                when d.discipline = 'Verkefnastjórnun'                then 'MPM'
                when d.discipline = 'Íþróttavísindi'                  then 'Íþróttafræði'
                when m.study_category like '%Tölvunarfræðideild%'     then 'Tölvunarfræðideild'
                when d.category = 'engineering'                       then 'Verkfræðideild'
                -- run by HR's Department of Engineering (per its title pages), though science
                when d.discipline = 'Sjálfbær orkuvísindi'            then 'Verkfræðideild'
                else 'Annað'
            end
        else coalesce(u.unit_label, '(óflokkað)')
    end as unit_label,
    case
        when d.university = 'Háskólinn í Reykjavík'
            then coalesce(m.study_category, '') not like 'Dip %'  -- NULL for old theses
                 and coalesce(d.discipline, '') not in ('Verkefnastjórnun', 'Íþróttavísindi')
                 and (d.category = 'engineering'
                      or coalesce(m.study_category, '') like '%Tölvunarfræðideild%')
        else coalesce(u.in_core, false)
    end as in_core
from v_thesis_discipline d
join v_thesis_msc m on m.thesis_id = d.thesis_id
left join discipline_unit u
       on u.university = d.university and u.discipline = d.discipline
left join org_short_name us
       on us.kind = 'university' and us.name = d.university;

-- Skammstofun deildar. Serstok syn thvi unit_label er reiknad i v_thesis_unit
-- og er thvi ekki adgengilegt i sama select.
create or replace view v_thesis_unit_named as
select
    t.*,
    coalesce(un.short_name, t.unit_label) as unit_short
from v_thesis_unit t
left join org_short_name un
       on un.kind = 'unit' and un.name = t.unit_label;