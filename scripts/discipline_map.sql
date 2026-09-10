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
-- boundary for issue #1, in four tiers:
--
--   engineering  -- core verkfrædi/taeknigreinar, always in scope
--   professional -- professional master's adjacent to engineering (MPM). In
--                   scope for the broad population, out for the strict one:
--                   report both rather than picking one.
--   applied      -- idnfraedi: HR's applied-engineering diplomas. Out of the
--                   engineering population, kept separate so HR's mix stays visible.
--   science      -- natural, earth and social sciences. HI's listing is the
--                   whole Verkfraedi- og natturuvisindasvid, so these have to
--                   be excluded by name.
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
    priority       integer default 100
);

create unique index discipline_keyword_uq on discipline_keyword (keyword_norm);

insert into discipline_keyword (keyword_norm, discipline, category, priority) values
-- Mechanical / mechatronics
('vélaverkfræði',                  'Vélaverkfræði',              'engineering', 10),
('mechanical engineering',         'Vélaverkfræði',              'engineering', 10),
('mechatronics engineering',       'Vélaverkfræði',              'engineering', 10),
('hátækniverkfræði',               'Vélaverkfræði',              'engineering', 10),

-- Chemical / biochemical engineering
('efnaverkfræði',                  'Efnaverkfræði',              'engineering', 10),
('chemical engineering',           'Efnaverkfræði',              'engineering', 10),
('lífefnaverkfræði',               'Efnaverkfræði',              'engineering', 15),

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
('ákvarðanaverkfræði',             'Iðnaðarverkfræði',           'engineering', 20),

-- Project management (HR's MPM -- a professional master's, see note below)
('verkefnastjórnun',               'Verkefnastjórnun',           'professional', 15),
('project management',             'Verkefnastjórnun',           'professional', 15),
('master of project management',   'Verkefnastjórnun',           'professional', 15),
('mpm',                            'Verkefnastjórnun',           'professional', 15),

-- Electrical / power
('rafmagnsverkfræði',              'Rafmagnsverkfræði',          'engineering', 10),
('electrical engineering',         'Rafmagnsverkfræði',          'engineering', 10),
('rafmagns- og tölvuverkfræði',    'Rafmagnsverkfræði',          'engineering', 10),
('raforkuverkfræði',               'Rafmagnsverkfræði',          'engineering', 10),
('electric power engineering',     'Rafmagnsverkfræði',          'engineering', 10),
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
('sustainable energy sciences',    'Orkuverkfræði',              'engineering', 12),
('sustainable energy science',     'Orkuverkfræði',              'engineering', 12),

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

-- Construction management -- a professional master's like MPM, not a
-- verkfraedi degree, so it sits in the same category.
('framkvæmdastjórnun',             'Framkvæmdastjórnun',         'professional', 15),
('construction management',        'Framkvæmdastjórnun',         'professional', 15),

-- Energy, additional spellings
('sjálfbær orkuvísindi - reyst',   'Orkuverkfræði',              'engineering', 12),
('sjálfbær orkuvísindi',           'Orkuverkfræði',              'engineering', 12),

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
('jarðeðlisfræði',                 'Jarðeðlisfræði',             'science', 10),
('jarðvísindi',                    'Jarðvísindi',                'science', 15),
('jarðefnafræði',                  'Jarðefnafræði',              'science', 15),
('efnafræði',                      'Efnafræði',                  'science', 10),
('lífræn efnafræði',               'Efnafræði',                  'science', 12),
('ólífræn efnafræði',              'Efnafræði',                  'science', 12),
('eðlisfræði',                     'Eðlisfræði',                 'science', 10),
('stærðfræði',                     'Stærðfræði',                 'science', 10),
('tölfræði',                       'Tölfræði',                   'science', 15),
('hagnýt tölfræði',                'Tölfræði',                   'science', 15),
('landfræði',                      'Landfræði',                  'science', 10),
('ferðamálafræði',                 'Ferðamálafræði',             'science', 10),
('umhverfis- og auðlindafræði',    'Umhverfis- og auðlindafræði','science', 10),
('umhverfisfræði',                 'Umhverfis- og auðlindafræði','science', 15),
('íþróttavísindi og þjálfun',      'Íþróttavísindi',             'science', 10),
('exercise science and coaching',  'Íþróttavísindi',             'science', 10),
('skammtafræði',                   'Eðlisfræði',                 'science', 20),
('iðnaðarlíftækni',                'Líftækni',                   'science', 15),
('sameindalíffræði',               'Líffræði',                   'science', 15),
('landafræði',                     'Landfræði',                  'science', 10),
('verkfræðileg eðlisfræði',        'Eðlisfræði',                 'science', 12),
('stjarneðlisfræði',               'Eðlisfræði',                 'science', 15),
('lífeðlisfræði',                  'Eðlisfræði',                 'science', 15),
('hljóðeðlisfræði',                'Eðlisfræði',                 'science', 15),
('menntun framhaldsskólakennara',  'Menntavísindi',              'science', 10),
('matvælafræði',                   'Matvælafræði',               'science', 10),
('næringarfræði',                  'Næringarfræði',              'science', 10),
('heilsuþjálfun og kennsla',       'Íþróttavísindi',             'science', 12);

