---
name: huawei-template-testbook
description: Create or edit Huawei Cloud test case documents using the LaTeX testbook template. Use when the user wants to write, extend, or fix a test case document, POC test cases, or acceptance test document for Huawei Cloud. Triggers on keywords like huawei-template-testbook, testbook, test cases, POC test, acceptance testing, casos de teste.
---

# Huawei Cloud Test Book — Skill

Create, edit, and compile Huawei Cloud POC/acceptance test case documents
using the `testbook` LaTeX class in this directory. The output is a PDF
compiled from LaTeX; DOCX, Markdown, and HTML are generated via Pandoc.

## When to use

Use this skill when the task is to **write, extend, or fix a Huawei Cloud
POC or acceptance test case document**. Test books follow a 3-section
structure: **Introduction** (objectives, scope, preconditions, acceptance
method), **Test Cases** (subsections per domain, each containing auto-numbered
`testcase` environments), and **Conclusion** (test summary table). Each test
case is rendered as a breakable tcolorbox with stacked fields, each preceded
by a full-width red mini header bar. Field order: Objective → Prerequisites →
Procedure → Expected Result → Test Result → Remarks. Content defaults to
English; pass the `portuguese` class option for Portuguese labels. Do **not**
use this for general LaTeX documents — the formatting is hard-coded to the
Huawei house style (AGENTS.md L9).

## Context loading (do this first)

Before creating or editing any document, read these files to load the full
project context:

1. **`templates/testbook/testbook.cls`** — the class file. Shared formatting
   lives in `templates/_base/huawei-*.sty` modules. Testbook-specific
   formatting (cover, TOC, titles, testcase environment) lives in
   `testbook.cls`. Every command and environment available to documents is
   defined across these files.
2. **`README.md`** (repo root) — project setup, compilation instructions,
   install steps, and project layout. Needed to understand the toolchain and
   folder conventions.
3. **`AGENTS.md`** (repo root) — locked decisions (see AGENTS.md), file editing
   rules, versioning workflow, and project standards. These are mandatory
   constraints that must not be violated.
4. **`templates/testbook/README.md`** — human-readable template overview (class
   options, label translations, format reference, customization).

Read all four files before proceeding to the Quick start below. Do not
guess command names, class options, or formatting conventions — look them
up in the class file and this SKILL.md.

---

## Quick start — creating a new test book

1. **Ask for the essentials** (if not already provided):
   - **Title** — e.g. "POC Test Cases: ECS Instance Provisioning"
   - **Language** — English (default) or Portuguese
   - **Project name** — used as the folder name (e.g. `ecs-poc-tests`)
   - **Author(s)** — prompt the user: "Who is the author of this document?"
     Add `\setdocauthors{Name}` to the preamble. If multiple authors, separate
     with commas: `\setdocauthors{John Smith, Jane Doe}`. If the user declines,
     omit the command entirely (nothing shown on the cover).
   - **Changelog** — prompt the user: "Keep the changelog section? [Y/n]"
     If yes (default), include the `changelog` environment with an initial
     `\changelogentry{1.0.0}{\today}{\item Initial version.}`. If no, add the
     `[nochangelog]` class option to suppress it.

2. **Create a self-contained project folder** at `documents/<project-name>/`:
   - **Always create a subfolder inside `documents/`** — never scatter files
     directly in the workspace root or `documents/` itself.
   - Inside the folder, create:
     - `src/` subfolder containing:
       - `<filename>.tex` — the document, using the skeleton below.
       - `.latexmkrc` — with `TEXINPUTS` pointing to this template directory.
         From `documents/<project-name>/src/`, the relative path to
         `templates/testbook/` is `../../../templates/testbook/`:
         ```perl
         $ENV{TEXINPUTS} = "../../../templates/_base/:../../../templates/testbook/:" . ($ENV{TEXINPUTS} || "");
         $pdf_mode = 5;
         $xelatex = 'xelatex -interaction=nonstopmode %O %S';
         $out_dir = '..';
         $aux_dir = '.';
         ```
            - **Timezone:** default `America/Sao_Paulo` (AGENTS.md L4).
              Override in `.latexmkrc` if needed (see [README.md](../../README.md)).
            - **Output:** `$out_dir = '..'` sends the PDF to the parent directory;
              `$aux_dir = '.'` keeps aux files in `src/`.
     - `assets/` subfolder for project-specific images and code files.

