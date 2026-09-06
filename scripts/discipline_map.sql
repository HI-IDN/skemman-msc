-- Discipline mapping for RQ2/RQ3.
--
-- Neither university exposes a department field in the Skemman item metadata:
-- HÍ files every thesis under "Meistaraprófsritgerðir - Verkfræði- og
-- náttúruvísindasvið" and HR under a handful of broad department collections.
-- The only per-thesis discipline signal is the subject keyword list, where both
-- schools tag the námsgrein (Vélaverkfræði, Tölvunarfræði, ...).
--
-- This file seeds a keyword -> discipline lookup. A thesis takes the discipline
-- of its lowest-priority matching keyword. `is_engineering` defines the
-- population boundary for issue #1 -- the boundary calls are flagged below.
--
--   duckdb data/processed/thesis.db < scripts/discipline_map.sql

create table if not exists discipline_keyword
(
    keyword_norm   varchar,
    discipline     varchar,
    is_engineering boolean,
    priority       integer default 100
);

create unique index if not exists discipline_keyword_uq on discipline_keyword (keyword_norm);

delete from discipline_keyword;

insert into discipline_keyword (keyword_norm, discipline, is_engineering, priority) values
-- Mechanical / mechatronics
('vélaverkfræði',                  'Vélaverkfræði',              true, 10),
('mechanical engineering',         'Vélaverkfræði',              true, 10),
('mechatronics engineering',       'Vélaverkfræði',              true, 10),
('hátækniverkfræði',               'Vélaverkfræði',              true, 10),

-- Civil / environmental / structural
('byggingarverkfræði',             'Byggingarverkfræði',         true, 10),
('civil engineering',              'Byggingarverkfræði',         true, 10),
('umhverfis- og byggingarverkfræði','Byggingarverkfræði',        true, 10),
('mannvirkjagerð',                 'Byggingarverkfræði',         true, 30),
('umhverfisverkfræði',             'Umhverfisverkfræði',         true, 10),

-- Industrial / operations / financial engineering
('iðnaðarverkfræði',               'Iðnaðarverkfræði',           true, 10),
('industrial engineering',         'Iðnaðarverkfræði',           true, 10),
('rekstrarverkfræði',              'Rekstrarverkfræði',          true, 10),
('engineering management',         'Rekstrarverkfræði',          true, 10),
('fjármálaverkfræði',              'Fjármálaverkfræði',          true, 10),
('financial engineering',          'Fjármálaverkfræði',          true, 10),
('ákvarðanaverkfræði',             'Iðnaðarverkfræði',           true, 20),

-- Project management (HR's MPM -- a professional master's, see note below)
('verkefnastjórnun',               'Verkefnastjórnun',           true, 15),
('project management',             'Verkefnastjórnun',           true, 15),
('master of project management',   'Verkefnastjórnun',           true, 15),
('mpm',                            'Verkefnastjórnun',           true, 15),

-- Electrical / power
('rafmagnsverkfræði',              'Rafmagnsverkfræði',          true, 10),
('electrical engineering',         'Rafmagnsverkfræði',          true, 10),
('rafmagns- og tölvuverkfræði',    'Rafmagnsverkfræði',          true, 10),
('raforkuverkfræði',               'Rafmagnsverkfræði',          true, 10),
('electric power engineering',     'Rafmagnsverkfræði',          true, 10),

-- Computing
('tölvunarfræði',                  'Tölvunarfræði',              true, 10),
('computer science',               'Tölvunarfræði',              true, 10),
('tölvufræði',                     'Tölvunarfræði',              true, 20),
('hugbúnaðarverkfræði',            'Hugbúnaðarverkfræði',        true, 10),
('software engineering',           'Hugbúnaðarverkfræði',        true, 10),
('hugbúnaðargerð',                 'Hugbúnaðarverkfræði',        true, 20),
('software development',           'Hugbúnaðarverkfræði',        true, 20),
('reikniverkfræði',                'Reikniverkfræði',            true, 10),

-- Energy
('orkuverkfræði',                  'Orkuverkfræði',              true, 10),
('sustainable energy engineering', 'Orkuverkfræði',              true, 10),
('orkuvísindi',                    'Orkuvísindi',                true, 12),
('sustainable energy',             'Orkuvísindi',                true, 12),
('sustainable energy sciences',    'Orkuvísindi',                true, 12),
('sustainable energy science',     'Orkuvísindi',                true, 12),

-- Biomedical / bioengineering
('heilbrigðisverkfræði',           'Heilbrigðisverkfræði',       true, 10),
('biomedical engineering',         'Heilbrigðisverkfræði',       true, 10),
('lífverkfræði',                   'Heilbrigðisverkfræði',       true, 20),

