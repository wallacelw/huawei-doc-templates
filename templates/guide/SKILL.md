---
name: huawei-template-guide
description: Create or edit Huawei Cloud guide documents using the LaTeX guide template. Use when the user wants to write, extend, or fix a guide, or asks to create a new document for Huawei Cloud. Triggers on keywords like huawei-template-guide, huawei guide, guia huawei, Huawei Cloud document.
---

# Huawei Cloud Guide — Skill

Create, edit, and compile Huawei Cloud guide documents using the
`guide` LaTeX class in this directory.

## When to use

Use this skill when the task is to **write, extend, or fix a Huawei Cloud
guide**. The output is a PDF compiled from LaTeX. Content defaults to
English; pass the `portuguese` class option for Portuguese labels
("Guia"). Do **not** use this for general LaTeX documents — the formatting is
hard-coded to the Huawei house style.

## Context loading (do this first)

Before creating or editing any document, read these files to load the full
project context:

1. **`templates/guide/guide.cls`** — the class file. Shared formatting lives in
   `templates/_base/huawei-*.sty` modules. Guide-specific formatting (cover, TOC,
   titles) lives in `guide.cls`. Every command and environment available to
   documents is defined across these files.
2. **`README.md`** (repo root) — project setup, compilation instructions,
   install steps, and project layout. Needed to understand the toolchain and
   folder conventions.
3. **`AGENTS.md`** (repo root) — locked decisions (see AGENTS.md), file editing
   rules, versioning workflow, and project standards. These are mandatory
   constraints that must not be violated.
4. **`templates/guide/README.md`** — human-readable template overview (class
   options, label translations, format reference, customization).

Read all four files before proceeding to the Quick start below. Do not
guess command names, class options, or formatting conventions — look them
up in the class file and this SKILL.md.

---

## Quick start — creating a new document

1. **Ask for the essentials** (if not already provided):
   - **Title** — e.g. "Provisioning an ECS Instance"
   - **Language** — English (default) or Portuguese
   - **Project name** — used as the folder name (e.g. `ecs-provisioning`)

2. **Create a self-contained project folder** at `documents/<project-name>/`:
   - **Always create a subfolder inside `documents/`** — never scatter files
     directly in the workspace root or `documents/` itself.
   - Inside the folder, create:
     - `src/` subfolder containing:
       - `<filename>.tex` — the document, using the skeleton below.
       - `.latexmkrc` — with `TEXINPUTS` pointing to this template directory.
         From `documents/<project-name>/src/`, the relative path to
         `templates/guide/` is `../../../templates/guide/`:
         ```perl
         $ENV{TEXINPUTS} = "../../../templates/_base/:../../../templates/guide/:" . ($ENV{TEXINPUTS} || "");
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

3. **Compile and verify** with `make project DIR=documents/<project-name>`
   (or `cd src/ && latexmk <filename>.tex` from inside the project folder).

4. **Report** the page count and any warnings to the user.

---

## Hard requirements

- **Engine: XeLaTeX or LuaLaTeX only.** The class loads `fontspec`, so
  `pdflatex` will fail. Always compile with `xelatex` (or `lualatex`).
- **Compile twice** on the first run so the TOC and page numbers settle.
  `latexmk` handles this automatically (`.latexmkrc` is included).
- **fvextra ≥ 1.5** — provides `backgroundcolor` for code blocks. TeX Live
  2024+ includes it; on older installs, update from CTAN or run `install.sh`.
- **Fonts:** HarmonyOS Sans (body) + Cascadia Code (code). Falls back with
  a warning if missing (see AGENTS.md L8). `install.sh` installs both.

---

## Document skeleton

### English (default)

```latex
\documentclass{guide}

\setguidetitle{Guide: <topic>}
\setheadertitle{Huawei Cloud -- <short title>}
\setcovertext{Huawei Technologies CO., LTD}
\setdocversion{1.0.0}
\setdocdate{\today}

