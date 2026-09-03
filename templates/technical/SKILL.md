---
name: huawei-template-technical
description: Create or edit Huawei Cloud technical reports using the LaTeX technical report template. Use when the user wants to write, extend, or fix a technical report, analysis report, or incident report for Huawei Cloud. Triggers on keywords like huawei-template-technical, huawei report, technical report, analysis report, relatório técnico, incident report.
---

# Huawei Cloud Technical Report — Skill

Create, edit, and compile Huawei Cloud technical reports using the
`technical` LaTeX class in this directory. The output is a PDF compiled
from LaTeX; DOCX, Markdown, and HTML are generated via Pandoc.

## When to use

Use this skill when the task is to **write, extend, or fix a Huawei Cloud
technical report**. Technical reports follow a fixed 6-section structure
(problem → root cause analysis → root cause → trigger condition →
workaround). The output is a PDF compiled from LaTeX. Content defaults to
English; pass the `portuguese` class option for Portuguese labels. Do
**not** use this for general LaTeX documents — the formatting is
hard-coded to the Huawei house style (AGENTS.md L9).

## Context loading (do this first)

Before creating or editing any document, read these files to load the full
project context:

1. **`templates/technical/technical.cls`** — the class file. Shared formatting
   lives in `templates/_base/huawei-*.sty` modules. Technical-specific
   formatting (cover page, 6-section environments) lives in `technical.cls`.
2. **`README.md`** (repo root) — project setup, compilation instructions,
   install steps, and project layout.
3. **`AGENTS.md`** (repo root) — locked decisions, file editing rules,
   versioning workflow, and project standards.
4. **`templates/technical/README.md`** — human-readable template overview.

Read all four files before proceeding to the Quick start below.

---

## Quick start — creating a new report

1. **Ask for the essentials** (if not already provided):
   - **Title** — e.g. "[Analysis Report] ECS Creation Page Issue"
   - **Language** — English (default) or Portuguese
   - **Project name** — used as the folder name (e.g. `ecs-issue-report`)

2. **Create a self-contained project folder** at `documents/<project-name>/`:
   - Inside the folder, create:
     - `src/` subfolder containing:
       - `main.tex` — the document, using the skeleton below.
       - `.latexmkrc` — with `TEXINPUTS` pointing to the template directories.
         From `documents/<project-name>/src/`, the relative path to
         `templates/technical/` is `../../../templates/technical/`:
         ```perl
         $ENV{TEXINPUTS} = "../../../templates/_base/:../../../templates/technical/:" . ($ENV{TEXINPUTS} || "");
         $pdf_mode = 5;
         $xelatex = 'xelatex -interaction=nonstopmode %O %S';
         $out_dir = '..';
         $aux_dir = '.';
         ```
     - `assets/` subfolder for project-specific images.

3. **Compile and verify** with `cd src/ && latexmk main.tex`.

4. **Report** the page count and any warnings to the user.

---

## Hard requirements

- **Engine: XeLaTeX or LuaLaTeX only.** The class loads `fontspec`, so
  `pdflatex` will fail. Always compile with `xelatex` (or `lualatex`).
- **Compile twice** on the first run so the TOC and page numbers settle.
  `latexmk` handles this automatically (`.latexmkrc` is included).
- **Fonts:** HarmonyOS Sans (body) + Cascadia Code (code). Falls back with
  a warning if missing (see AGENTS.md L8). `install.sh` installs both.
- **Pandoc >= 3.0** — required for multi-format output (DOCX, Markdown, HTML).

---

## Document skeleton

### English (default)

