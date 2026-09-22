"""Find the front-matter passages where a thesis names outside organisations, and flag them.

Issue #11. `sponsor` is empty for every engineering master's thesis, so whether a thesis was
done with, for, or funded by an outside party has to be read off the text: the
acknowledgements and preface above all, which the title-page step already has on disk as the
first pages of each open PDF (data/raw/pdf_text/). This script does no network and no LLM:

  1. Bounds each thesis's acknowledgements / preface section in the cached text, falling back
     to the first "I would like to thank" / "Ég vil þakka" paragraph when there is no heading.
  2. Flags generic signals in those sections and in the abstracts: company-form suffixes
     (ehf., hf., GmbH, Ltd ...), collaboration wording, funding wording, and organisations
     named in config/organisations.yaml.

  3. For each advisor, reads where they work: off the title page's advisor block (HR states
     position and employer; HÍ mostly names alone), or from the acknowledgements, where the
     employer is often named beside them. Examiners are not advisors and are left out.

Writes five tables, replaced on every run:

  thesis_section              one row per bounded passage -- the input the LLM step (#12) reads
  thesis_text_read            whether the thesis had cached PDF text to search at all
  thesis_org_signal           one row per match, with its surrounding text as evidence
  thesis_advisor_affiliation  one row per thesis and advisor: academic, outside, or unknown
  organisation                config/organisations.yaml, flattened

scripts/collaboration.sql builds the per-thesis views on top.

  python scripts/load_collaboration.py [--db data/processed/thesis.db] [--text-dir data/raw/pdf_text]
"""
import argparse
import re
import unicodedata
from pathlib import Path

import duckdb
import pandas as pd
import yaml

ROOT = Path(__file__).resolve().parent.parent

# The title-page cache opens with "%%PAGES\t<total>\t<kept>"; see skemman-harvester.
PAGE_MARKER = "%%PAGES"

# Longest passage kept per section. A real acknowledgements page is well under this; a
# section whose end heading was never found would otherwise run into chapter one.
MAX_SECTION = 3000

UPPER = "A-ZÁÉÍÓÚÝÞÆÖÐ"

# --- section headings -------------------------------------------------------------

# A heading, optionally numbered ("III. Þakkir", "1 Preface"), optionally followed by a
# period or colon. "Acknowledg..." is distinctive enough to accept with the text running on
# after it on the same line, which pypdf often produces ("ACKNOWLEDGEMENTS I would like to");
# the plainer words must stand alone on their line, or every "Thanks to the variety of ..."
# in the body would open a section.
_NUM = r"(?:[IVX]+\.|\d+\.?)?\s*"
_ACK_HEAD = re.compile(
    rf"(?im)^[ \t]*{_NUM}(?P<head>acknowledge?ments?|acknowledgement)\b[.:]?[ \t]*(?P<rest>.*)$"
)
_OTHER_HEAD = re.compile(
    rf"(?im)^[ \t]*{_NUM}(?P<head>þakkarorð|þakkir|formáli|preface|foreword|thanks)[.:]?[ \t]*$"
)
# A table-of-contents line: the heading followed only by dot leaders and a page number.
_TOC_REST = re.compile(r"(?i)^[\s.…·_]*[ivxlc\d]*\s*$")
_TOC_LEADERS = re.compile(r"\.{4,}|(?:\. ){4,}")

# What ends a front-matter section: the next front-matter or first-chapter heading.
_END = re.compile(
    r"(?im)^[ \t]*(?:[IVX]+\.|\d+\.?)?\s*(?:"
    r"contents|table of contents|efnisyfirlit|yfirlit|list of (?:figures|tables|abbreviations)"
    r"|myndaskrá|myndalisti|töfluskrá|nomenclature|abbreviations|skammstafanir|notation"
    r"|introduction|inngangur|chapter\s+1|abstract|útdráttur|ágrip|declaration|yfirlýsing"
    r"|dedication|tileinkun"
    r")\b"
)

