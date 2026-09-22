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

Writes four tables, replaced on every run:

  thesis_section     one row per bounded passage -- the input the LLM step (#12) will read
  thesis_text_read   whether the thesis had cached PDF text to search at all
  thesis_org_signal  one row per match, with its surrounding text as evidence
  organisation       config/organisations.yaml, flattened

scripts/collaboration.sql builds the per-thesis views on top.

  python scripts/load_collaboration.py [--db data/processed/thesis.db] [--text-dir data/raw/pdf_text]
"""
import argparse
import re
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

        sec_rows, sig_rows, text_rows = [], [], []
        for thesis_id, abstract_is, abstract_en in theses:
            passages = []
            path = text_dir / f"{thesis_id}.txt"
            text_rows.append((thesis_id, path.exists()))
            if path.exists():
                passages += sections(read_text(path))
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
        write_table(con, "organisation",
                    "org_key varchar, name varchar, sector varchar, external boolean",
                    [(o["key"], o["name"], o["sector"], o.get("external", True)) for o in orgs])
        con.execute("checkpoint")

    n_text = sum(1 for r in sec_rows if not r[1].startswith("abstract"))
    print(f"{len(theses)} theses: {n_text} front-matter sections, "
          f"{len(sig_rows)} signals, {len(orgs)} organisations in the gazetteer.")


if __name__ == "__main__":
    main()