```latex
\documentclass{technical}

\setreporttitle{[Analysis Report] <title>}
\setreportversion{HCS <version>}
\setreportdate{<date>}
\setreportscenario{<scenario>}
\setheadertitle{Huawei Cloud -- <short title>}

\begin{document}
\makecover
\maketoc
\startbody

\begin{problem}
<problem description and impact>
\end{problem}

\begin{rootcauseanalysis}
<step-by-step analysis>
\end{rootcauseanalysis}

\begin{rootcause}
<identified root cause>
\end{rootcause}

\begin{triggercondition}
<when the issue occurs>
\end{triggercondition}

\begin{workaround}

  \begin{impact}
  <impact of the workaround>
  \end{impact}

  \begin{backupdata}
  <backup steps or N/A>
  \end{backupdata}

  \begin{workaroundsteps}
  <step-by-step workaround>
  \end{workaroundsteps}

  \begin{verification}
  <how to verify the fix>
  \end{verification}

  \begin{rollback}
  <how to undo the workaround>
  \end{rollback}

  \begin{cleanup}
  <post-fix cleanup steps>
  \end{cleanup}

\end{workaround}

\begin{changelog}
  \changelogentry{1.0.0}{\today}{
    \item Initial version.
  }
\end{changelog}

\end{document}
```

### Portuguese

Same skeleton but with `\documentclass[portuguese]{technical}`. Labels switch
automatically: *Descrição do Problema e Impacto*, *Análise de Causa Raiz*,
*Causa Raiz*, *Condição de Disparo*, *Solução Alternativa e Impacto*, etc.

Body order is fixed: `\makecover` → `\maketoc` → `\startbody` → sections.

---

## Project layout (this directory)

```
templates/technical/
├── technical.cls                    # technical-specific formatting (cover, 6-section envs)
├── technical-pandoc.lua             # Lua filter for DOCX/MD/HTML output
├── technical-template.html          # HTML template for Pandoc
├── create-technical-reference-docx.py  # DOCX reference style generator
├── technical-reference.docx         # reference DOCX with Huawei styles
├── README.md                        # human docs (brief)
├── SKILL.md                         # this file (opencode skill)
├── .latexmkrc                       # latexmk config (XeLaTeX by default)
└── common-assets/                   # shared template assets (logos)
    ├── huawei-logo-header.png
    └── huawei-logo-cover.png

# Samples:
examples/technical/
├── pt/
│   ├── src/
│   │   ├── .latexmkrc
│   │   └── main.tex                # Portuguese sample
│   └── main.pdf                    # compiled output
└── en/
    ├── src/
    │   ├── .latexmkrc
    │   └── main.tex                # English sample
    └── main.pdf

# User-created documents go in documents/:
documents/
└── my-report/
    ├── src/
    │   ├── .latexmkrc
    │   └── main.tex
    └── assets/
```

**Rule of thumb:** content/structure goes in `.tex` files; shared look-and-feel
goes in `templates/_base/huawei-*.sty` modules; technical-specific formatting
goes in `technical.cls`. Do not inline formatting overrides in the document.

---

## Commands reference

### Preamble configuration
| Command | Purpose |
|---|---|
| `\setreporttitle{...}` | Report title (shown on cover page). |
| `\setreportversion{HCS 8.5.1}` | Version info (shown in cover page version table). |
| `\setreportdate{2025-08-13}` | Report date (shown in cover page version table). |
| `\setreportscenario{Standard Scenario}` | Installation scenario (shown in cover page version table). |
| `\setreporttype{...}` | Report type (optional, for custom classification). |
| `\setheadertitle{...}` | Centered header text on body pages. |
| `\setdocversion{1.0.0}` | Document version for changelog (if using changelog). |
| `\setdocdate{\today}` | Document date for changelog. |

### Document structure
| Command | Purpose |
|---|---|
| `\makecover` | Render the cover page with version info table. Call right after `\begin{document}`. |
| `\maketoc` | Render the TOC and page-break. |
| `\startbody` | Mark body start; resets page numbering to 1 and restores header. |

### 6-section environments (the core structure)

All six sections are mandatory in a technical report. They produce
language-aware section headings automatically.

| Environment | Level | English label | Portuguese label |
|---|---|---|---|
| `problem` | Section (H1) | Problem Description and Impact | Descrição do Problema e Impacto |
| `rootcauseanalysis` | Section (H1) | Root Cause Analysis | Análise de Causa Raiz |
| `rootcause` | Section (H1) | Root Cause | Causa Raiz |
| `triggercondition` | Section (H1) | Trigger Condition | Condição de Disparo |
| `workaround` | Section (H1) | Workaround and Impact | Solução Alternativa e Impacto |