3. **Compile and verify** — generate all four output formats:
   ```bash
   make project DIR=documents/<project-name>                    # PDF
   ./scripts/build.sh --all documents/<project-name>            # PDF + DOCX + MD + HTML
   ```
   Or from inside the project folder:
   ```bash
   cd src/ && latexmk main.tex                                  # PDF
   cd ../../.. && ./scripts/build.sh --all documents/<project-name>  # all 4 formats
   ```

4. **Report** the page count, output file locations (PDF, DOCX, MD, HTML),
   and any warnings to the user.

---

## Hard requirements

- **Engine: XeLaTeX or LuaLaTeX only.** The class loads `fontspec`, so
  `pdflatex` will fail. Always compile with `xelatex` (or `lualatex`).
- **Compile twice** on the first run so the TOC and page numbers settle.
  `latexmk` handles this automatically (`.latexmkrc` is included).
- **fvextra ≥ 1.5** — provides `backgroundcolor` for code blocks. TeX Live
  2024+ includes it; on older installs, update from CTAN or run `scripts/install.sh`.
- **Fonts:** HarmonyOS Sans (body) + Cascadia Code (code). Falls back with
  a warning if missing (see AGENTS.md L8). `scripts/install.sh` installs both.

---

## Document skeleton

### English (default)

```latex
\documentclass{testbook}

\settestbooktitle{Test Book: <project name>}
\setheadertitle{Huawei Cloud -- <short title>}
\setcovertext{Huawei Technologies CO., LTD}
\setdocversion{1.0.0}
\setdocdate{\today}
\setdocauthors{Author Name}  % optional — omit to hide

\begin{document}
\makecover
\maketoc
\startbody

% --- Section 1: Introduction ---
\section{Introduction}

\begin{objectives}
  \generalobjective{Verify that <system> meets the acceptance criteria.}
  \prerequisites
  \begin{itemize}
    \item <precondition 1>
    \item <precondition 2>
  \end{itemize}
\end{objectives}

\subsection{Test Scope}
% ... scope table ...

\subsection{Preconditions and Preparations}
% ... preconditions list ...

\subsection{Acceptance Method}
% ... acceptance criteria table ...

% --- Section 2: Test Cases ---
\section{Test Cases}

\subsection{<Test Domain 1>}

\begin{testcase}{<test case title>}
  \testobjective{Verify that <functionality> works as expected.}
  \begin{testprerequisites}
    \teststep{System is running.}
    \teststep{User is logged in.}
  \end{testprerequisites}
  \begin{testprocedure}
    \teststep{Navigate to <page>}
    \teststep{Click <button>}
    \teststep{Enter <data> and click Save}
  \end{testprocedure}
  \begin{testexpected}
    \teststep{The resource is created successfully.}
    \teststep{Data is persisted.}
  \end{testexpected}
  \testresult{\testresultbadge{Pass}}
  \testremarks{Optional notes about this test case.}
\end{testcase}

\begin{testcase}{<another test case title>}
  \testobjective{Verify that <other functionality> behaves correctly.}
  \begin{testprerequisites}
    \teststep{Testcase 1 completed.}
  \end{testprerequisites}
  \begin{testprocedure}
    \teststep{Select the resource}
    \teststep{Click Delete and confirm}
  \end{testprocedure}
  \begin{testexpected}
    \teststep{The resource is removed.}
    \teststep{No orphan data remains.}
  \end{testexpected}
  \testresult{\testresultbadge{Pass}}
  \testremarks{}
\end{testcase}

\subsection{<Test Domain 2>}

\begin{testcase}{<test case in domain 2>}
  \testobjective{...}
  \begin{testprerequisites}
    \teststep{...}
  \end{testprerequisites}
  \begin{testprocedure}
    \teststep{...}
  \end{testprocedure}
  \begin{testexpected}
    \teststep{...}
  \end{testexpected}
  \testresult{...}
  \testremarks{...}
\end{testcase}

% --- Section 3: Conclusion ---
\section{Conclusion}

\begin{testsummary}
  \testsummaryrow{1}{<test case title>}{\testresultbadge{Pass}}
  \testsummaryrow{2}{<another test case title>}{\testresultbadge{Pass}}
  \testsummaryrow{3}{<test case in domain 2>}{\testresultbadge{Fail}}
\end{testsummary}

% --- Changelog (after all sections, before \end{document}) ---
\begin{changelog}
  \changelogentry{1.0.0}{2026-09-12}{
    \item Initial version.
  }
\end{changelog}

\end{document}
```

