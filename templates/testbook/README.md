# Huawei Cloud Test Book — LaTeX Template

A LaTeX template that produces a Huawei Cloud POC/acceptance test case PDF:
cover page, header, table of contents, test cases organized by domain with
structured tables (objective, prerequisites, procedure, expected result,
remarks, test result), code blocks, callout boxes, and changelog.

> **Setup:** see the [root README](../../README.md) for installation,
> environment setup, VS Code configuration, and compilation instructions.
> See [SKILL.md](SKILL.md) for the full command and environment reference.

## Language

By default the test book renders in **English** — built-in labels such as
*Objective*, *Prerequisites*, *Procedure*, *Expected Result*, *Remarks* and
*Test Result* are in English. Pass the **`portuguese`** class option
(`\documentclass[portuguese]{testbook}`) to switch all labels to Portuguese
and load `babel` with `brazilian` instead.

## Class options

```latex
\documentclass[portuguese,indentbody,notime,nochangelog,noauthors,noanswers]{testbook}
```

| Option | Effect |
|---|---|
| `portuguese` | Switches all predefined labels to Portuguese; loads `babel` with `brazilian`. Default off (English). |
| `indentbody` | Indents all running text by `\contentindent` (0.6 cm). Default off (text flush to the left margin). |
| `notime` | Hides the compilation time (HH:MM) on the cover page. Default off (time is shown). |
| `nochangelog` | Suppresses the changelog section entirely (no-ops) and hides version, date, and time on the cover page. Use when it grows too large. Default off (changelog is shown). |
| `noauthors` | Hides the authors on the cover page. Default off (authors shown if set via `\setdocauthors`). |
| `noanswers` | Hides the **Remarks** and **Test Result** rows in all test cases. Use to produce a blank test book for testers to fill in by hand. Default off (all rows shown). |

### Label translations

| Token | English (default) | Portuguese (`[portuguese]`) |
|---|---|---|
| TOC title | Contents | Sumário |
| Cover title default | Test Book | Test Book |
| `\testobjective` label | Objective | Objetivo |
| `\testprerequisites` label | Prerequisites | Pré-requisitos |
| `\testprocedure` label | Procedure | Procedimento |
| `\testexpected` label | Expected Result | Resultado Esperado |
| `\testremarks` label | Remarks | Observações |
| `\testresult` label | Test Result | Resultado do Teste |
| Footer page label | Page | Página |

## Document structure

The body order is fixed: `\makecover` → `\maketoc` → `\startbody` → sections
→ `changelog` → `\end{document}`.

Sections (`\section`) represent test domains. Each test case uses the
`testcase` environment, which produces a subsection heading and a structured
2-column table.

See [SKILL.md](SKILL.md) for the complete skeleton and all available commands
and environments.

## Format reference

| Element | Value |
|---|---|
| Page | A4 |
| Margins | top/bottom 3 cm · left/right 2 cm |
| Body font | HarmonyOS Sans, 10.5 pt |
| Code font | Cascadia Code, 10 pt |
| Body leading | ~14 pt |
| Space between paragraphs | 4 pt |
| H1 title | 20 pt bold right-aligned + 56 pt number left-aligned + 1.5 pt rule |
| H2 / H3 / H4 titles | 18 / 16 / 14 pt, regular |
| Test case label column | 3 cm, white bold on Huawei-red (`#C7000B`) |
| Code background | `#F6F8FA` |
| Code text color | `#1F2328` |
| Link color | `#0000FF` (no underline) |
| Brand red | `#C7000B` (`huaweired` — H1 chapter rules, test case labels, accents, badge) |
| Warning box | `#FFF8E1` bg / `#F57C00` border |
| Tip box | `#E8F5E9` bg / `#2E7D32` border |
| Info box | `#E3F2FD` bg / `#1565C0` border |

Colors are defined in `templates/_base/huawei-colors.sty` and fonts in
`templates/_base/huawei-fonts.sty`. Both are reusable via `\textcolor{name}{...}`
and `\codefont` respectively.

## Customization

- **Logos:** replace files in `common-assets/` keeping the names, or use
  `\setheaderlogo{path}` / `\setcoverlogo{path}` in the preamble.
- **Colors:** edit the `\definecolor` block in `templates/_base/huawei-colors.sty`.
- **Fonts:** edit font setup in `templates/_base/huawei-fonts.sty`.
- **Sizes/spacing:** each concern is in a commented section of `testbook.cls`
  (`TITLES`, `CODE`, `HEADER AND FOOTER`, etc.) — find the section and edit there.

## Samples

Two samples demonstrate all commands and environments:

- [`examples/testbook/pt/main.tex`](../../examples/testbook/pt/src/main.tex) — Portuguese
- [`examples/testbook/en/main.tex`](../../examples/testbook/en/src/main.tex) — English

Compile with `make pt` / `make en` from the repo root, or `latexmk main.tex`
from either folder.

## Quick example

```latex
\documentclass{testbook}

\settestbooktitle{POC Test Cases: ECS Provisioning}
\setheadertitle{Huawei Cloud -- ECS POC Tests}
\setdocversion{1.0.0}
\setdocdate{\today}

\begin{document}
\makecover \maketoc \startbody

\section{ECS Instance Management}

\begin{testcase}{TC-001: Create ECS instance}
  \testobjective{Verify that an ECS instance can be created.}
  \testprerequisites{1. Account is active. \\ 2. VPC exists.}
  \testprocedure{1. Navigate to ECS. \\ 2. Click Create. \\ 3. Fill parameters. \\ 4. Click OK.}
  \testexpected{1. Instance is created. \\ 2. Status is Running.}
  \testremarks{Test with basic and general-purpose specs.}
  \testresult{Pass}
\end{testcase}

\begin{changelog}
  \changelogentry{1.0.0}{\today}{\item Initial version.}
\end{changelog}

\end{document}
```

Compile with `latexmk main.tex` (XeLaTeX).
