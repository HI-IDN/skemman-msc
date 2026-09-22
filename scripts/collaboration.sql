-- Per-thesis collaboration and funding signals, from scripts/load_collaboration.py (#11).
--
-- The heuristic layer only: regex and the config/organisations.yaml gazetteer over the
-- acknowledgements, preface and abstracts. It finds candidates and gives the baseline the
-- LLM step (#12) will be checked against. A match says an organisation is *named*, not that
-- it collaborated -- thanks alone is not collaboration, and that distinction is the LLM's job.
--
--   duckdb data/processed/thesis.db < scripts/collaboration.sql

-- Cue order, strongest first: see _CUES in scripts/load_collaboration.py.
create or replace macro cue_rank(cue) as
    case cue when 'collaboration' then 1 when 'supervision' then 2
             when 'data' then 3 when 'funding' then 4 else 5 end;

-- One row per thesis and named external organisation, with where it was named and the
-- strongest cue any front-matter sentence naming it carries.
create or replace view v_thesis_org as
select
    s.thesis_id,
    o.org_key,
    o.name,
    o.sector,
    count(*) as n_mentions,
    arg_min(s.cue, cue_rank(s.cue)) filter (where s.section not like 'abstract%') as best_cue,
    bool_or(s.section in ('acknowledgements', 'preface', 'thanks_fallback')) as in_frontmatter,
    bool_or(s.section like 'abstract%') as in_abstract
from thesis_org_signal s
join organisation o using (org_key)
where s.kind = 'known_org' and o.external
group by all;

-- One row per thesis in the population. `evidence` is the heuristic's verdict, weakest last.
-- Organisations count only where the front matter names them: an abstract that mentions
-- Landsvirkjun is usually about Landsvirkjun's power plants, not written with Landsvirkjun.
--   named_partner     front matter names a company, public company or agency, or a company
--                     by its suffix -- the RQ4 sense of collaboration. How strongly is in
--                     `partner_strength`:
--                       involved  a partner's own sentence says it collaborated, hosted,
--                                 supervised, or provided data or material
--                       funded    ... says only that it paid
--                       thanked   ... says neither: named in thanks, nothing more
--                     A cue is a word in the same sentence, not a reading of it; the LLM
--                     step (#12) is what reads it.
--   funding_only      front matter names a fund or an international funder (EU, UNU-GTP)
--                     or uses funding wording, and nothing more
--   academic_only     front matter names only a university or research centre abroad
--   wording_only      collaboration wording ("in collaboration with") but no organisation
--   abstract_mention  an external organisation named only in the abstract -- mostly a topic
--   none_found        front matter read, nothing found
--   no_frontmatter    text on disk but no acknowledgements or preface found; abstract only
--   no_text           no open PDF text at all; abstract only
create or replace view v_thesis_collaboration as
with sig as (
    -- Collaboration wording counts wherever it is: "this thesis was carried out at" in an
    -- abstract is about the thesis itself. Suffixes and funding wording in an abstract are
    -- mostly topic ("the company's funding model"), so only the front matter's count.
    select
        thesis_id,
        bool_or(kind = 'org_suffix' and section not like 'abstract%')     as has_org_suffix,
        bool_or(kind = 'collab_phrase')                                   as has_collab_phrase,
        bool_or(kind = 'funding_phrase' and section not like 'abstract%') as has_funding_phrase
    from thesis_org_signal
    group by thesis_id
),
org as (
    select
        thesis_id,
        count(*) as n_orgs,
        bool_or(sector = 'private')        as has_private,
        bool_or(sector = 'public_company') as has_public_company,
        bool_or(sector = 'public_agency')  as has_public_agency,
        bool_or(sector = 'research_fund')  as has_research_fund,
        bool_or(sector = 'international')  as has_international,
        bool_or(sector = 'university')     as has_university,
        bool_or(sector in ('private', 'public_company', 'public_agency')) as has_partner,
        string_agg(name, '; ' order by name) as orgs
    from v_thesis_org
    where in_frontmatter
    group by thesis_id
),
abstract_org as (
    select thesis_id, string_agg(name, '; ' order by name) as abstract_orgs
    from v_thesis_org
    where not in_frontmatter
    group by thesis_id
),
partner as (
    -- Front-matter mentions of a partner: a listed company or agency, or any company by its
    -- suffix. Their strongest cue decides partner_strength.
    select thesis_id, min(cue_rank(cue)) as best_rank
    from thesis_org_signal s
    left join organisation o using (org_key)
    where s.section not like 'abstract%'
      and (s.kind = 'org_suffix'
           or (s.kind = 'known_org' and o.external
               and o.sector in ('private', 'public_company', 'public_agency')))
    group by thesis_id
),
sec as (
    select
        thesis_id,
        bool_or(section in ('acknowledgements', 'preface', 'thanks_fallback')) as has_frontmatter
    from thesis_section
    group by thesis_id
)
select
    m.thesis_id,
    m.university,
    m.yr,
    coalesce(t.has_text, false)                   as has_text,
    coalesce(sec.has_frontmatter, false)          as has_frontmatter,
    coalesce(org.n_orgs, 0)                       as n_orgs,
    org.orgs,
    abstract_org.abstract_orgs,
    coalesce(org.has_private, false)              as has_private,
    coalesce(org.has_public_company, false)       as has_public_company,
    coalesce(org.has_public_agency, false)        as has_public_agency,
    coalesce(org.has_research_fund, false)        as has_research_fund,
    coalesce(org.has_international, false)       as has_international,
    coalesce(org.has_university, false)          as has_university,
    coalesce(sig.has_org_suffix, false)           as has_org_suffix,
    coalesce(sig.has_collab_phrase, false)        as has_collab_phrase,
    coalesce(sig.has_funding_phrase, false)       as has_funding_phrase,
    case
        when org.has_partner or sig.has_org_suffix            then 'named_partner'
        when org.has_research_fund or org.has_international
             or sig.has_funding_phrase                        then 'funding_only'
        when org.has_university                               then 'academic_only'
        when sig.has_collab_phrase                            then 'wording_only'
        when abstract_org.abstract_orgs is not null           then 'abstract_mention'
        when sec.has_frontmatter                              then 'none_found'
        when t.has_text                                       then 'no_frontmatter'
        else 'no_text'
    end as evidence,
    case
        when partner.best_rank <= 3 then 'involved'
        when partner.best_rank = 4  then 'funded'
        when partner.best_rank = 5  then 'thanked'
    end as partner_strength
from v_thesis_msc m
left join sec using (thesis_id)
left join org using (thesis_id)
left join abstract_org using (thesis_id)
left join sig using (thesis_id)
left join partner using (thesis_id)
left join thesis_text_read t using (thesis_id);