# No heading at all: the first sentence that reads as thanks, not as "thanks to X" in the
# body. First person, a verb of thanking, in either language.
_THANKS = re.compile(
    r"(?i)\bI (?:would|wish|want) (?:also )?(?:like )?to (?:thank|express|acknowledge|extend)"
    r"|\bI am (?:very |deeply |most )?(?:grateful|thankful|indebted)"
    r"|\b(?:ég|við) vil(?:ja|jum)? (?:\w+ )?(?:þakka|færa|koma)"
    r"|\bvil (?:ég|við) (?:\w+ )?(?:þakka|færa)"
    r"|\bhöfundur vill"
    r"|\bspecial thanks\b"
)

SECTION_KIND = {
    "acknowledgement": "acknowledgements", "acknowledgements": "acknowledgements",
    "acknowledgment": "acknowledgements", "acknowledgments": "acknowledgements",
    "þakkarorð": "acknowledgements", "þakkir": "acknowledgements", "thanks": "acknowledgements",
    "formáli": "preface", "preface": "preface", "foreword": "preface",
}

# --- signals ------------------------------------------------------------------------

# A company form after one to four capitalised words: "Spennubreytar ehf.", "Verkís hf",
# "Volvo Group Trucks Technology AB". The name is what the LLM step and the gazetteer need.
_SUFFIX = re.compile(
    rf"(?P<name>(?:[{UPPER}0-9][\w&.'\-]*\s+){{1,4}})"
    r"(?P<suffix>ehf|ohf|hf|slf|sf|GmbH|Ltd|Inc|LLC|AB|A/S|ApS|AS|Oy|B\.V|S\.A|plc|Corp)"
    r"(?=[.,;:)\s]|$)"
)
# Publishers named in a copyright or permissions note, not partners.
_PUBLISHER = re.compile(r"(?i)publish|press\b|education|sons\b|wiley|springer|elsevier")
# The thesis itself done with, at, or for someone -- not a cited study's collaboration.
_COLLAB = re.compile(
    r"(?i)\b(?:in (?:close )?(?:collaboration|cooperation|co-operation|partnership) with"
    r"|carried out (?:at|in|for|with)|conducted (?:at|in|for|with)|performed at"
    r"|(?:done|written|developed) (?:at|for|in collaboration)"
    r"|made possible by|(?:carry|carried) out (?:this|the) (?:work|project|thesis) at"
    r"|(?:colleagues|staff|employees|team|engineers|everyone|people) (?:at|of) (?-i:[A-Z])"
    r"|internship|on behalf of|commissioned by|provided (?:by|the) data|data (?:was |were )?provided"
    r"|í samstarfi við|í samvinnu við|unni[nð] (?:hjá|fyrir|í samstarfi|í samvinnu)"
    r"|fyrir hönd|lögðu til gögn|útveguðu gögn|lét í té|létu í té)"
)
_FUNDING = re.compile(
    r"(?i)\b(?:grant(?:ed)?|funded|funding|financial(?:ly)? support(?:ed)?|scholarship"
    r"|fellowship|sponsor\w*|styrk\w*|aðalstyrk\w*|fjármagna\w*|sjóð\w*|rann[ií]s)\b"
)