### Portuguese

Same skeleton but with `\documentclass[portuguese]{testbook}`. Labels switch
automatically: *Casos de Teste*, *Objetivo*, *Pré-requisitos*, *Procedimento*,
*Resultado Esperado*, *Resultado do Teste*, *Observações*. Section headings
should be translated: *Introdução*, *Casos de Teste*, *Conclusão*.

Body order is fixed: `\makecover` → `\maketoc` → `\startbody` → sections →
`changelog` → `\end{document}`.

**Accent verification (PT-BR).** After compiling a Portuguese document,
confirm no glyphs are missing:

```sh
grep -i "Missing character" main.log   # must produce no output
```

XeLaTeX emits `Missing character: There is no <glyph>` for any code point the
active font lacks. The brand fonts (HarmonyOS Sans, fallback Liberation Sans)
provide full PT-BR coverage; a custom font that drops a diacritic will surface
here.

---

## Project layout (this directory)

```
templates/testbook/
├── testbook.cls          # testbook-specific formatting (cover, TOC, titles, testcase env)
├── testbook-pandoc.lua   # Lua filter wrapper (calls _base/pandoc-common.lua factory)
├── testbook-template.html   # HTML template for Pandoc
├── create-testbook-reference-docx.py  # DOCX reference creation/fix script (calls _base/docx_fix.py)
├── README.md             # human docs (brief — see root README for setup)
├── SKILL.md              # this file (opencode skill)
├── .latexmkrc            # latexmk config (XeLaTeX by default)
└── common-assets/        # shared template assets (logos, sample images)
    ├── huawei-logo-header.png   # header logo
    ├── huawei-logo-cover.png    # cover logo
    ├── exemplo-menu.png         # sample image
    ├── exemplo-login.png        # sample image
    └── example-script.sh        # example code file for \codefile

# Each document has its own assets/ folder for project-specific files:
examples/testbook/
├── pt/
│   ├── src/
│   │   ├── .latexmkrc  # TEXINPUTS → ../../../templates/testbook/; $out_dir='..'
│   │   └── main.tex    # Portuguese sample (reference)
│   └── assets/         # project-specific images and files
└── en/
    ├── src/
    │   ├── .latexmkrc
    │   └── main.tex    # English sample (reference)
    └── assets/         # project-specific images and files

# User-created documents go in documents/ (see Quick start):
documents/
└── my-testbook/
    ├── src/
    │   ├── .latexmkrc  # TEXINPUTS → ../../../templates/_base/ + ../../../templates/testbook/; $out_dir='..'
    │   └── main.tex
    └── assets/
```

**Asset resolution:** when a `.tex` file references `assets/foo.png`, LaTeX
looks in the project's own `assets/` folder first, then falls back to
`common-assets/` in the template directory (via TEXINPUTS). Logos default to
`common-assets/` since they are template-level shared assets.

**Rule of thumb:** content/structure goes in `.tex` files; shared look-and-feel
goes in `templates/_base/huawei-*.sty` modules; testbook-specific formatting
goes in `testbook.cls`. Do not inline formatting overrides in the document
unless the user asks.

---

## Commands reference

### Preamble configuration
| Command | Purpose |
|---|---|
| `\settestbooktitle{...}` | Big cover title (default "Test Book"). |
| `\setheadertitle{...}` | Centered header text on body pages (cover, TOC, and changelog have no header). |
| `\setcovertext{...}` | Line under the cover logo (default `Huawei Technologies CO., LTD`). |
| `\setheaderlogo{path}` | Header logo image path (default `common-assets/huawei-logo-header.png`). |
| `\setcoverlogo{path}` | Cover logo image path (default `common-assets/huawei-logo-cover.png`). |
| `\setdocversion{1.0.0}` | Document version, shown on the cover page (e.g. "v1.0.0"). |
| `\setdocdate{2026-09-12}` | Document date, shown on the cover page next to the version. |
| `\setdocauthors{John Smith, Jane Doe}` | One or more authors displayed on the cover page. Optional — if not set, nothing is shown. |

### Document structure
| Command | Purpose |
|---|---|
| `\makecover` | Render the cover. Call right after `\begin{document}`. |
| `\maketoc` | Render the TOC ("Contents" / "Sumário", right-aligned, dotted leaders) and page-break. |
| `\startbody` | Mark body start; **resets page numbering to 1** and restores header (logo + title). |

