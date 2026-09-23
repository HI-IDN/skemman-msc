# Paper brief: master's theses as a trace of university–industry knowledge exchange

Framing for a journal article built on the Skemman analysis in this repository. Tracked in
[#17](https://github.com/HI-IDN/skemman-msc/issues/17). The literature behind it is in
[`literature.md`](literature.md); verified references are in [`references.bib`](references.bib).

This brief began as a request to Copilot Researcher written for *Verktækni* (Icelandic).
It has been rewritten for an international engineering-education journal.

## Target venue

- **Journal of Engineering Education (JEE)** is the first choice. It expects an explicit
  theoretical framework, a clear contribution to engineering education research (not
  only to innovation policy), and careful statements about what the data can and cannot show.
- **European Journal of Engineering Education (EJEE)** is the natural alternative. The
  closest precedents ([Asplund & Bengtsson 2020](https://doi.org/10.1080/03043797.2019.1604632); [Shah & Gillen 2024](https://doi.org/10.1080/03043797.2023.2253741); [Vuoriainen et al. 2024](https://doi.org/10.1080/03043797.2024.2432440))
  were published there, so the paper would be in direct conversation with them.

For either venue, the education angle has to lead: the thesis is a learning experience
that also serves as a channel for knowledge exchange. The descriptive statistics are
evidence for that argument, not the contribution in themselves.

## Working titles

1. *Master's theses as traces of university–industry knowledge exchange: a longitudinal
   analysis of engineering education in Iceland*
2. *Master's theses as an interface between university and industry: engineering and
   technology education in Iceland since 2010*

The first title is preferred. It makes clear that theses are used as a **proxy** for
knowledge exchange, not as proof that knowledge was transferred.

## Research questions

**Overarching (RQ-A).** What do master's theses show about the development and structure
of university–industry and university–society ties in Icelandic engineering and
technology education since 2010?

- **RQ-B.** How have the number and disciplinary composition of engineering and technology
  master's theses at HÍ and HR developed over the period?
- **RQ-C.** What share of theses show recorded ties to external organisations, and how does
  this vary by university, discipline, year and type of partner?
- **RQ-D.** What longitudinal patterns appear in repeat partners, external supervision,
  supervisor–organisation networks and thesis topics?
- **RQ-E.** How do the Icelandic patterns compare with Nordic and international studies of
  collaborative master's theses and other capstone work?

### Mapping to the book

The book's chapters (RQ1–RQ7, issues #4–#10) are the evidence base. The paper's questions
draw on them as follows:

| Paper | Book chapters and issues | Status in the book |
|---|---|---|
| RQ-A | RQ7 knowledge transfer (#10), with all other chapters | parked |
| RQ-B | RQ1 volume (#4), RQ2 disciplines (#5), RQ3 HÍ vs HR (#6) | RQ1 done |
| RQ-C | RQ4 collaboration (#7), RQ5 partners (#8), RQ3 (#6) | depends on #11, #12, #14 |
| RQ-D | RQ5 (#8), RQ6 themes (#9), advisor network (#13), supervisor workplace (#16) | in progress |
| RQ-E | literature only, no chapter | [`literature.md`](literature.md) |

## Working hypotheses (to test, not assume)

| # | Hypothesis | Tested in | Data needed |
|---|---|---|---|
| H1 | The share of industry-linked theses has increased since 2010 | RQ4 (#7) | Partner extraction (#11) with missingness reported per year |
| H2 | How common industry collaboration is varies by discipline | RQ4 × RQ2 | Discipline map, partner extraction |
| H3 | HÍ and HR have different collaboration patterns | RQ3, RQ4 | As above |
| H4 | A few industry sectors dominate as partners | RQ5 (#8) | Company register / ÍSAT codes (#14) |
| H5 | Collaboration is concentrated in relatively few organisations | RQ5, network (#13) | Normalised organisation names |
| H6 | New topics (data science, AI, sustainability) become more visible over time | RQ6 (#9) | Titles, abstracts, keywords |
| H7 | Theses are a useful but incomplete proxy for university–industry ties | Methods, limitations | Hand-coded validation sample |

A benchmark for H1–H3: [Bengtsson & Asplund (2026)](https://doi.org/10.1007/s44217-026-01559-x) report a 64% collaboration rate for
engineering MSc theses at one Swedish university (6% for business). This is the only
published thesis-level rate from a comparable setting that has been verified so far.

## Coding external involvement

A thesis that names a company has not necessarily collaborated with it. To keep these
apart, external involvement is coded on an ordinal scale:

| Level | Meaning | Typical evidence |
|---|---|---|
| 0 | No visible external tie | Nothing in the available data |
| 1 | External organisation mentioned, role unclear | Acknowledgements, abstract |
| 2 | Data or problem provider | "Data provided by …", problem statement |
| 3 | Active partner: supervision, project development or assessment | External supervisor or examiner (#16) |
| 4 | Integrated project, tied to the partner's operations, innovation or a larger research project | Several signals together |

The scale is a proposal. Before the paper uses it, it needs written coding rules and a
stratified hand-coded sample to validate any automated classification (#12). Results
should be reported under both a narrow definition (levels 3–4) and a broad one (levels 1–4).

## Contribution and research gap

This is **not** the first study to use master's theses to study knowledge transfer. The
Swedish studies ([Asplund & Bengtsson 2020](https://doi.org/10.1080/03043797.2019.1604632); [Bengtsson & Asplund 2026](https://doi.org/10.1007/s44217-026-01559-x)) and [Mamica (2020)](https://doi.org/10.13187/ejced.2020.1.76) do
that directly. The defensible claim is narrower:

> Earlier studies show that master's theses can be a channel for university–industry
> collaboration and knowledge exchange. Most of them focus on a single university or
> programme, or on cross-sectional data. This study follows visible
> university–society ties over a longer period, using thesis metadata from engineering and
> technology at two universities in the same small national system.

The closest precedent makes the difference concrete. The Swedish Lund (LTH) study is a
survey of a single year of theses (2016), with telephone follow-up to the collaborating
firms. That design measures what firms gain, which metadata cannot, but it cannot show
change over time. This study covers theses from 2010 to 2026 and gives up firm-side outcomes
in exchange for the time dimension. The two designs complement each other; neither
replaces the other.

What is specific to this study:

- two universities (HÍ and HR) compared within one country;
- a long time span, 2010–2026, where the closest precedent covers one year;
- a broad partner definition: companies, public agencies, hospitals, research institutes;
- metadata, text and network analysis combined;
- a small innovation system. Earlier Icelandic work describes university–industry ties as
  informal, short-term and dependent on personal networks ([Karlsdottir et al. 2021](https://doi.org/10.1504/IJKBD.2021.119049)), so
  the question is which part of those ties becomes visible in formal records.

The gap statement must stay within what the literature review supports. See
[`literature.md`](literature.md#research-gap).

## Language for claims

Throughout the paper, use:

- *visible traces of collaboration*, *recorded ties*, *proxy*;
- *consistent with knowledge exchange*.

Avoid *evidence of impact*, *proves*, and *knowledge was transferred*. The metadata show
recorded ties and how they change. They do not show hiring, implementation, patents,
publications or doctoral progression. Those outcomes would need surveys, interviews or
linkage to other registers.