# What the sentence that names an organisation says the organisation did, strongest first.
# This grades a mention, it does not prove anything: "Research Engineer X at General Motors
# for his advice" is a supervision cue on one person's advice. The LLM step (#12) is what
# reads the sentence; this is the transparent rule it gets checked against.
#   collaboration  the work was done with, at or for the organisation, or on its premises
#   supervision    someone at the organisation advised or supervised
#   data           the organisation provided data, measurements, material or information
#   funding        the organisation paid: a grant, scholarship, salary or sponsorship
_CUES = [
    ("collaboration", re.compile(
        r"(?i)collaborat\w*|cooperat\w*|co-operat\w*|partner\w*|carried out|conducted at"
        r"|made possible|internship|facilit\w*|premises|workplace|workspace|lab(?:oratory)?\b"
        r"|equipment|work on (?:this|the) project"
        r"|employer|work(?:ed|ing)? (?:at|for|with|under)|opportunity to work|(?:student|summer) job"
        r"|job at|co-?workers|colleagues|in cooperation"
        r"|(?:help|assistance) (?:with|on) (?:the |this |my )?(?:project|work|thesis)"
        r"|samstarf\w*|samvinn\w*|aðstöð\w*|búnað\w*|vinnuveitand\w*|starfsnám\w*|rannsóknarstof\w*"
        r"|samstarfsfélag\w*|vinnufélag\w*|unni[nð] (?:hjá|fyrir)|aðstoð\w* við (?:\w+ )?verkefni\w*"
    )),
    ("supervision", re.compile(
        r"(?i)supervis\w*|advis(?:or|er|ors|ers|ing|ed|e)\b|advice|guidance|mentor\w*"
        # Lower case only: "VSÓ Ráðgjöf" is a company name, not advice.
        r"|leiðbein\w*|leiðsögn\w*|(?-i:ráðgjöf)\w*|ráðlegging\w*"
    )),
    ("data", re.compile(
        r"(?i)\bdata\b|dataset\w*|measurement\w*|information|material\w*|samples?\b|access to"
        r"|images?\b|drawings?\b|teikning\w*|myndir\b|myndum\b"
        r"|gögn\w*|gagna\w*|upplýsing\w*|mæling\w*|aðgang\w*"
    )),
    ("funding", _FUNDING),
]
# For _sentence(): a stop, then whitespace and a capital.
_SENTENCE_END = re.compile(rf"(?P<word>\w+)[.!?]\s+(?=[{UPPER}])")
_ABBREVIATIONS = {"dr", "prof", "mr", "ms", "mrs", "st", "no", "nr", "ehf", "hf", "ohf", "sf",
                  "slf", "inc", "ltd", "co", "corp", "e.g", "i.e", "etc", "dept", "sr", "jr"}


def read_text(path: Path) -> str:
    raw = path.read_text(encoding="utf-8", errors="replace")
    if raw.startswith(PAGE_MARKER):
        raw = raw.partition("\n")[2]
    return raw


def _is_toc(line_rest: str, after: str) -> bool:
    """A heading that is really an entry in the table of contents."""
    if _TOC_REST.match(line_rest) and line_rest.strip():
        return True
    return bool(_TOC_LEADERS.search(line_rest)) or bool(_TOC_LEADERS.search(after[:200]))


def _cut(text: str, start: int) -> str:
    body = text[start:start + MAX_SECTION + 200]
    # Skip the first line: an inline heading ("Acknowledgements I would ...") would otherwise
    # be ended by nothing, and a stray "Abstract" in it would end the section at once.
    first_nl = body.find("\n")
    search_from = first_nl + 1 if first_nl >= 0 else len(body)
    end = _END.search(body, search_from)
    body = body[:end.start()] if end else body[:MAX_SECTION]
    return re.sub(r"[ \t]*\n[ \t]*", "\n", body).strip()[:MAX_SECTION]


def sections(text: str) -> list[tuple[str, str, str]]:
    """(section, heading as found, text) for every front-matter passage in the text."""
    found: list[tuple[int, str, str]] = []
    for m in _ACK_HEAD.finditer(text):
        if _is_toc(m.group("rest"), text[m.end():m.end() + 200]):
            continue
        found.append((m.start(), m.group("head"), m.group("rest")))
    for m in _OTHER_HEAD.finditer(text):
        if _is_toc("", text[m.end():m.end() + 200]):
            continue
        found.append((m.start(), m.group("head"), ""))

    out: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for pos, head, _ in sorted(found):
        kind = SECTION_KIND[head.lower()]
        # Headings, not the running header that repeats "Acknowledgements" on every page of a
        # long section: keep the first of each kind.
        if kind in seen:
            continue
        body = _cut(text, pos)
        if len(body) < 40:  # a heading with nothing under it -- usually a stray page header
            continue
        seen.add(kind)
        out.append((kind, head, body))

    if "acknowledgements" not in seen:
        m = _THANKS.search(text)
        if m:
            # Back to the start of the paragraph the thanks opens.
            start = max(text.rfind("\n\n", 0, m.start()), text.rfind("\n", 0, max(0, m.start() - 300)))
            out.append(("thanks_fallback", "", _cut(text, max(0, start))))
    return out