### Headings — use standard section commands (template restyles them)
| Command | Result |
|---|---|
| `\section{...}` | H1: 56pt chapter number (left) + 20pt bold right-aligned title + red rule. New page. In TOC. Use for test domains. |
| `\subsection{...}` | H2: 18pt regular, left-aligned (`1.1`). Auto-generated by `testcase` environment. |
| `\subsubsection{...}` | H3: 16pt regular (`1.1.1`). |
| `\paragraph{...}` | H4: 14pt regular (`1.1.1.1`). |

Starred forms (`\section*{...}`) drop the number and the TOC entry.
**Note:** `\section*` also triggers `\clearpage` (every H1 starts on a new
page, including unnumbered ones).
Numbering is automatic: `1` / `1.1` / `1.1.1` / `1.1.1.1`.

### Test case environment

The `testcase` environment is the core building block. Each test case is
rendered as a caption-style heading (bold **Testcase N:** + description,
like figure/table captions) followed by a **breakable tcolorbox** with a
3pt Huawei-red left-rule. Fields are **stacked blocks**: each field shows a
full-width red mini header bar (Huawei-red background, white bold text)
followed by the content below it. This design allows images, code blocks,
callout boxes, and nested content to render correctly and break
across pages.

**Auto-numbering:** The `testcase` environment automatically numbers each test
case using a global counter (1, 2, 3, …). The rendered heading is
**Testcase *N*:** *title* (English) or **Caso de Teste *N*:** *title* (Portuguese),
formatted as a caption — the "Testcase N:" prefix is bold and the description
follows in regular text, matching the style of figure/table captions.
Do **not** include manual prefixes like "TC-001:" in the title argument — the
environment adds the number for you.

**Field order:** Objective → Prerequisites → Procedure → Expected Result →
Test Result → Remarks. Test Result and Remarks are filled after execution,
hence they appear last. The `noanswers` class option hides Test Result and
Remarks fields.

```latex
\begin{testcase}{Verify MRS cluster deployment}
  \testobjective{Confirm that the MRS cluster is deployed.}
  \begin{testprerequisites}
    \teststep{Terraform apply completed.}
  \end{testprerequisites}
  \begin{testprocedure}
    \teststep{Log in to the Huawei Cloud Console}
    \teststep{Navigate to MapReduce Service, Clusters}
    \teststep{Verify cluster status is Running}
  \end{testprocedure}
  \begin{testexpected}
    \teststep{Cluster status is Running.}
  \end{testexpected}
  \testresult{\testresultbadge{Pass}}
  \testremarks{If any component shows Abnormal, check alarms.}
\end{testcase}
```

This renders as **Testcase 1:** Verify MRS cluster deployment (the number
is automatic — the next `testcase` will be "Testcase 2: ...").

| Field command | English label | Portuguese label | Required |
|---|---|---|---|
| `\testobjective{...}` | Objective | Objetivo | Yes |
| `\begin{testprerequisites}...\end{testprerequisites}` | Prerequisites | Pré-requisitos | Yes |
| `\begin{testprocedure}...\end{testprocedure}` | Procedure | Procedimento | Yes |
| `\begin{testexpected}...\end{testexpected}` | Expected Result | Resultado Esperado | Yes |
| `\testresult{...}` | Test Result | Resultado do Teste | No (hidden by `noanswers`) |
| `\testremarks{...}` | Remarks | Observações | No (hidden by `noanswers`) |

**Formatting notes:**
- `testprerequisites` and `testexpected` are environments (like
  `testprocedure`) that render a mini header bar followed by auto-numbered
  `\teststep` items. Use `\teststep{...}` inside them — do not use
  `testlist` or `\item`.
- Each field is preceded by a full-width red mini header bar (Huawei-red
  background, white bold text), with the content rendered below it.
- The box has a 3pt Huawei-red left-rule and breaks across pages.
- `\testresult` and `\testremarks` are suppressed by the `noanswers` class
  option — use this when generating a "blank" test book for testers to fill
  in by hand.

### Test summary table

The `testsummary` environment renders a 3-column overview table (ID, Title,
Status) with a Huawei-red header. Use it to provide an at-a-glance summary
of all test cases and their results. The ID column should use the auto-number
from the `testcase` environment (1, 2, 3, …) — not manual TC-XXX prefixes.