The `workaround` environment contains six subsections:

| Environment | Level | English label | Portuguese label |
|---|---|---|---|
| `impact` | Subsection (H2) | Impact | Impacto |
| `backupdata` | Subsection (H2) | Back up data before the workaround | Backup de dados antes da solução alternativa |
| `workaroundsteps` | Subsection (H2) | Workaround | Solução Alternativa |
| `verification` | Subsection (H2) | Verification after the workaround | Verificação após a solução alternativa |
| `rollback` | Subsection (H2) | Rollback Operation | Operação de Rollback |
| `cleanup` | Subsection (H2) | Cleanup Operation | Operação de Limpeza |

### Headings — use standard section commands inside environments
| Command | Result |
|---|---|
| `\section{...}` | H1: 56pt chapter number + bold title + red rule. New page. |
| `\subsection{...}` | H2: 18pt regular, left-aligned. |
| `\subsubsection{...}` | H3: 16pt regular. |
| `\paragraph{...}` | H4: 14pt regular. |

### Callout boxes (shared from _base)
| Environment | English label | Portuguese label | Color |
|---|---|---|---|
| `warning` | Important | Importante | Amber |
| `tip` | Tip | Dica | Green |
| `infobox` | Info | Informação | Blue |

### Tables
Use the `hutable` environment (full-grid, Huawei-red header, alternating
body rows). Do not use raw `tabular` with manual rules.

### Code
| Command | Result |
|---|---|
| `\begin{code} ... \end{code}` | Code block: `#F6F8FA` bg, Cascadia Code 10pt. Verbatim. |
| `\codefile[language]{file}` | Code block from an external file. |
| `\inlinecode{...}` | Inline monospace code. |

### Images
| Command | Result |
|---|---|
| `\image{path}` | Inline image (non-floating). |
| `\imagecap{path}{caption}` | Image with caption. |
| `\imageplaceholder{path}{description}` | Placeholder for missing image. |

### Changelog
```latex
\begin{changelog}
  \changelogentry{1.0.0}{\today}{
    \item Initial version.
  }
\end{changelog}
```
The `changelog` environment emits its own section heading. Use the
`nochangelog` class option to suppress it.

---

## Multi-format output

LaTeX → PDF is the primary output. DOCX, Markdown, and HTML are generated
via Pandoc + the Lua filter:

```bash
# Markdown
pandoc --lua-filter=templates/technical/technical-pandoc.lua \
  -f latex+raw_tex -t markdown -o output.md input.tex

# HTML
pandoc --lua-filter=templates/technical/technical-pandoc.lua \
  --template=templates/technical/technical-template.html \
  -f latex+raw_tex -t html5 --standalone -o output.html input.tex

# DOCX
pandoc --lua-filter=templates/technical/technical-pandoc.lua \
  --reference-doc=templates/technical/technical-reference.docx \
  -f latex+raw_tex -t docx -o output.docx input.tex
```

---

## Class options

| Option | Effect |
|---|---|
| `portuguese` | Portuguese labels (Sumário, section names, etc.). |
| `notime` | Hide compilation time on cover page. |
| `nochangelog` | Suppress changelog section and cover page version/date/time. |
| `indentbody` | Indent first line of paragraphs. |

---

## Compilation

From the project folder:

```bash
cd src/ && latexmk main.tex          # compile to PDF (XeLaTeX)
cd src/ && latexmk -C main.tex       # clean all generated files
```

---

## Agent workflow checklist

1. Read `technical.cls` and this SKILL.md before writing any content.
2. Create a self-contained folder in `documents/<project-name>/`.
3. Write `src/main.tex` using the skeleton above.
4. Write `src/.latexmkrc` with correct `TEXINPUTS` paths.
5. Compile with `latexmk` and verify the PDF.
6. Bump version and add a changelog entry (AGENTS.md L11).
7. For multi-format output, run the Pandoc commands above.