def load_organisations(path: Path) -> tuple[list[dict], re.Pattern | None]:
    """The gazetteer, and one regex that finds every organisation in it.

    One alternation with a named group per organisation, not a regex each: sixty patterns that
    open with a lookbehind cost Python a full character-by-character scan apiece, about a
    minute and a half over the population, where one scan takes seconds. It also settles
    overlaps for free -- matches never overlap, the leftmost wins, and at the same position the
    entry listed first in the YAML wins.
    """
    if not path.exists():
        return [], None
    orgs = yaml.safe_load(path.read_text(encoding="utf-8")).get("organisations") or []
    if not orgs:
        return [], None
    # The name matches literally; each alias is a regular expression. Both must stand as whole
    # words. Case matters: "Efla" the company, not "efla" the verb.
    groups = []
    for o in orgs:
        patterns = [re.escape(o["name"])] + list(o.get("aliases") or [])
        groups.append(f"(?P<{o['key']}>{'|'.join(patterns)})")
    return orgs, re.compile(rf"(?<!\w)(?:{'|'.join(groups)})(?!\w)")


def _context(text: str, start: int, end: int, width: int = 120) -> str:
    return re.sub(r"\s+", " ", text[max(0, start - width):end + width]).strip()


def _sentence(text: str, start: int, end: int) -> str:
    """The sentence around a match: back to the previous full stop, on to the next.

    A stop only counts when a capital letter follows and the word before it is not an
    abbreviation, or "staff at Össur hf. that supported me" would be cut at "hf.".
    """
    bounds = [0] + [m.end() for m in _SENTENCE_END.finditer(text)
                    if len(m.group("word")) > 1
                    and m.group("word").lower() not in _ABBREVIATIONS] + [len(text)]
    lo = max(b for b in bounds if b <= start)
    hi = min((b for b in bounds if b >= end), default=len(text))
    return text[lo:hi]


def _cue(sentence: str) -> str | None:
    """What the sentence naming an organisation says it did, strongest first."""
    for cue, rx in _CUES:
        if rx.search(sentence):
            return cue
    return None


def signals(text: str, org_rx: re.Pattern | None) -> list[tuple[str, str, str | None, str, str | None]]:
    """(kind, match, org_key, context, cue) for one passage.

    `cue` is set for organisation matches only: the strongest thing their own sentence says
    they did (see _CUES). An organisation in a sentence with no cue is thanked, nothing more.
    """
    out = []
    for m in _SUFFIX.finditer(text):
        name = re.sub(r"\s+", " ", m.group("name")).strip() + " " + m.group("suffix")
        if _PUBLISHER.search(name):
            continue
        out.append(("org_suffix", name, None, _context(text, m.start(), m.end()),
                    _cue(_sentence(text, m.start(), m.end()))))
    for kind, rx in (("collab_phrase", _COLLAB), ("funding_phrase", _FUNDING)):
        for m in rx.finditer(text):
            out.append((kind, m.group(0), None, _context(text, m.start(), m.end()), None))

    if org_rx:
        for m in org_rx.finditer(text):
            out.append(("known_org", m.group(0), m.lastgroup, _context(text, m.start(), m.end()),
                        _cue(_sentence(text, m.start(), m.end()))))
    return out