```latex
\begin{testsummary}
  \testsummaryrow{1}{Verify MRS cluster deployment}{\testresultbadge{Pass}}
  \testsummaryrow{2}{Verify OBS bucket creation}{\testresultbadge{Pass}}
  \testsummaryrow{3}{Verify VPC configuration}{\testresultbadge{Fail}}
\end{testsummary}
```

| Command | Purpose |
|---|---|
| `\begin{testsummary} ... \end{testsummary}` | 3-column summary table (ID, Title, Status). |
| `\testsummaryrow{id}{title}{status}` | One row in the summary table. |

**Language-aware labels:** Column headers adapt to the class option:
- English (default): **ID**, **Title**, **Status**
- Portuguese (`[portuguese]`): **ID**, **Título**, **Status**

### `testprocedure` environment

Renders the "Procedure" mini header bar followed by auto-numbered step
paragraphs. Each `\teststep` is rendered as a red bold step number followed
by the action text. Steps are numbered automatically (1, 2, 3, …).
Images, code blocks, and callouts can be placed freely between steps.

```latex
\begin{testprocedure}
  \teststep{Log in to Console}
  \teststep{Click Create and set parameters}
  \image[width=0.8\linewidth]{common-assets/screenshot.png}
  \teststep{Verify the instance is created}
\end{testprocedure}
```

| Command | Purpose |
|---|---|
| `\begin{testprocedure} ... \end{testprocedure}` | Procedure mini header bar + auto-numbered step paragraphs. |
| `\teststep{action_description}` | One step: red bold auto-numbered step number + action text. Numbering is automatic. |

**Language-aware label:** The mini header bar text adapts to the class option:
- English (default): **Procedure**
- Portuguese (`[portuguese]`): **Procedimento**

### `testlist` environment

Styled enumerate with red bold numbers, matching the teststep styling.
Available for use inside `\testremarks{...}` or other fields that need
a numbered list. Items are auto-numbered — do not include the number
in the `\item` text.

> **Note:** `testprerequisites` and `testexpected` are now environments
> that use `\teststep` directly (like `testprocedure`). Do not use
> `testlist` inside them.

```latex
\testremarks{
  \begin{testlist}
    \item First observation.
    \item Second observation.
  \end{testlist}
}
```

| Command | Purpose |
|---|---|
| `\begin{testlist} ... \end{testlist}` | Numbered list with red bold auto-numbered items. Use inside `\testremarks{...}` or other fields. |
| `\item` | One item in the list. Numbering is automatic. |

### Test steps

The `\teststep` command renders an auto-numbered step paragraph inside
`testprocedure`. Each step shows a red bold step number followed by the
action text. Numbering is automatic — do not include the step number as
an argument.

```latex
\begin{testprocedure}
  \teststep{Log in to Console}
  \teststep{Click Create}
  \teststep{Enter parameters and submit}
\end{testprocedure}
```

| Command | Purpose |
|---|---|
| `\teststep{action}` | One step: red bold auto-numbered step number + action text. |

**Note:** The `teststeps` environment (2-column step table) was removed in
v4.2.0. Steps are now auto-numbered paragraphs inside `testprocedure`.

### Result badge

The `\testresultbadge` command renders a visual status badge with
color-coded background: green for Pass, red for Fail, orange for Blocked,
gray for Untested.

```latex
\testresultbadge{Pass}      % green badge
\testresultbadge{Fail}      % red badge
\testresultbadge{Blocked}   % orange badge
\testresultbadge{Untested}  % gray badge
```

| Command | Color | Use |
|---|---|---|
| `\testresultbadge{Pass}` | Green background, white text | Test step/case passed. |
| `\testresultbadge{Fail}` | Red background, white text | Test step/case failed. |
| `\testresultbadge{Blocked}` | Orange background, white text | Test step/case blocked by dependency. |
| `\testresultbadge{Untested}` | Gray background, white text | Test step/case not yet executed. |

**Badge labels are not translated** — they always display in English
(Pass, Fail, Blocked, Untested) regardless of the `portuguese` class option.

**Tip:** Use `\testresultbadge` inside `\testresult{}` for the test case
result:

```latex
\testresult{\testresultbadge{Pass}}
```