\begin{document}
\makecover
\maketoc
\startbody

\section{<chapter title>}

\begin{objectives}
  \generalobjective{<general objective>}
  \prerequisites
  \begin{itemize}
    \item <prerequisite 1>
    \item <prerequisite 2>
  \end{itemize}
\end{objectives}

\subsection{<section title>}
\objective{<objective}

\stepbystep
\begin{enumerate}
  \item <step 1>
  \item <step 2>
\end{enumerate}

% --- Changelog (after all sections, before \end{document}) ---
\begin{changelog}
  \changelogentry{1.0.0}{2026-08-08}{
    \item Initial version.
  }
\end{changelog}

\end{document}
```

### Portuguese

Same skeleton but with `\documentclass[portuguese]{guide}`. Labels switch
automatically: *Sumário*, *Objetivo Geral:*, *Objetivo:*,
*Pré-requisitos:*, *Passo a passo:*, *Página*.

Body order is fixed: `\makecover` → `\maketoc` → `\startbody` → sections.

**Accent verification (PT-BR).** The Portuguese sample includes a diacritic
test line in its first `infobox` that exercises every Portuguese accent
(`á à â ã ç é ê í ó ô õ ú`, `Á À Â Ã Ç É Ê Í Ó Ô Õ Ú`). After compiling the
sample, confirm no glyphs are missing:

```sh
make pt                               # compile Portuguese sample
grep -i "Missing character" examples/guide/pt/main.log   # must produce no output
```

XeLaTeX emits `Missing character: There is no <glyph>` for any code point the
active font lacks. The brand fonts (HarmonyOS Sans, fallback Liberation Sans)
provide full PT-BR coverage; a custom font that drops a diacritic will surface
here. Run this check after every sample compile — the grep is the only extra step.

---

## Project layout (this directory)

```
templates/guide/
├── guide.cls          # guide-specific formatting (cover, TOC, titles)
├── guide-pandoc.lua   # Lua filter for Pandoc multi-format output
├── guide-reference.docx  # reference DOCX with Huawei styles
├── guide-template.html   # HTML template for Pandoc
├── create-reference-docx.py  # DOCX reference creation/fix script
├── embed-images.py    # image embedding for self-contained Markdown
├── README.md           # human docs (brief — see root README for setup)
├── SKILL.md            # this file (opencode skill)
├── .latexmkrc          # latexmk config (XeLaTeX by default)
└── common-assets/      # shared template assets (logos, sample images)
    ├── huawei-logo-header.png   # header logo
    ├── huawei-logo-cover.png    # cover logo
    ├── exemplo-menu.png         # sample image
    ├── exemplo-login.png        # sample image
    └── example-script.sh        # example code file for \codefile

# Each document has its own assets/ folder for project-specific files:
examples/guide/
├── pt/
│   ├── src/
│   │   ├── .latexmkrc  # TEXINPUTS → ../../../templates/guide/; $out_dir='..'
│   │   └── main.tex    # Portuguese sample (reference)
│   └── assets/         # project-specific images and files
└── en/
    ├── src/
    │   ├── .latexmkrc
    │   └── main.tex    # English sample (reference)
    └── assets/         # project-specific images and files

# User-created documents go in documents/ (see Quick start):
documents/
└── my-guide/
    ├── src/
    │   ├── .latexmkrc  # TEXINPUTS → ../../../templates/_base/ + ../../../templates/guide/; $out_dir='..'
    │   └── main.tex
    └── assets/