# --- advisors -----------------------------------------------------------------------
#
# Is an advisor from outside the universities? Two places say so. HR's title page gives each
# advisor's position and employer on the line under the name ("Verkfræðingur, Samgöngustofa";
# "Associate Professor, Reykjavík University"); HÍ's gives the name alone, but the
# acknowledgements often name the employer beside it ("Andra Gunnarssyni hjá Eflu"). The
# examiner is left out on purpose: an examiner is impartial by design, not a partner.

# An academic position or employer. Checked after the gazetteer, so "University of Ljubljana"
# is already a foreign university by the time this is asked.
_ACADEMIC = re.compile(
    r"(?i)professor|prófessor|\blektor|\blector|lecturer|dósent|docent|adjunct|aðjúnkt"
    r"|universit\w*|háskól\w*|\bcollege\b|ph\.?\s?d\.?\s+(?:student|candidate)|doktorsnem\w*"
    r"|post-?doc\w*|school of|faculty|fræðasvið|deild\b"
)
# A job title nobody holds at a university: says outside even when the employer is unnamed.
_INDUSTRY_TITLE = re.compile(
    r"(?i)\w*verkfræðing\w*|\w*tæknifræðing\w*|\w*iðnfræðing\w*|sérfræðing\w*|\w*stjóri\b"
    r"|ráðgjaf\w*|\bengineer\b|manager|director|\bCEO\b|\bCTO\b|consultant|specialist"
    r"|head of|chief"
)
# From an advisor's name in the acknowledgements to where they work: "Andra Gunnarssyni hjá
# Eflu", "Árni Benediktsson, Head Engineer at Landsvirkjun", "X (Landsvirkjun)". At most a
# few words of job title in between, and the employer is the capitalised phrase after the
# preposition -- the first one only, so "Sigurði hjá Háskóla Íslands og Andra hjá Eflu" gives
# Sigurður the university, not Efla.
_EMPLOYER_AFTER = re.compile(
    # No "^": this is used with .match(text, pos), which anchors at pos; "^" would not.
    rf"[\s,]{{0,3}}(?:[\w.\-]+\s+){{0,4}}?(?:hjá|at|from|frá|of|\()\s*(?:the\s+)?"
    rf"(?P<org>[{UPPER}][^\s,.;:()]*(?:\s+(?:[{UPPER}][^\s,.;:()]*|og|and|of|í|á)){{0,4}})"
)


def _fold(text: str) -> str:
    """Accents off, one character for one, so positions in the folded text are positions in
    the original: 'Júlíusson' -> 'Juliusson'. þ, ð and æ have no decomposition and stay."""
    return "".join(unicodedata.normalize("NFD", ch)[0] for ch in text)


def _name_parts(name: str) -> tuple[str, str] | None:
    """(first name, surname) from a people.name: 'Winrow, Patrick Karl' or 'Jón E. Bernódusson'."""
    if "," in name:
        last, _, first = name.partition(",")
        name = f"{first.strip()} {last.strip()}"
    words = [w for w in name.split() if len(w.rstrip(".")) > 1]
    if len(words) < 2:
        return None
    return words[0], words[-1]


def _inflected(word: str, keep: int) -> str:
    """A regex for an Icelandic name in any case: 'Gunnarsson' -> Gunnarssyni, 'Andri' -> Andra.

    Patronymics keep their stem and let the ending vary; other names keep their first `keep`
    letters. A foreign name ("Winrow") still matches itself.
    """
    if word.endswith("son"):
        stem = word[:-2]
    elif word.endswith("dóttir"):
        stem = word[:-2]
    else:
        stem = word[:max(keep, len(word) - 2)] if len(word) > keep else word
    return re.escape(stem) + r"\w*"


