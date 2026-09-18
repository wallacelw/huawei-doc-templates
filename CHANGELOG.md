# Changelog

All notable changes to the huawei-doc-template project are documented here.
Per-document changelogs are maintained via `\changelogentry` in each `.adoc` file
(inside passthrough blocks).

## v6.1.1 (2026-09-18)

### Fixes

- **SKILL.md skeleton**: Fixed undefined `\signatureblock` → `\signaturecell`
  with explicit `&` and `\\ \hline`.
- **AGENTS.md**: Added poc template to L15, "Adding a new command", and
  "File editing rules" sections. Added `huawei-badges` to module list.
- **README.md**: Fixed project layout tree (malformed markers, duplicate
  `_base/`, missing poc files). Updated stale line counts (converter
  831→728, CSS 367→337). Removed references to deleted files
  (`.luacheckrc`, `tests/cases/`, `tests/expected/`).
- **testbook.cls**: Refactored `\testresultbadge` to use shared
  `\huaweibadge` from `huawei-badges.sty` (eliminates duplicated styling).
- **guide.cls, technical.cls**: Added `\fvset{breaklines,breakanywhere}`
  for consistent code block line breaking across all templates.
- **Converter**: Removed dead role check in `convert_open`. Applied
  `process_text` to `convert_colist` for consistent entity handling.
- **Various**: Updated stale comments, cls dates, and .latexmkrc
  documentation across all templates.

## v6.1.0 (2026-09-18)

### Features

- **New `poc` template** for Proof of Concept and homologation documents.
  - 3-part, 15-section structure (Preamble → Scope & Planning → Conclusion).
  - 7 POC-specific environments: stakeholders table, objective block,
    result badges (Pass/Partial/Fail/Skip), activities list (roman numerals),
    evidence checklist (checkboxes), closing record, signatures.
  - Language-aware labels (Portuguese and English).
  - Two samples (pt + en) with fake data and public Huawei Cloud services.

### New shared module

- `templates/_base/huawei-badges.sty` — generic `\huaweibadge` command
  for colored tcolorbox badges. Used by `\pocresult` in poc.cls.

### Converter changes (additive)

- 7 new role handlers: `objective`, `result-pass/partial/fail/skip`,
  `activities` (roman numeral list), `evidence` (checkbox list).
- Normalized hyphens to underscores in role dispatch (fixes inline span
  roles like `[.result-pass]`).
- Added numeric HTML entity unescaping (`&#8217;` → UTF-8) for smart quotes.
- Added `process_text` helper for list item text processing.

### Fixes

- Fixed `tabularx` + tcolorbox `enhanced jigsaw` conflict in stakeholders
  table (replaced `tabularx` with `tabular` + fixed widths).
- Fixed `\ifodd` conditional inside tabular in signatures environment
  (replaced with explicit `\signaturecell` + `&` / `\\ \hline`).

## v6.0.10 (2026-09-17)

### Fixes

- **Table cell `&` escaping bug**: `&` in table cell content (e.g.,
  "Data Engineering & DataArts Studio") was not being escaped to `\&`
  for LaTeX, causing "Extra alignment tab" compilation errors in testbook
  samples. Fixed by using block-form `gsub` in converter's table cell
  processing (header, body, and footer cells).
- **testbook/en and testbook/pt PDFs now compile successfully** (21 pages each)
  with `\testscope` field rendering correctly.

## v6.0.9 (2026-09-17)

### Features

- **New testcase field: Test Scope** (`\testscope{...}`) — added between
  Objective and Prerequisites in the testcase environment. Contains the
  topics or requirements that the testcase covers.
  - Language-aware: "Test Scope" (en) / "Escopo do Teste" (pt).
  - Added to all 10 testcases in both testbook/en and testbook/pt samples.
  - Documented in SKILL.md command reference table and usage example.

## v6.0.8 (2026-09-17)

### Features

- **Diagram captions with separate counter**: Diagrams now use "Diagram 1:",
  "Diagram 2:", etc. — separate from "Figure N:" used by regular images.
  - New `\diagramcap` command in `huawei-images.sty` with dedicated `diagram` counter.
  - Converter detects `.diagram` role on image nodes and uses `\diagramcap`
    instead of `\imagecap`.
  - All diagram blocks in all 6 samples now have `.diagram` role
    (e.g., `[plantuml.diagram,...]`, `[graphviz.diagram,...]`).

## v6.0.7 (2026-09-17)