```

**Asset resolution:** when a `.tex` file references `assets/foo.png`, LaTeX
looks in the project's own `assets/` folder first, then falls back to
`common-assets/` in the template directory (via TEXINPUTS). Logos default to
`common-assets/` since they are template-level shared assets.

**Rule of thumb:** content/structure goes in `.tex` files; shared look-and-feel
goes in `templates/_base/huawei-*.sty` modules; guide-specific formatting goes in
`guide.cls`. Do not inline formatting overrides in the document unless the user
asks.

---

## Commands reference

### Preamble configuration
| Command | Purpose |
|---|---|
| `\setguidetitle{...}` | Big cover title. |
| `\setheadertitle{...}` | Centered header text on body pages (cover, TOC, and changelog have no header). |
| `\setcovertext{...}` | Line under the cover logo (default `Huawei Technologies CO., LTD`). |
| `\setheaderlogo{path}` | Header logo image path (default `common-assets/huawei-logo-header.png`). |
| `\setcoverlogo{path}` | Cover logo image path (default `common-assets/huawei-logo-cover.png`). |
| `\setdocversion{1.0.0}` | Document version, shown on the cover page (e.g. "v1.0.0"). |
| `\setdocdate{2026-08-05}` | Document date, shown on the cover page next to the version. |

### Document structure
| Command | Purpose |
|---|---|
| `\makecover` | Render the cover. Call right after `\begin{document}`. |
| `\maketoc` | Render the TOC ("Contents" / "Sumário", right-aligned, dotted leaders) and page-break. |
| `\startbody` | Mark body start; **resets page numbering to 1** and restores header (logo + title). |

### Headings — use standard section commands (template restyles them)
| Command | Result |
|---|---|
| `\section{...}` | H1: 56pt chapter number (left) + 20pt bold right-aligned title + red rule. New page. In TOC. |
| `\subsection{...}` | H2: 18pt regular, left-aligned (`1.1`). |
| `\subsubsection{...}` | H3: 16pt regular (`1.1.1`). |
| `\paragraph{...}` | H4: 14pt regular (`1.1.1.1`). |

Starred forms (`\section*{...}`) drop the number and the TOC entry.
**Note:** `\section*` also triggers `\clearpage` (every H1 starts on a new
page, including unnumbered ones).
Numbering is automatic: `1` / `1.1` / `1.1.1` / `1.1.1.1`.

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

### Lists
Use standard `itemize` / `enumerate` — indent and spacing are already set by the
class. Do not pass `enumitem` options unless asked.

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

**Policy: avoid images by default.** Guides should be text-driven. Only add an
image when the user explicitly asks for one.

**Workflow when a user requests an image:**
1. The AI inserts `\imageplaceholder{assets/filename.png}{description}` at the
   desired location in the `.tex` file.
2. The AI creates the `assets/` folder in the project directory (if needed) and
   tells the user the exact path to place the file.
3. The user manually adds the image file at that path.
4. The AI replaces `\imageplaceholder` with `\image` or `\imagecap` once the
   file is in place.

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

### Changelog / Versioning
| Command | Purpose |
|---|---|
| `\setdocversion{1.0.0}` | Sets the version shown on the cover page. |
| `\setdocdate{2026-08-05}` | Sets the date shown on the cover page. **Optional** — defaults to `\today` if omitted. |
| `\begin{changelog} ... \end{changelog}` | Version history block with auto-emitted section heading (framed with horizontal rules). Do not add a `\section` before it. |
| `\changelogentry{version}{date}{items}` | One entry inside `changelog`. `items` is an `itemize` body. |

Example:

```latex
\begin{changelog}
  \changelogentry{1.0.0}{2026-08-05}{
    \item Initial version.
    \item Added ECS provisioning.
  }
  \changelogentry{0.9.0}{2025-07-15}{
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
   - **Minor** (`1.0.0` → `1.1.0`): new sections, new content, new features.
   - **Major** (`1.0.0` → `2.0.0`): structural changes, removed sections, breaking reorganization.

2. **Update `\setdocversion{...}`** in the preamble with the new version.

3. **Add a `\changelogentry` at the top of the `changelog` block** (newest first):
   ```latex
   \changelogentry{1.0.1}{2026-08-08}{
     \item Fixed typo in section 2.
     \item Updated ECS instance type table.
   }
   ```

4. **Recompile** with `make project DIR=documents/<project-name>` to produce
   the updated PDF.

5. **Report** the new version number to the user.

#### Disabling the changelog

When the changelog becomes too large, add the `nochangelog` class option to
suppress it from the PDF:

```latex
\documentclass[nochangelog]{guide}
```

The environment and all `\changelogentry` calls become no-ops — nothing is
rendered, but the content remains in the `.tex` file for future reference.

---

## Class options

```latex
\documentclass[portuguese,indentbody,notime,nochangelog]{guide}
```
- `portuguese` — switches all predefined labels to Portuguese and loads `babel`
  with `brazilian`. Default off (English).
- `indentbody` — indents all running text by `\contentindent` (0.6cm). Default
  off (text flush to the left margin).
- `notime` — hides the compilation time on the cover page. Default off
  (time is shown).
- `nochangelog` — suppresses the changelog section entirely (heading + entries) and hides version, date, and time on the cover page. The `changelog` environment emits its own heading, so this one option hides everything. Default off (changelog is shown).

---

## Colors (defined in `templates/_base/huawei-colors.sty`, reusable via `\textcolor{name}{...}`)
| Name | Hex | Use |
|---|---|---|
| `codebg` | `#F6F8FA` | Code block background |
| `codetext` | `#1F2328` | Code text |
| `linkblue` | `#0000FF` | Links |
| `huaweired` | `#C7000B` | Brand red (H1 chapter rules, accents, badge) |
| `ruleblack` | `#000000` | Horizontal rules (TOC, objectives) |
| `warningbg` | `#FFF8E1` | Warning box background |
| `warningfg` | `#F57C00` | Warning box border |
| `tipbg` | `#E8F5E9` | Tip box background |
| `tipfg` | `#2E7D32` | Tip box border |
| `infobg` | `#E3F2FD` | Info box background |
| `infofg` | `#1565C0` | Info box border |

---

## Format reference

See [templates/guide/README.md](README.md) for the format reference table
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
pandoc --lua-filter=templates/guide/guide-pandoc.lua \
  -f latex+raw_tex -t markdown -o output.md input.tex

# HTML
pandoc --lua-filter=templates/guide/guide-pandoc.lua \
  --template=templates/guide/guide-template.html \
  -f latex+raw_tex -t html5 --standalone -o output.html input.tex

# DOCX
pandoc --lua-filter=templates/guide/guide-pandoc.lua \
  --reference-doc=templates/guide/guide-reference.docx \
  -f latex+raw_tex -t docx -o output.docx input.tex
```

---

## Customization pointers

See [templates/guide/README.md](README.md) for customization options
(logos, colors, fonts, sizes/spacing).

---

## Agent workflow checklist
1. Confirm the engine: never run `pdflatex`. Use `xelatex` (twice) or
   `latexmk` (handles it via `.latexmkrc`).
2. Edit `.tex` files for content; touch `guide.cls` only for look-and-feel
   changes the user explicitly requested.
3. Keep body order: `\makecover` → `\maketoc` → `\startbody` → sections →
   `changelog` → `\end{document}`.
4. Inside `code`, write literal code. In prose, use `\inlinecode{...}` with normal
   escaping.
5. After edits, compile and check the PDF (TOC + page numbers need the
   second pass).
6. **After any content change, bump the version and add a changelog entry**
   (see Versioning workflow above). Recompile to produce the updated PDF.
7. If a font is missing, the class warns and falls back — the build still
   succeeds; surface the warning to the user but do not block.
8. For Portuguese (`[portuguese]`) documents, after compiling run
   `grep -i "Missing character" main.log` — it must be empty. The pt sample's
   first `infobox` exercises every PT-BR diacritic, so any missing glyph surfaces
   here (see "Accent verification (PT-BR)" above).