def _classify_employer(text: str, org_rx: re.Pattern | None,
                       orgs_by_key: dict[str, dict]) -> tuple[str | None, str | None, str | None]:
    """(kind, org_key, employer text) for what follows an advisor's name.

    kind is 'outside', 'academic' or None when nothing tells. A gazetteer organisation decides
    by its sector; then an academic position; then an industry job title or company suffix.
    """
    if org_rx:
        for m in org_rx.finditer(text):
            o = orgs_by_key[m.lastgroup]
            if o["sector"] == "university":
                return "academic", o["key"], m.group(0)
            if o.get("external", True):
                return "outside", o["key"], m.group(0)
    if _ACADEMIC.search(text):
        return "academic", None, None
    m = _SUFFIX.search(text)
    if m:
        return "outside", None, re.sub(r"\s+", " ", m.group(0)).strip()
    if _INDUSTRY_TITLE.search(text):
        # "Véliðnfræðingur, GJ járn": the employer, when stated, follows the title's comma.
        rest = text.split(",", 1)[1].strip() if "," in text else None
        return "outside", None, rest or None
    return None, None, None


def advisor_affiliations(advisors: list[tuple[int, str]], titlepage: str | None,
                         front_matter: list[str], org_rx: re.Pattern | None,
                         orgs_by_key: dict[str, dict]) -> list[tuple]:
    """One row per advisor of one thesis: what the title page and the acknowledgements say."""
    parts = {pid: _name_parts(name) for pid, name in advisors}

    # The title page: each advisor's block runs from their surname to the next advisor's name.
    # Names are found with accents folded on both sides: the title page of 23877 spells
    # "Egill Juliusson" where Skemman has "Júlíusson", and a name not found merges its block,
    # employer and all, into the advisor before it.
    blocks: dict[int, str] = {}
    if titlepage:
        folded = _fold(titlepage)
        found = []
        for pid, p in parts.items():
            if p:
                m = re.search(rf"(?<!\w){re.escape(_fold(p[1]))}(?!\w)", folded)
                if m:
                    found.append((m.start(), m.end(), pid))
        found.sort()
        for i, (_, end, pid) in enumerate(found):
            nxt = found[i + 1][0] if i + 1 < len(found) else len(titlepage)
            # Back up to the start of the next advisor's first name, not their surname.
            block = titlepage[end:nxt]
            if i + 1 < len(found):
                first = _fold(parts[found[i + 1][2]][0])
                cut = _fold(block).rfind(first)
                block = block[:cut] if cut >= 0 else block
            blocks[pid] = block.strip(" ;,")

    rows = []
    for pid, name in advisors:
        tp_kind = tp_org = tp_text = None
        if pid in blocks and blocks[pid]:
            tp_kind, tp_org, tp_text = _classify_employer(blocks[pid], org_rx, orgs_by_key)
        ack_kind = ack_org = ack_text = ack_context = None
        p = parts[pid]
        if p:
            name_rx = re.compile(
                rf"(?<!\w){_inflected(p[0], 4)}(?:\s+[\w.\-]+){{0,3}}?\s+{_inflected(p[1], 5)}(?!\w)"
            )
            for text in front_matter:
                for m in name_rx.finditer(text):
                    e = _EMPLOYER_AFTER.match(text, m.end())
                    if not e:
                        continue
                    # The whole span, title included: "Professor of Civil Engineering" is
                    # academic because of "Professor", not because of what follows "of".
                    ack_kind, ack_org, ack_text = _classify_employer(
                        text[m.end():e.end()], org_rx, orgs_by_key)
                    if ack_kind is None:
                        # Named but unknown to the gazetteer: keep the text for the LLM step
                        # and for growing the gazetteer, but do not call it either way.
                        ack_text = e.group("org")
                    ack_context = _context(text, m.start(), e.end())
                    break
                if ack_context:
                    break
        rows.append((pid, name, blocks.get(pid), tp_kind, tp_org, tp_text,
                     ack_kind, ack_org, ack_text, ack_context))
    return rows