### Code
| Command | Result |
|---|---|
| `\begin{code} ... \end{code}` | Code block: `#F6F8FA` bg, Cascadia Code 10pt, `#1F2328` text, left-indented, no border. **Verbatim** — `_{}^\` are literal, no escaping. Clean copy-paste from PDF. |
| `\begin{code}[bash] ... \end{code}` | Same; the `[bash]` hint is accepted for backward compatibility but ignored (no syntax highlighting). |
| `\codefile[language]{file}` | Code block from an external file. |
| `\inlinecode{...}` | Inline monospace code. **Standard LaTeX escaping rules apply** here. |
| `\codefont` | Selects the monospace font (Cascadia Code with fallback). Used internally by `code` and `\inlinecode`; available for advanced customization. |
| `\param{...}` | Filename/parameter in italic (e.g. `\param{provider.tf}`). |

**Gotcha:** inside `code`, write code literally — no escaping. In running text
use `\inlinecode{...}` and escape LaTeX specials normally.

### Images (always horizontally centered)

| Command | Result |
|---|---|
| `\image{file}` | Centered image, default `width=0.9\linewidth`, `height=0.5\textheight` (`keepaspectratio`). |
| `\image[width=0.8\linewidth]{file}` | Custom width, default height. |
| `\image[height=0.3\textheight]{file}` | Custom height, default width. |
| `\image[width=0.9\linewidth, height=0.5\textheight]{file}` | Both custom. |
| `\imagecap{file}{caption}` | Centered image with **numbered** caption ("Figure 1: ..."). Same options as `\image`. |
| `\imagecap[width=0.8\linewidth]{file}{caption}` | Custom width with caption. |
| `\imageplaceholder{path}{description}` | Dashed placeholder box showing where to put the image. Use when the image file is not yet available. |

**Caption best practice:** do **not** include "Figure N" or "Table N" in the
caption text — the class adds the prefix automatically ("Figure 1: ...",
"Table 1: ..."). Write only the description: `\imagecap{file}{Console login
screen.}` produces "Figure 1: Console login screen.".

### Tables

Tables use a Huawei-branded full-grid style via the `hutable` environment:
red rules on all four sides and between every row, a Huawei-red header bar
with white bold text, and alternating white / light-gray body rows. The class
loads `booktabs`, `array`, and `colortbl` (via `xcolor[table]`); rules are
colored in Huawei red and caption labels ("Table N:") are bold black.

**Float placement:** `figure` and `table` floats default to `[H]` (here,
exactly) so they appear in source order and never drift. Wrap `hutable` in a
`table` float for the caption. Users may still override with `[h]`, `[t]`,
`[b]`, or `[p]` per float.

**Rules:**
- Use `hutable` (not raw `tabular`) — it applies `\centering\small`, the full
  grid, and the top border automatically.
- Header row: `\rowcolor{huaweired}` + `\thd{...}` per cell (white bold on red),
  ended by `\\`.
- After the header `\\`, add `\tbody` to start alternating body row colors
  (white / light gray).
- Body rows: plain cells, black text on alternating white / light-gray rows.
- Every row MUST end with `\\` (including the last) so the bottom border draws.
- Do not add `\midrule`, `\bottomrule`, `\centering`, or `\small` — `hutable`
  handles them. Do not include "Table N" in the caption — the class adds it.
- Column spec uses `|` for vertical borders, e.g. `{|l|l|l|}`.
- `hutable` uses `\hline` (red via `\arrayrulecolor`) for all horizontal rules — `\hline` is required so `colortbl` `\rowcolor` fills the row background cleanly (booktabs `\midrule` leaves uncolored gaps). Do not add `\hline`, `\midrule`, or `\bottomrule` inside `hutable`.

```latex
\begin{table}[H]
  \begin{hutable}{|l|l|l|}
    \rowcolor{huaweired} \thd{Column A} & \thd{Column B} & \thd{Column C} \\
    \tbody
    Row 1 & Value & Value \\
    Row 2 & Value & Value \\
  \end{hutable}
  \caption{Table caption.}
\end{table}
```

### `longhutable` — page-breaking table

Same visual style as `hutable` (full-grid, Huawei-red header, alternating rows) but uses
`longtable` for page breaking. Use for tables with many rows that don't fit on one page.

Usage:
```latex
\begin{longhutable}{|l|l|l|}
  \rowcolor{huaweired} \thd{Col A} & \thd{Col B} & \thd{Col C} \\
  \endhead
  \tbody
  row 1 & value & value \\
  row 2 & value & value \\