-- Data science / language technology
('gagnavísindi',                   'Gagnavísindi',               true, 10),
('data science',                   'Gagnavísindi',               true, 10),
('máltækni',                       'Máltækni',                   true, 10),
('gervigreind og máltækni',        'Máltækni',                   true, 12),
('language technology',            'Máltækni',                   true, 10),

-- Construction management (HR)
('framkvæmdastjórnun',             'Framkvæmdastjórnun',         true, 15),
('construction management',        'Framkvæmdastjórnun',         true, 15),

-- Energy, additional spellings
('sjálfbær orkuvísindi - reyst',   'Orkuvísindi',                true, 12),
('sjálfbær orkuvísindi',           'Orkuvísindi',                true, 12),

-- BOUNDARY CALLS -- review these two. Both are arguably outside "verkfræði og
-- tæknigreinar" but both are technical programmes. Flip is_engineering to false
-- if the population should be narrower.
('rafiðnfræði',                    'Rafiðnfræði',                true, 15),
('skipulagsfræði og samgöngur',    'Skipulagsfræði og samgöngur', true, 15),
('samgöngur',                      'Skipulagsfræði og samgöngur', true, 25),

-- Generic engineering fallback
('verkfræði',                      'Verkfræði (ótilgreind)',     true, 90),
('engineering',                    'Verkfræði (ótilgreind)',     true, 90),

-- Explicitly NOT engineering: HÍ's listing is the whole Verkfræði- og
-- náttúruvísindasvið, so the natural sciences have to be excluded by name.
('líffræði',                       'Líffræði',                   false, 10),
('líffræði (námsgrein)',           'Líffræði',                   false, 10),
('sjávarlíffræði',                 'Líffræði',                   false, 15),
('lífefnafræði',                   'Lífefnafræði',               false, 10),
('lífupplýsingafræði',             'Lífupplýsingafræði',         false, 10),
('jarðfræði',                      'Jarðfræði',                  false, 10),
('jarðfræði (námsgrein)',          'Jarðfræði',                  false, 10),
('jarðeðlisfræði',                 'Jarðeðlisfræði',             false, 10),
('jarðvísindi',                    'Jarðvísindi',                false, 15),
('jarðefnafræði',                  'Jarðefnafræði',              false, 15),
('efnafræði',                      'Efnafræði',                  false, 10),
('efnafræði (námsgrein)',          'Efnafræði',                  false, 10),
('eðlisfræði',                     'Eðlisfræði',                 false, 10),
('stærðfræði',                     'Stærðfræði',                 false, 10),
('tölfræði',                       'Tölfræði',                   false, 15),
('hagnýt tölfræði',                'Tölfræði',                   false, 15),
('landfræði',                      'Landfræði',                  false, 10),
('landfræði (námsgrein)',          'Landfræði',                  false, 10),
('ferðamálafræði',                 'Ferðamálafræði',             false, 10),
('umhverfis- og auðlindafræði',    'Umhverfis- og auðlindafræði',false, 10),
('umhverfisfræði',                 'Umhverfis- og auðlindafræði',false, 15),
('íþróttavísindi og þjálfun',      'Íþróttavísindi',             false, 10),
('exercise science and coaching',  'Íþróttavísindi',             false, 10),
('skammtafræði',                   'Eðlisfræði',                 false, 20),
('iðnaðarlíftækni',                'Líftækni',                   false, 15),
('sameindalíffræði',               'Líffræði',                   false, 15),
('landafræði',                     'Landfræði',                  false, 10),
('eðlisfræði (námsgrein)',         'Eðlisfræði',                 false, 10),
('stærðfræði (námsgrein)',         'Stærðfræði',                 false, 10),
('umhverfis- og auðlindafræði (námsgrein)', 'Umhverfis- og auðlindafræði', false, 10),
('menntun framhaldsskólakennara',  'Menntavísindi',              false, 10),
('heilsuþjálfun og kennsla',       'Íþróttavísindi',             false, 12);

-- One discipline per thesis: the lowest-priority matching keyword wins, ties
-- broken alphabetically so the assignment is deterministic.
create or replace view v_thesis_discipline as
with matches as (
    select
        tk.thesis_id,
        d.discipline,
        d.is_engineering,
        row_number() over (
            partition by tk.thesis_id
            order by d.priority, d.discipline
        ) as rn
    from thesis_keywords tk
    join keywords k on k.id = tk.keyword_id
    join discipline_keyword d on d.keyword_norm = k.keyword_norm
)
select
    m.thesis_id,
    year(t.date_accepted) as yr,
    m.university,
    m.degree_level,
    x.discipline,
    coalesce(x.is_engineering, false) as is_engineering,
    x.discipline is null as unclassified
from thesis_metadata m
join thesis t on t.id = m.thesis_id
left join matches x on x.thesis_id = m.thesis_id and x.rn = 1;