def write_table(con: duckdb.DuckDBPyConnection, name: str, columns: str, rows: list) -> None:
    """Replace a table with these rows in one statement.

    executemany() inserts row by row and took two minutes for a few thousand rows; a
    DataFrame goes in as a single scan.
    """
    con.execute(f"create or replace table {name} ({columns})")
    if rows:
        df = pd.DataFrame(rows, columns=[c.split()[0] for c in columns.split(",")])
        con.register("_rows", df)
        con.execute(f"insert into {name} select * from _rows")
        con.unregister("_rows")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=str(ROOT / "data" / "processed" / "thesis.db"))
    ap.add_argument("--text-dir", default=str(ROOT / "data" / "raw" / "pdf_text"))
    ap.add_argument("--organisations", default=str(ROOT / "config" / "organisations.yaml"))
    args = ap.parse_args()

    orgs, org_rx = load_organisations(Path(args.organisations))
    text_dir = Path(args.text_dir)

    with duckdb.connect(args.db) as con:
        # Every master's thesis in the population, not just engineering: the text is on disk
        # anyway, and the chapters choose their own slice through v_thesis_discipline.
        theses = con.execute(
            "select thesis_id, abstract_is, abstract_en from v_thesis_msc"
        ).fetchall()

        advisors: dict[int, list[tuple[int, str]]] = {}
        for thesis_id, pid, name in con.execute("""
                select tp.thesis_id, tp.person_id, p.name
                from thesis_people tp
                join people p on p.id = tp.person_id
                join v_thesis_msc using (thesis_id)
                where tp.role = 'advisor'
                order by tp.thesis_id, tp.sort_order""").fetchall():
            advisors.setdefault(thesis_id, []).append((pid, name))
        titlepage = dict(con.execute(
            "select thesis_id, advisors from thesis_titlepage where advisors is not null"
        ).fetchall())
        orgs_by_key = {o["key"]: o for o in orgs}

        sec_rows, sig_rows, text_rows, adv_rows = [], [], [], []
        for thesis_id, abstract_is, abstract_en in theses:
            passages = []
            path = text_dir / f"{thesis_id}.txt"
            text_rows.append((thesis_id, path.exists()))
            if path.exists():
                passages += sections(read_text(path))
            if thesis_id in advisors:
                front = [body for kind, _, body in passages]
                for row in advisor_affiliations(advisors[thesis_id], titlepage.get(thesis_id),
                                                front, org_rx, orgs_by_key):
                    adv_rows.append((thesis_id, *row))
            for kind, abstract in (("abstract_is", abstract_is), ("abstract_en", abstract_en)):
                if abstract and abstract.strip():
                    passages.append((kind, "", abstract.strip()))
            for kind, head, body in passages:
                sec_rows.append((thesis_id, kind, head, body))
                for sig in signals(body, org_rx):
                    sig_rows.append((thesis_id, kind, *sig))

        write_table(con, "thesis_section",
                    "thesis_id integer, section varchar, heading varchar, text varchar", sec_rows)
        # Which theses had front-matter text to search at all. A thesis with none is unknown,
        # not "no collaboration", and the views have to be able to say which is which.
        write_table(con, "thesis_text_read", "thesis_id integer, has_text boolean", text_rows)
        write_table(con, "thesis_org_signal",
                    "thesis_id integer, section varchar, kind varchar, match varchar, "
                    "org_key varchar, context varchar, cue varchar", sig_rows)
        write_table(con, "thesis_advisor_affiliation",
                    "thesis_id integer, person_id integer, name varchar, "
                    "titlepage_block varchar, titlepage_kind varchar, titlepage_org_key varchar, "
                    "titlepage_employer varchar, ack_kind varchar, ack_org_key varchar, "
                    "ack_employer varchar, ack_context varchar", adv_rows)
        write_table(con, "organisation",
                    "org_key varchar, name varchar, sector varchar, external boolean",
                    [(o["key"], o["name"], o["sector"], o.get("external", True)) for o in orgs])
        con.execute("checkpoint")

    n_text = sum(1 for r in sec_rows if not r[1].startswith("abstract"))
    print(f"{len(theses)} theses: {n_text} front-matter sections, "
          f"{len(sig_rows)} signals, {len(orgs)} organisations in the gazetteer.")


if __name__ == "__main__":
    main()