### Architecture

- **Core/template inheritance model documented**: `templates/_base/` contains
  core shared components (tables, diagrams, code blocks, images/figures,
  callouts, changelog, colors, fonts, page layout). Each template inherits
  core and adds template-specific features (technical: 5-section structure,
  testbook: testcase/testsummary). Updated AGENTS.md L15 with full model.
- **SKILL.md reorganization**: Each SKILL.md now has clear "Core Components"
  and "Template-Specific Features" sections. Files remain self-sufficient
  (no external references) but clearly distinguish shared vs template-specific.
- **Diagrams as core component**: All 3 diagram types (PlantUML, graphviz,
  mermaid) now demonstrated in all template samples with captions:
  - guide/en, guide/pt: 3 diagrams each (PlantUML + graphviz + mermaid)
  - technical/en, technical/pt: 3 diagrams each
  - testbook/en, testbook/pt: 2 diagrams each (PlantUML + graphviz)
- **Diagram captions**: All diagram blocks now have `.Caption text` titles
  that render as numbered figure captions via `\imagecap`.

### Fixes

- **.gitignore**: Added `examples/*/*/src/` patterns for nested diagram PNGs
  (previous patterns only matched one-level-deep directories).

## v6.0.6 (2026-09-16)

### Fixes

- **guide/pt: Fixed graphviz typo** (`[%label` → `[label` in Deploy node).
- **guide/pt: Fixed missing image** (`console-regions.png` → `\imageplaceholder`
  passthrough, same pattern as guide/en `ecs-flavors.png`).
- **Git cleanup: Untracked diagram PNGs and .asciidoctor cache** — these are
  build artifacts, now properly gitignored. Added `.asciidoctor/` to .gitignore.

### Verification

- guide/en PDF: 13 pages, 695KB — 3 diagrams embedded ✅
- guide/pt PDF: 14 pages, 711KB — 3 diagrams embedded ✅

## v6.0.5 (2026-09-16)

### Fixes

- **Table headers now show Huawei red background**: Added `\rowcolor{huaweired}`
  before header cells in converter. Previously header text was white-on-white
  (invisible) because the red row color was missing.
- **Table header cell content**: Fixed `cell.content` returning Ruby arrays
  (`["Flavor"]` instead of `Flavor`) — now joins arrays before emitting `\thd{}`.

### Features

- **All 3 diagram types now render in PDF**: PlantUML (sequence diagrams),
  graphviz (flowcharts), and mermaid (flowcharts) all generate PNG images
  and are included in the PDF output.
- **Diagram examples in guide/pt**: Added Portuguese diagram section with
  PlantUML, graphviz, and mermaid examples (matches guide/en).
- **build-adoc.sh**: PlantUML uses `plantuml-native` when available (avoids
  system JAR incompatibility). Mermaid uses puppeteer-config.json for
  `--no-sandbox` support when running as root.
- **puppeteer-config.json**: New file for mermaid-cli `--no-sandbox` support.

## v6.0.4 (2026-09-16)

### Cleanup

- **Converter optimized**: 831→653 lines (−21%). Removed dead code
  (`TESTFIELD_MAP`, `convert_role_testfield`, `convert_role_general_objective`,
  redundant `convert_role_hutable`/`longhutable`), consolidated 11 identical
  role methods into `TECHNICAL_ROLES` + `define_method`, simplified table
  env detection, trimmed verbose separator comments.
- **CHANGELOG condensed**: 1,409→155 lines. Pre-v6.0.0 entries (v1.0.0–v5.1.1)
  summarized into a brief historical overview.
- **CSS optimized**: 412→337 lines. Consolidated 11 duplicate `::before`
  pseudo-elements into shared rule + individual content/color, removed no-op
  `.problem` override, combined duplicate table rules.
- **HTML templates deduplicated**: `technical-template.html` replaced with
  symlink to `guide-template.html` (were byte-for-byte identical). Fixed
  invalid HTML comments inside `<style>` blocks.
- **Scripts simplified**: `build.sh` 560→520, `round-trip.sh` 520→493,
  `Makefile` 292→237. Removed legacy aliases, condensed verbose echoes with
  loops, removed dead `.tex` fallback in `compile_sample`, extracted `watch`
  target to `scripts/watch.sh`.
- **AGENTS.md**: Merged L21 into L16 (redundant), 719→709 lines.

## v6.0.3 (2026-09-16)

### Features