\end{longhutable}
```

Rules:
- **Must NOT be wrapped in `\begin{table}`** — longtable is not a float.
- Add `\endhead` after the header row to repeat it on page breaks.
- Without `\endhead`, the header appears only on the first page.
- **Cannot be used inside `testcase`** — longtable requires top-level.

### Notes & links
| Command | Result |
|---|---|
| `\note{...}` | Italic observation paragraph. |
| `\weblink{url}{text}` | Blue (`#0000FF`), no underline, clickable. |
| `\menu{A, B, C}` | Menu path: **A** → **B** → **C** (bold items joined by arrows). |
| `\href{url}{text}` | Standard `hyperref` link (also blue via `urlcolor`). |
| `\textbf{...}` | Bold — use for UI terms (e.g. **Console**). |

### Callout boxes
| Environment | Color | Use |
|---|---|---|
| `\begin{warning} ... \end{warning}` | Amber bg, red **"Important"** label | Warning / caution — potential pitfalls. |
| `\begin{tip} ... \end{tip}` | Green bg, green **"Tip"** label | Tip / suggestion — best practices. |
| `\begin{infobox} ... \end{infobox}` | Blue bg, blue **"Info"** label | Informational note — helpful context. |

All boxes are breakable across pages and have a 3pt left border. Labels are
language-aware (e.g. "Importante" in Portuguese) and appear as bold colored
text at the top of the box content.

### Badge
| Command | Result |
|---|---|
| `\badge{...}` | Inline red label with white text (e.g. `\badge{New}`). |

### Objectives / prerequisites block
```latex
\begin{objectives}
  \generalobjective{<general objective>}
  \objective{<objective>}
  \prerequisites
  \begin{itemize}
    \item ...
  \end{itemize}
\end{objectives}
```
Closes with a 1.5pt horizontal rule. `\objective` and `\stepbystep` also
work outside `objectives` (e.g. inside a subsection).

| Command | Produces |
|---|---|
| `\generalobjective{...}` | **"General Objective:"** / **"Objetivo Geral:"** (bold label) + text. |
| `\objective{...}` | **"Objective:"** / **"Objetivo:"** + text. |
| `\prerequisites` | **"Prerequisites:"** / **"Pré-requisitos:"** label (put a list after). |
| `\stepbystep` | **"Step by step:"** / **"Passo a passo:"** label (put a numbered list after). |

### Changelog / Versioning
| Command | Purpose |
|---|---|
| `\setdocversion{1.0.0}` | Sets the version shown on the cover page. |
| `\setdocdate{2026-09-12}` | Sets the date shown on the cover page. **Optional** — defaults to `\today` if omitted. |
| `\begin{changelog} ... \end{changelog}` | Version history block with auto-emitted section heading (framed with horizontal rules). Do not add a `\section` before it. |
| `\changelogentry{version}{date}{items}` | One entry inside `changelog`. `items` is an `itemize` body. |

Example:

```latex
\begin{changelog}
  \changelogentry{1.0.0}{2026-09-12}{
    \item Initial version.
    \item Added ECS provisioning test cases.
  }
  \changelogentry{0.9.0}{2026-08-15}{
    \item Draft.
  }
\end{changelog}
```

### Versioning workflow (for AI-assisted edits)

**Every AI-assisted change to a document must bump the version and add a
changelog entry.** This ensures the PDF always reflects what changed and when.

#### Steps (after making content edits):

1. **Determine the bump level:**
   - **Patch** (`1.0.0` → `1.0.1`): typo fixes, wording tweaks, small corrections.
   - **Minor** (`1.0.0` → `1.1.0`): new test cases, new test domains, new content.
   - **Major** (`1.0.0` → `2.0.0`): structural changes, removed test domains, breaking reorganization.

2. **Update `\setdocversion{...}`** in the preamble with the new version.

3. **Add a `\changelogentry` at the top of the `changelog` block** (newest first):
   ```latex
   \changelogentry{1.0.1}{2026-09-12}{
     \item Fixed typo in TC-003.
     \item Added VPC test cases to section 2.
   }
   ```

4. **Recompile** with `make project DIR=documents/<project-name>` to produce
   the updated PDF.

5. **Report** the new version number to the user.

#### Disabling the changelog

When the changelog becomes too large, add the `nochangelog` class option to
suppress it from the PDF:

```latex
\documentclass[nochangelog]{testbook}
```

The environment and all `\changelogentry` calls become no-ops — nothing is
rendered, but the content remains in the `.tex` file for future reference.

---

## Class options