-- One discipline per thesis: the FIRST matching keyword in Skemman's own subject
-- order wins. Both schools list the namsgrein first and topical terms after, so
-- sort_order carries real signal; `priority` only breaks ties within one
-- position. The earlier rule ordered by priority and fell back to alphabetical,
-- which was arbitrary -- "Idnadarverkfraedi; Fjarmalaverkfraedi; ..." was filed
-- under Fjarmalaverkfraedi purely because F sorts before I.
create or replace view v_thesis_discipline as
with matches as (
    select
        tk.thesis_id,
        d.discipline,
        d.category,
        row_number() over (
            partition by tk.thesis_id
            order by tk.sort_order, d.priority, d.discipline
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
    x.category = 'engineering' as is_engineering,
    x.category in ('engineering', 'professional') as in_scope_broad,
    x.discipline is null as unclassified
from v_thesis_msc m
left join matches x on x.thesis_id = m.thesis_id and x.rn = 1;


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
('Háskóli Íslands', 'Reikniverkfræði',     'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Gagnavísindi',        'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Máltækni',            'IVT', 'Iðnaðarverkfræði-, vélaverkfræði- og tölvunarfræðideild', true),
('Háskóli Íslands', 'Byggingarverkfræði',  'UMBYGG', 'Umhverfis- og byggingarverkfræðideild', true),
('Háskóli Íslands', 'Umhverfisverkfræði',  'UMBYGG', 'Umhverfis- og byggingarverkfræðideild', true),
('Háskóli Íslands', 'Framkvæmdastjórnun',  'UMBYGG', 'Umhverfis- og byggingarverkfræðideild', true),
('Háskóli Íslands', 'Skipulagsfræði og samgöngur', 'UMBYGG', 'Umhverfis- og byggingarverkfræðideild', true),
('Háskóli Íslands', 'Rafmagnsverkfræði',   'RT', 'Rafmagns- og tölvuverkfræðideild', true),
('Háskóli Íslands', 'Heilbrigðisverkfræði','RT', 'Rafmagns- og tölvuverkfræðideild', true),
('Háskóli Íslands', 'Tölvuverkfræði',      'RT', 'Rafmagns- og tölvuverkfræðideild', true),
('Háskóli Íslands', 'Stærðfræði',          'RAUN', 'Raunvísindadeild', false),
('Háskóli Íslands', 'Eðlisfræði',          'RAUN', 'Raunvísindadeild', false),
('Háskóli Íslands', 'Efnafræði',           'RAUN', 'Raunvísindadeild', false),
('Háskóli Íslands', 'Tölfræði',            'RAUN', 'Raunvísindadeild', false),
('Háskóli Íslands', 'Jarðfræði',           'JARD', 'Jarðvísindadeild', false),
('Háskóli Íslands', 'Jarðeðlisfræði',      'JARD', 'Jarðvísindadeild', false),
('Háskóli Íslands', 'Jarðvísindi',         'JARD', 'Jarðvísindadeild', false),
('Háskóli Íslands', 'Jarðefnafræði',       'JARD', 'Jarðvísindadeild', false),
('Háskóli Íslands', 'Líffræði',            'LIF', 'Líf- og umhverfisvísindadeild', false),
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
                else 'Annað'
            end
        else coalesce(u.unit_label, '(óflokkað)')
    end as unit_label,
    case
        when d.university = 'Háskólinn í Reykjavík'
            then m.study_category not like 'Dip %'
                 and coalesce(d.discipline, '') not in ('Verkefnastjórnun', 'Íþróttavísindi')
                 and (d.category = 'engineering' or m.study_category like '%Tölvunarfræðideild%')
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