- **Diagram support**: PlantUML, graphviz, and mermaid diagrams can now be
  embedded directly in `.adoc` files using `[plantuml]`, `[graphviz]`, and
  `[mermaid]` blocks. The `asciidoctor-diagram` gem is loaded automatically
  by `build-adoc.sh`. Requires Java+PlantUML, graphviz, or mermaid-cli
  depending on diagram type. Added diagram examples to guide/en sample.
- **Copy-to-clipboard for HTML code blocks**: Code blocks in HTML output now
  show a "Copy" button on hover. Uses `navigator.clipboard` API with
  `execCommand` fallback. Styled with Huawei brand colors (green on success).
  New files: `huawei.js`, `docinfo.html`.
- **`make preview`**: Generates HTML preview from `.adoc` and opens in browser.
  Usage: `make preview DIR=examples/guide/en`.
- **`make watch`**: Watches `.adoc` files and recompiles PDF on save.
  Uses `entr` if available, falls back to `inotifywait`, then polling.
  Usage: `make watch DIR=examples/guide/en`.

### Cleanup

- **Removed old Lua filter files**: `pandoc-common.lua` (47KB),
  `guide-pandoc.lua`, `technical-pandoc.lua`, `testbook-pandoc.lua`.
  These were superseded by `huawei-latex-converter.rb` in v6.0.0.
- **Removed legacy test data**: `tests/cases/` (36 .tex files),
  `tests/expected/` (36 .md.expected files), `.luacheckrc`.
  These tested the old Lua filter pipeline.
- **Gemfile**: Added `ruby '>= 2.4'` version constraint (converter uses
  `Float#clamp` from Ruby 2.4+).
- **install.sh**: Added `graphviz` and `plantuml` packages for diagram support.

## v6.0.2 (2026-09-16)

### Fixes

- **.gitignore: Fixed generated .tex coverage** — added `examples/*/*/src/main.tex`
  pattern to cover nested sample directories (guide/en, guide/pt, etc.).
- **Test scripts: Updated for AsciiDoc pipeline**:
  - `round-trip.sh`: Now uses `asciidoctor -b huawei-latex -r converter.rb` instead
    of `asciidoctor -b latex`; DOCX/MD/HTML generation branches on `.adoc` source.
  - `test-docx-fix.sh`: Detects `.adoc` and generates `.tex` before testing;
    DOCX generation uses `asciidoctor-reducer → pandoc -f asciidoc`.
  - `test-filter.sh`: Skips with clear message (Lua filter tests are legacy).
- **AGENTS.md L15: Added missing modules** — `huawei-cover`, `huawei-titles`,
  `huawei-toc` were not listed in the shared modules enumeration.
- **Converter: Fixed stale comment** — removed reference to deleted
  `convert_role_changelog` method.
- **SKILL.md: Fixed `:guidetitle:`** — replaced with `= Document Title` (level-0
  heading), which is how the converter actually reads the document title.
- **README.md: Fixed stale line counts** — converter 940→831, CSS 242→367.
- **README.md: Added testbook samples** to project layout tree.
- **README.md: Marked test-filter.sh as legacy** in project layout.
- **.gitignore: Added `session-*.md`** pattern for session files.

## v6.0.1 (2026-09-16)

### Fixes

- **Converter: Added technical template role handlers** (`problem`,
  `rootcauseanalysis`, `rootcause`, `triggercondition`, `workaround` + 6 sub-roles)
  that emit proper LaTeX environments. Previously these roles were silently ignored.
- **Converter: Fixed `:date:` attribute** — now reads `:date:` first (as documented),
  falls back to `:revdate:`.
- **Converter: Added `:noanswers:` and `:indentbody:` class options** — previously
  silently dropped.
- **Converter: Added `:header-logo:` and `:cover-logo:` attribute handling** —
  now emits `\setheaderlogo` and `\setcoverlogo` commands.
- **Converter: Fixed multiple `include::` in source blocks** — previously only the
  first include was processed, rest silently dropped.
- **Converter: Fixed HTML entity unescape order** — `&amp;` is now unescaped last
  to prevent double-unescape.
- **Converter: Fixed LaTeX escaping** in `convert_inline_break`, `convert_role_badge`,
  `convert_role_note`, `convert_role_param`, and `convert_dlist` description text.
- **Converter: Fixed table header cells** — now uses `cell.content` for inline
  formatting support and processes all header rows (not just first).