```latex
\documentclass[portuguese,indentbody,notime,nochangelog,noauthors,noanswers]{testbook}
```
- `portuguese` — switches all predefined labels to Portuguese and loads `babel`
  with `brazilian`. Default off (English).
- `indentbody` — indents all running text by `\contentindent` (0.6cm). Default
  off (text flush to the left margin).
- `notime` — hides the compilation time on the cover page. Default off
  (time is shown).
- `nochangelog` — suppresses the changelog section entirely (heading + entries) and hides version, date, and time on the cover page. The `changelog` environment emits its own heading, so this one option hides everything. Default off (changelog is shown).
- `noauthors` — hides the authors on the cover page. Default off (authors are shown if set via `\setdocauthors`).
- `noanswers` — hides the **Test Result** and **Remarks** fields in all test cases. Use this to produce a "blank" test book for testers to fill in by hand. Default off (all fields shown).

---

## Colors (defined in `templates/_base/huawei-colors.sty`, reusable via `\textcolor{name}{...}`)
| Name | Hex | Use |
|---|---|---|
| `codebg` | `#F6F8FA` | Code block background |
| `codetext` | `#1F2328` | Code text |
| `linkblue` | `#0000FF` | Links |
| `huaweired` | `#C7000B` | Brand red (H1 chapter rules, test case left-rule and labels, accents, badge) |
| `ruleblack` | `#000000` | Horizontal rules (TOC, objectives) |
| `warningbg` | `#FFF8E1` | Warning box background |
| `warningfg` | `#F57C00` | Warning box border |
| `tipbg` | `#E8F5E9` | Tip box background |
| `tipfg` | `#2E7D32` | Tip box border |
| `infobg` | `#E3F2FD` | Info box background |
| `infofg` | `#1565C0` | Info box border |

---

## Format reference

See [templates/testbook/README.md](README.md) for the format reference table
(page size, margins, fonts, colors, spacing).

---

## Compilation

```bash
make project DIR=documents/<project-name>   # from repo root (recommended)
```

Or `cd src/ && latexmk main.tex` from inside the project folder. See [README.md](../../README.md)
for the full Makefile reference and multi-format output options.

**Never use pdflatex** — the class loads `fontspec` which requires XeLaTeX.

---

## Multi-format output

LaTeX → PDF is the primary output. DOCX, Markdown, and HTML are generated
via Pandoc + the Lua filter:

```bash
# Markdown
pandoc --lua-filter=templates/testbook/testbook-pandoc.lua \
  -f latex+raw_tex -t markdown -o output.md input.tex

# HTML
pandoc --lua-filter=templates/testbook/testbook-pandoc.lua \
  --template=templates/testbook/testbook-template.html \
  -f latex+raw_tex -t html5 --standalone -o output.html input.tex

# DOCX
pandoc --lua-filter=templates/testbook/testbook-pandoc.lua \
  --reference-doc=templates/testbook/testbook-reference.docx \
  -f latex+raw_tex -t docx -o output.docx input.tex
```

---

## Customization pointers

See [templates/testbook/README.md](README.md) for customization options
(logos, colors, fonts, sizes/spacing).

---

## Agent workflow checklist
1. Confirm the engine: never run `pdflatex`. Use `xelatex` (twice) or
   `latexmk` (handles it via `.latexmkrc`).
2. Edit `.tex` files for content; touch `testbook.cls` only for look-and-feel
   changes the user explicitly requested.
3. Keep body order: `\makecover` → `\maketoc` → `\startbody` → sections →
   `changelog` → `\end{document}`.
4. Follow the 3-section structure: Section 1 Introduction (objectives, scope,
   preconditions, acceptance method), Section 2 Test Cases (subsections per
   domain with auto-numbered `testcase` environments), Section 3 Conclusion
   (test summary table).
5. Use the `testcase` environment for each test case — do not manually create
   subsections and tables.
6. Inside `code`, write literal code. In prose, use `\inlinecode{...}` with normal
   escaping.
7. After edits, compile and check the PDF (TOC + page numbers need the
   second pass).
8. **After any content change, bump the version and add a changelog entry**
   (see Versioning workflow above). Recompile to produce the updated PDF.
9. If a font is missing, the class warns and falls back — the build still
   succeeds; surface the warning to the user but do not block.
10. For Portuguese (`[portuguese]`) documents, after compiling run
   `grep -i "Missing character" main.log` — it must be empty.
11. Use `noanswers` class option when producing blank test books for
     manual test execution (hides Test Result and Remarks fields).