- **Converter: Removed ~140 lines of dead code** (`latex_col_spec`, `BADGE_ROLE_MAP`,
  `convert_role_changelog`, `convert_role_testcase`, `convert_testsummary`).
- **build.sh: Updated multi-format pipeline** — DOCX/MD/HTML now uses
  `asciidoctor-reducer → pandoc -f asciidoc` when `.adoc` source exists.
  Legacy `.tex`-only pipeline preserved for backward compatibility.
- **install.sh: Fixed `compile_sample()`** — now detects `.adoc` and runs
  `build-adoc.sh` before `latexmk`.
- **build-adoc.sh: Added asciidoctor availability check** with actionable error message.
- **CSS: Added styling for technical template roles** (problem, rootcause, workaround,
  etc.) with brand-colored borders and section headings.
- **Docs: Fixed stale references** in 3× template README.md (rewritten for AsciiDoc),
  3× SKILL.md (attribute name fixes), 3× HTML templates (Lua filter comments),
  README.md, CHANGELOG.md, BRAND-GUIDELINES.md, test-sync.sh.
- **Samples: Fixed guide/en placeholder image** — uses `\imageplaceholder` passthrough
  for missing `ecs-flavors.png`.

## v6.0.0 (2026-09-16)

### Breaking changes

- **Source format changed from LaTeX to AsciiDoc**: All documents now use
  `.adoc` as the source format. LaTeX (`.tex`) is generated by the
  `huawei-latex-converter.rb` Ruby backend and compiled to PDF via XeLaTeX.
- **Old `.tex` source files removed**: Replaced by `.adoc` equivalents.
  Generated `.tex` files are build artifacts (gitignored).
- **Build pipeline changed**: `asciidoctor -b huawei-latex` → `.tex` → `latexmk` → PDF.

### Features

- **Custom AsciiDoc-to-LaTeX converter** (`huawei-latex-converter.rb`, 940 lines):
  converts AsciiDoc documents to LaTeX using Huawei template class commands.
  Handles all node types: sections, paragraphs, admonitions, tables, code blocks,
  lists, images, inline formatting, changelog, testcase, objectives, badges.
- **Huawei brand CSS** (`huawei.css`, 242 lines): styles HTML output from asciidoctor.
- **Gemfile**: asciidoctor, asciidoctor-reducer, asciidoctor-diagram dependencies.
- **build-adoc.sh**: wrapper script for the asciidoctor → LaTeX conversion.

### Refactoring

- **Makefile**: All targets updated to use `build-adoc.sh` before `latexmk`.
- **install.sh**: Added asciidoctor gem installation.
- **Test scripts**: Adapted for .adoc source detection.
- **.gitignore**: Generated .tex files and testbook outputs now ignored.
- **Net code reduction**: ~6,200 lines removed (old .tex sources + testbook outputs).
- **Lua filters now legacy**: `pandoc-common.lua` and `*-pandoc.lua` files are
  superseded by `huawei-latex-converter.rb` for PDF and `asciidoctor-reducer → pandoc`
  for other formats. The files still exist for backward compatibility but are no
  longer the primary pipeline.

## Pre-v6.0.0 (v1.0.0 – v5.1.1)

### Summary

The pre-v6.0.0 era used LaTeX (`.tex`) as the source format with Lua filters
(`pandoc-common.lua`) for multi-format output. Key milestones:

- **v1.0.0–v2.x**: Initial LaTeX templates (guide, technical), brand colors,
  callout boxes, Huawei cover page, TOC, changelog environment.
- **v3.x**: Testbook template, testcase/testsummary environments, badge roles,
  image captions, step-by-step lists, prerequisites blocks.
- **v4.x**: Multi-format output (DOCX, MD, HTML) via Pandoc + Lua filters,
  `docx_fix.py` post-processing, `embed-images.py` for MD, HTML templates
  with brand CSS, setup guide, install script.
- **v5.x**: Brand guidelines integration (auxiliary colors, monochrome palette),
  callout color sync across formats, `:noauthors:`/`:notime:`/`:nochangelog:`
  attributes, float placement `[H]`, `hutable`/`longhutable` roles,
  `.latexmkrc` timezone support, version sync validation.

### Migration to v6.0.0

In v6.0.0, the source format changed from LaTeX to AsciiDoc. The Lua filter
pipeline was replaced by `huawei-latex-converter.rb` (Ruby) for PDF and
`asciidoctor-reducer → pandoc` for DOCX/MD/HTML. See v6.0.0 entry above
for details.
