# Changelog

All notable changes to the huawei-doc-templates project are documented here.
Per-document changelogs are maintained via `\changelogentry` in each `.tex` file.

## v2.8.2 (2026-08-23)

### DOCX H1 heading: revert table to paragraph + red bottom border

- **Reverted table approach**: v2.8.1 used a two-column table for H1, but
  this broke Word's navigation pane and TOC field (Heading1 style was split
  across cells). Reverted to a single paragraph with Heading1 style.
- **Red bottom border**: Added 1.5pt red (C7000B) paragraph bottom border
  to H1, matching the PDF's `\color{huaweired}\titlerule[1.5pt]`.
- **Layout preserved**: 56pt number left + right tab stop + 20pt bold title
  right — visually identical to the table approach but navigation-compatible.
- **H2-H4 unchanged**: Still simple inline (number + space + title).

## v2.8.1 (2026-08-23)

### DOCX heading fix: black text + table layout for H1

- **Heading text color**: Reverted to black (#1F2328). v2.8.0 incorrectly
  changed heading text to Huawei red — PDF uses black text with only the
  rule below H1 in red.
- **H1 layout**: Replaced tab-stop approach with a two-column table —
  column 1 (left-aligned) contains the 56pt section number, column 2
  (right-aligned) contains the 20pt bold title. Table has a red bottom
  border (1.5pt C7000B) matching the PDF's `\titlerule`.
- **H2-H4 layout**: Simplified to inline format — number + space + title
  in a single paragraph with heading style. Removed the right tab stop
  that was incorrectly pushing the title to the right edge. Number is
  now the same font size as the title (matches PDF).

## v2.8.0 (2026-08-23)

### DOCX output: match PDF styling across all visual elements

Comprehensive DOCX vs PDF comparison found 11 discrepancies. All fixed:

- **Heading colors**: H1-H4 text now Huawei red (#C7000B), was dark gray (#1F2328).
- **H1 number size**: Section number now 56pt (sz=112), was 28pt (sz=56).
- **Callout borders**: Only left border (3pt), top/bottom/right removed.
- **Callout padding**: Left/right=8pt (160tw), top/bottom=6pt (120tw).
- **Changelog formatting**: Top/bottom rules (0.5pt black), bold version (left),
  italic date (right via tab stop at 8504 twips).
- **Caption style**: 9pt (sz=18) bold centered — always ensured even if pandoc
  creates a bare style.
- **Badge style**: 8pt (sz=16) bold white text on Huawei red background —
  always ensured even if pandoc creates a bare style.
- **List indentation**: Level 0=480tw, level 1=960tw, level 2=1440tw with
  240tw hanging indent — matches PDF 1.6em/1.8em.
- **Note/Param**: Already italic (`pandoc.Emph`) in Lua filter — no change needed.
- **Code blocks**: Already correct (F6F8FA shading, Cascadia Code 10pt) — no
  change needed.

Files changed: `create-reference-docx.py` (heading colors, caption/badge style
enforcement, numbering.xml indentation fix), `guide-pandoc.lua` (H1 number size,
callout borders/padding, changelog raw OpenXML).

## v2.7.1 (2026-08-23)

### DOCX section headings: number left (bigger), title right

- **Heading layout**: Section headings (H1-H4) in DOCX now have the section
  number on the far left in a bigger font, and the title on the far right,
  using a right-aligned tab stop at the content width (8504 twips).
- **Number font sizes**: H1=28pt, H2=24pt, H3=22pt, H4=20pt (bigger than the
  heading style default, which is 20/18/16/14pt for the title).
- **Heading styles preserved**: Paragraphs still use `Heading1`-`Heading4`
  styles, so they appear in the navigation pane and TOC field.
- **Bookmarks preserved**: Each heading has a `bookmarkStart`/`bookmarkEnd`
  with the pandoc-generated identifier, so cross-references and TOC
  navigation work.
- **Page breaks**: H1 page breaks (except first) still applied.
- Non-DOCX formats (Markdown, HTML) unaffected — pandoc's `--number-sections`
  handles numbering for those.

## v2.7.0 (2026-08-23)

### Native Word TOC — replaced manual entries with Word's built-in TOC field

**Major change:** Removed all manually generated TOC cached entries, hyperlinks,
and styles from the Lua filter. The TOC is now a native Word TOC field that
Word generates automatically.

**What changed:**
- TOC field wrapped in `w:sdt` (structured document tag) — Word's native TOC container
- `w:dirty="true"` on the field — Word updates on open
- No cached entries — Word generates everything: page numbers, hyperlinks, dot leaders, indentation
- Removed ~30 lines of manual TOC entry generation from `guide-pandoc.lua`
- TOC1/TOC2/TOC3 styles kept in reference DOCX (Word uses them when generating entries)

**Trade-off:** Opening the DOCX triggers a one-time Word security warning
("This document contains fields that may refer to other files. Update?").
User clicks "Yes" → Word builds the full TOC → save → warning never reappears.
This is the only way to get page numbers in the TOC.

**Before:** Manually constructed TOC entries with text, hyperlinks, tab stops —
no page numbers, fragile.
**After:** Native Word TOC with page numbers, clickable hyperlinks, dot leaders,
proper indentation — all generated by Word.

## v2.6.1 (2026-08-23)

### TOC entries now clickable

- **TOC hyperlinks**: Cached TOC entries now wrap text in `<w:hyperlink
  w:anchor="...">` pointing to each heading's bookmark. Clicking a TOC entry
  navigates to the corresponding section. All 11 anchors match pandoc-generated
  bookmarks (slug-based names like `provision-an-elastic-cloud-server`).
- No `w:dirty`, no `updateFields` — no security warning on open.

## v2.6.0 (2026-08-23)

### DOCX style architecture overhaul — styles-first approach

**Fixes:**
- **Removed duplicate Heading1-4 styleIds** — `create-reference-docx.py` was
  creating custom heading styles via `add_style()` when python-docx's BabelFish
  lookup failed (case sensitivity), producing invalid duplicate styleIds in
  `styles.xml`. The duplicate styles lacked `outlineLvl`, causing headings to
  not appear in Word's navigation pane.
- **Removed `w:dirty="true"` from TOC field** — this was triggering Word's
  "This document contains fields that may refer to other files" security
  warning on open.
- **Confirmed `updateFields` absent** from settings.xml in all generated DOCX.

**New styles added in `fix_generated_docx`:**
- **Caption** — for figure/table captions: 10pt bold, centered, HarmonyOS Sans
- **TOC1/TOC2/TOC3** — Word built-in TOC entry styles with tab stops (right,
  dot leader at 9000 twips) and per-level indentation
- **Heading5-9** — fixed `outlineLvl` (4-8), `qFormat`, font/color to match
  Heading1-4 pattern
- **keepNext + keepLines** on Heading1-4 — prevents headings from separating
  from following content

**TOC improvements:**
- Cached TOC entries now use TOC1/TOC2/TOC3 styles (proper indentation + tab
  stops with5 dot leaders) instead of bare indentation
- No `w:dirty` attribute — no security warning on open
- TOC is visible immediately from cached entries; user can right-click →
  Update Field for page numbers

**Caption improvements:**
- `\imagecap` now generates a visible caption paragraph with Caption style
  in DOCX (previously caption was only used as alt text, not visible)

**Architecture:**
- `create-reference-docx.py` no longer modifies heading styles (removed
  try/except KeyError blocks that created duplicates)
- `fix_generated_docx` is the single point of control for all style fixes
- Added `remove_duplicate_styles()` helper to clean any residual duplicates

## v2.5.10 (2026-08-22)

### TOC and navigation fixes

- **TOC field marked dirty**: Added `w:dirty="true"` to the TOC field's
  `fldChar` begin element. Without this, Word didn't know the field needed
  updating — the TOC showed placeholder text instead of actual entries.
- **Cached TOC entries**: Generated heading text as cached content inside the
  TOC field (between `separate` and `end` fldChar). The TOC is now visible
  immediately when opening the document, with section numbers and indentation.
  When Word updates the field, it replaces cached entries with full TOC
  (hyperlinks + page numbers).
- **Multi-paragraph field structure**: Changed TOC field from single paragraph
  to multi-paragraph (begin paragraph + entry paragraphs + end paragraph),
  matching Word's native TOC field structure.
- **Navigation pane**: Heading styles confirmed correct (`outlineLvl` 0-3,
  `qFormat`, `uiPriority`, `basedOn=Normal`). The navigation pane issue was
  caused by the empty TOC — with cached entries now visible, the document
  structure is immediately apparent.

## v2.5.9 (2026-08-22)

### DOCX fixes: callout spacing, TOC, navigation

- **Callout spacing**: Added a 6pt spacing paragraph after each callout table.
  Tables don't inherit paragraph style spacing, so adjacent callouts had no
  visual gap between them.
- **TOC auto-update**: Added `<w:updateFields w:val="true"/>` to `settings.xml`
  so Word automatically populates the TOC field when the document is opened.
  Previously the TOC appeared empty until the user manually right-clicked →
  Update Field.
- **Navigation pane**: Fixed `pBdr` element order in Heading1 style. The bottom
  border was appended after `spacing` and `outlineLvl`, violating the OOXML
  schema order (`pBdr` must come before `spacing`). Now correctly inserted
  before `spacing`. Heading styles have `outlineLvl` 0-3 for H1-H4, so Word's
  navigation pane shows the full document structure.

## v2.5.8 (2026-08-22)

### DOCX style architecture overhaul

**Cover image centering fixed**: Defined `CoverLogo` named style with
`jc=center` and applied via `custom-style` in Lua filter. The cover logo
is now horizontally centered, matching PDF's `\centering`.

**Vertical spacing fixed**: All heading after-spacing was 0 (pandoc defaults
never corrected). Now matches PDF `guide.cls` titlespacing values:
- H1: before=0, after=30pt
- H2: before=30pt, after=6pt
- H3: before=10pt, after=4pt
- H4: before=8pt, after=4pt

**Body line spacing**: Added `line=280 lineRule=atLeast` (14pt leading) to
docDefaults, matching PDF's `\@setfontsize\normalsize{10.5}{14}`.

**Callout/code spacing**: Added 6pt before/after to `warning`, `tip`,
`infobox`, and `SourceCode` styles (was 0).

**Title spacing**: Fixed to before=62pt, after=128pt to match PDF cover
layout (`\vspace{2.2cm}` + `\vspace{4.5cm}`).

**New named styles** (replacing ad-hoc raw OpenXML):
- `CoverLogo` — centered, 10pt before/after
- `CoverText` — centered, 30pt before, 10pt after, 16pt
- `CoverMeta` — centered, 5pt before, 10pt after, 12pt
- `TOCTitle` — right-aligned, 22pt bold
- `ImageBlock` — centered, 6pt before/after (also fixes body image centering)
- `ObjectivesRule` — bottom border 1.5pt black

**Architecture**: Lua filter now emits `custom-style` attributes instead of
raw OpenXML for cover page, TOC title, body images, and objectives rule.
Raw OpenXML retained only for table structures, field codes, and page breaks
(elements that cannot be controlled via paragraph styles).

## v2.5.7 (2026-08-22)

### Makefile fix

- **`make all-formats` now generates setup-guide formats**: Previously only
  generated DOCX/MD/HTML for `examples/guide/pt` and `examples/guide/en`.
  Added `docx-sg`, `md-sg`, `html-sg` targets. `make all` now produces all
  9 format outputs (3 formats × 3 documents).

## v2.5.6 (2026-08-22)

### Makefile fix

- **`make clean` now removes all build artifacts**: `latexmk -C` run from
  `src/` couldn't reach PDFs output to the parent directory (`$out_dir = '..'`
  in `.latexmkrc`). Added explicit `rm -f` for each PDF in the document root.
- **`clean-formats` now covers setup-guide**: Previously only cleaned
  `examples/guide/pt` and `examples/guide/en`. Now also removes
  `examples/setup-guide/setup-guide.{docx,md,html}`.

## v2.5.5 (2026-08-22)

### DOCX final polish — bug fixes from end-to-end review

- **Language detection fixed (critical)**: `lang` was set inside `Pandoc()`
  which runs after the AST walk. Moved to module level so `RawBlock`/`RawInline`
  handlers have the correct language. Portuguese labels (Importante, Dica,
  Informação, Histórico de versões) now render correctly in all formats.
- **Heading4 italic removed**: Pandoc's default H4 includes `<w:i/>`.
  `fix_generated_docx` now strips `i` and `iCs` along with `b` and `bCs`.
- **Badge font fixed**: Was Cascadia Code (code font). Now HarmonyOS Sans
  (body font), matching PDF `\colorbox` which uses the default body font.
- **Syntax highlighting disabled for DOCX**: PDF uses monochrome fancyvrb.
  CodeBlock language classes now stripped for DOCX so pandoc doesn't apply
  colored token styles.
- **BodyText spacing fixed**: `BodyText` and `FirstParagraph` styles had
  `after=180 before=180` (9pt). Now `after=80 before=0` (4pt), matching
  PDF `\parskip=4pt`.
- **Header/footer idempotent**: `main()` now clears existing runs before
  adding header/footer fields. Prevents triplication on repeated runs.
- **SourceCode szCs added**: Added `szCs=20` for complex script consistency.
- **VerbatimChar 10pt**: Was 11pt (pandoc default). Now 10pt (sz=20),
  matching PDF code font.
- **Cover compilation time**: Cover now shows "v1.7.0 — 2026-08-22 02:00"
  with HH:MM time, matching PDF cover page.
- **Code block margins**: SourceCode style now has left=0.7cm (397 twips),
  right=0.5cm (284 twips) indentation, matching PDF code block margins.

## v2.5.4 (2026-08-22)

### DOCX styling — match PDF (Tier 2)

- **TOC**: Word TOC field inserted after cover page (right-aligned 22pt bold
  heading + `TOC \o "1-3" \h \z \u` field + page break). Replaces stripped
  `\maketoc`. Heading is language-aware ("Sumário" / "Table of Contents").
- **Section numbers**: `--number-sections` added to pandoc invocation. Pandoc
  renders numbers with `SectionNumber` character style + tab separator.
- **H1 page breaks**: Page break inserted before each H1 (except the first,
  which follows the TOC page break) — matches PDF `\clearpage` before
  `\section`.
- **Cover logo**: `pandoc.Image` inserted on cover page (centered, 3.6cm wide).
  `--resource-path` added to pandoc to resolve `common-assets/` images.
- **Badge**: Switched from `Div` with class "badge" to `Span` with
  `custom-style="badge"` — pandoc now applies the badge character style (red
  background, white bold text).
- **Objectives border**: 1.5pt black bottom rule added after objectives block
  via `RawBlock("openxml")` — matches PDF `\hrulefill`.
- **\note semantics**: Changed from infobox callout to plain italic paragraph
  for DOCX — matches PDF `\textit{...}`.

## v2.5.3 (2026-08-22)

### DOCX styling overhaul — match PDF (Tier 1)

- **Heading sizes restored**: Pandoc was overriding reference-doc heading sizes
  with its defaults (H1=16pt, H2=14pt, H3=12pt, H4=12pt). `fix_generated_docx`
  now restores PDF values: H1=20pt, H2=18pt, H3=16pt, H4=14pt.
- **Body text size fixed**: Was 12pt (pandoc default). Now 10.5pt (sz=21)
  matching PDF `\fontsize{10.5}{14}`. Paragraph spacing reduced from 10pt to 4pt.
- **hutable as OpenXML table**: Tables now render with Huawei-red header row
  (#C7000B bg, white bold text), alternating body rows (white/#F6F8FA), red
  cell borders (#C7000B full grid), and 9pt centered font — matching the PDF
  `hutable` environment exactly.
- **Callout boxes as OpenXML tables**: Switched from `custom-style` Divs (which
  only styled the first paragraph) to single-cell OpenXML tables with cell
  shading, thick colored left border, and colored bold label — matching PDF
  `tcolorbox` rendering. Label colors: warning=#C7000B, tip=#2E7D32,
  infobox=#1565C0.
- **Page layout**: A4 page size with 3/3/2/2 cm margins (was 1in all sides).
- **Headers**: Document title via STYLEREF field (10pt, centered), different
  first page (no header on cover).
- **Footers**: Page number via PAGE field (10pt, centered), different first page.

## v2.5.2 (2026-08-21)

### DOCX cover page + font fixes

- **Title style fixed**: Was 18pt blue (pandoc default). Now 36pt near-black
  bold centered, matching PDF cover (`\fontsize{36}{42}\bfseries`).
- **Cover page content added**: DOCX now includes cover text (16pt centered)
  and version/date (12pt centered) after the title, plus a page break —
  matching the PDF `\makecover` layout.
- **VerbatimChar font fixed**: Was Consolas (pandoc default). Now Cascadia
  Code, matching PDF code font and L8 fallback chain.
- **Theme-only font refs eliminated**: Styles that used `asciiTheme="majorHAnsi"`
  without explicit font names now have `ascii="HarmonyOS Sans"` added.
  Prevents Word from falling back to Cambria when HarmonyOS Sans is not
  installed.

## v2.5.1 (2026-08-21)

### Review fixes: H2-H4 weight, build robustness, CSS variables

- **H2-H4 font weight fixed (L18)**: PDF uses `\normalfont` (regular) for
  H2-H4. DOCX was bold, HTML was semibold. Fixed both to regular weight.
- **build.sh post-processing made non-fatal**: `2>/dev/null` + `set -e`
  could silently kill a successful build. Now warns on failure instead.
- **pPr creation fixed**: `fix_generated_docx` silently skipped H1 border
  if `pPr` didn't exist. Now creates it (mirrors `rPr` pattern).
- **Bold removal in fix_generated_docx**: Added code to strip `<w:b/>`/
  `<w:bCs/>` from H2-H4 in generated DOCX (pandoc overrides reference doc).
- **`--fix` argument parsing**: Added missing-path check for direct invocation.
- **HTML callout labels use CSS variables**: Replaced hardcoded hex with
  `var(--huawei-red)`, `var(--tip-border)`, `var(--info-border)`.

## v2.5.0 (2026-08-21)

### Multi-format styling fixes + L18: PDF is the reference

- **L18 locked decision**: PDF is the primary output and visual reference.
  DOCX, Markdown, and HTML must match the PDF as closely as possible.
- **Image references fixed**: Pandoc now runs from the project directory
  (not `src/`) so `assets/` is found. Images are properly embedded in DOCX.
- **DOCX callout styles fixed**: Style names renamed to match Lua filter
  classes (`warning`, `tip`, `infobox`). Lua filter changed to use
  `custom-style` attribute for DOCX Divs. Callouts now have colored
  backgrounds and borders in DOCX.
- **DOCX heading styles fixed**: Pandoc overrides reference doc heading
  styles with blue `accent1` defaults. Added `fix_generated_docx()`
  post-processing that directly modifies `styles.xml` in the zip to set
  near-black color (`#1F2328`) and H1 red bottom border.
- **HTML H1 color fixed**: Changed from red to near-black (`--body-text`)
  to match PDF (black text + red rule below).
- **HTML callout label colors**: Added CSS for callout label colors
  (warning=red, tip=green, infobox=blue) matching PDF.

## v2.4.0 (2026-08-21)

### Remove EPUB format + restructure document layout

- **EPUB removed**: Dropped EPUB as an output format. Technical guides render
  poorly on e-readers (code blocks, tables, callouts don't survive reflow).
  PDF + DOCX + HTML + Markdown is the complete output set. Removed
  `guide-epub.css`, `generate_epub()`, `--epub` flag, Makefile targets, and
  all EPUB documentation.
- **src/ subfolder**: Source files (`.tex` and `.latexmkrc`) now live in a
  `src/` subfolder within each document directory. Generated outputs (PDF,
  DOCX, MD, HTML) go in the parent directory. This keeps source files
  organized separately from generated artifacts. `.latexmkrc` sets
  `$out_dir = '..'` and `$aux_dir = '.'` so the PDF goes to the parent while
  aux files stay in `src/`.

## v2.3.0 (2026-08-21)

### Font configuration across all output formats

- **DOCX**: `create-reference-docx.py` now sets the theme `majorFont` and
  `minorFont` (latin/ea/cs) to HarmonyOS Sans via direct `theme1.xml`
  mutation (python-docx has no theme API). Previously the theme defaulted
  to Calibri (headings) and Cambria (body); now all theme-referencing
  styles inherit HarmonyOS Sans. Explicit styles (Source Code → Cascadia
  Code) keep their override. `docDefaults/rPrDefault` also updated.
- **EPUB**: New `guide-epub.css` brand stylesheet passed via `--css`.
  Replaces pandoc's default epub.css with Huawei brand fonts, colors,
  callouts, and table styling matching the HTML template. Fonts are not
  embedded (brand font + e-reader limitations); fallback chain handles
  missing fonts.
- **LaTeX**: Renamed internal macro `\consolasfont` → `\lg@codefont`
  (loaded Cascadia Code, not Consolas; name was misleading). `\codefont`
  public API unchanged.
- **README**: Added `guide-epub.css` to project layout; noted EPUB brand
  CSS in multi-format section.

## v2.2.1 (2026-08-20)

### Fix: \imageplaceholder no longer emits real image references

- The block-level `\imageplaceholder` handler emitted a real `pandoc.Image`
  for Markdown/EPUB output, pointing to a non-existent file. EPUB then
  warned ("Could not fetch resource") when bundling. Now `\imageplaceholder`
  emits a placeholder paragraph in all formats, matching the inline handler
  and the semantic intent (a placeholder is for images that don't exist).
- Updated the imageplaceholder test expected output.

## v2.2.0 (2026-08-20)

### Self-documenting Makefile

- Bare `make` now prints a clear, sectioned help summary instead of
  building everything (use `make all` to build everything). The Makefile
  is self-documenting via `## ` target annotations and `##@ ` section
  headers; `make help` shows the same output.
- Help is TTY-aware (colored in a terminal, plain when piped).
- Updated README Makefile reference to reflect the new default.
- Recompiled setup-guide.pdf (cls changed in v2.1.0).

## v2.1.0 (2026-08-20)

### Codebase + documentation review fixes

- **Fix hutable phantom-row bug** in the Pandoc Lua filter: the final-row
  fallback anchored to the first `\\` instead of the last, emitting a
  duplicate mangled row in every non-PDF table output. Corrected the
  expected test output that had encoded the bug.
- **Align font fallback with L8**: removed extra fallbacks (Helvetica Neue,
  Arial, Consolas) from the HTML template and switched the DOCX reference
  from Consolas to Cascadia Code. Regenerated guide-reference.docx.
- **Version hygiene**: bumped guide.cls to v2.0.3; completed .sty
  dependency comments (keyval, etoolbox, tcolorbox, xcolor/colortbl).
- **Complete README project-layout tree**: added 7 missing entries
  (guide-pandoc.lua, guide-reference.docx, guide-template.html,
  create-reference-docx.py, documents/README.md, tests/test-filter.sh,
  tests/expected/).
- **Fix build.sh** error message that referenced an empty `$1`.
- **Add 9 Lua filter test cases** for previously untested commands
  (imagecap, imageplaceholder, objectives env, generalobjective,
  prerequisites, param, code env, codefile without language hint,
  multi-entry changelog). Suite now 23 passed, 0 failed.

## v2.0.3 (2026-08-20)

### Repo structure: gallery moved into examples/

- Moved `docs/gallery/` → `examples/gallery/` and removed the now-empty
  `docs/` directory, eliminating the confusing `docs/` vs `documents/`
  name clash.
- Updated README.md gallery link and project layout tree.
- No code, class, or `.tex` changes; compilation unaffected.

## v2.0.2 (2026-08-20)

### Documentation refactor

- Refactored docs: removed duplication, fixed cross-references, and
  corrected TEXINPUTS paths. (Backfilled — tag existed without a
  CHANGELOG entry.)

## v2.0.1 (2026-08-20)

### Documentation review + L17 standard

- Added L17 to AGENTS.md: version tag + validate/tests after each change.
- Made Makefile the recommended compilation method across all docs.
- Added EPUB to all multi-format output documentation.
- Fixed stale references: guide.cls description (decomposed, not all-in-one),
  broken L7 refs (moved to Conventions), L1–L15 → L1–L17 range.
- Fixed hardcoded absolute path in `tests/cases/codefile.tex`.
- Renamed project folder to lowercase (`huawei-doc-templates`).

## v2.0.0 (2026-08-19)

### Major: Class decomposition + multi-format output

- **Phase 1**: Decomposed `guide.cls` (600 lines) into 10 shared `.sty` modules
  under `templates/_base/` (colors, fonts, lang, page, tables, code, callouts,
  images, changelog, shared). `guide.cls` reduced to ~194 lines.
- **Phase 2**: Added multi-format output via Pandoc + Lua filter. Generates
  DOCX, Markdown, HTML, and EPUB from LaTeX source. The Lua filter translates
  all custom commands (`\makecover`, `\infobox`, `\objective`, `\stepbystep`,
  `\image`, `\note`, `\hutable`, `\codefile`, `\badge`, `\menu`, `\changelog`,
  etc.) to Pandoc AST elements.
- Added `build.sh` interactive format selection menu with `--pdf`, `--docx`,
  `--md`, `--html`, `--epub`, `--all`, `--dry-run` flags.
- Added `make menu` Makefile target delegating to `build.sh`.
- Added reference DOCX (`guide-reference.docx`) with custom Huawei styles.
- Added HTML template (`guide-template.html`) with Huawei brand CSS.
- Added EPUB output support.
- Added Lua filter unit tests (`tests/` with 14 test cases).
- Added `.luacheckrc` for static analysis.
- Added ARIA roles on callout divs in HTML output.
- Added `lang` attribute on HTML `<html>` element from documentclass option.
- Added `pdftitle`/`pdfauthor` PDF metadata via `\hypersetup`.
- Added module dependency comments in all `.sty` files.
- Added `PANDOC_VERSION:must_be_at_least('3.0')` runtime version gating.
- Added `os.setlocale('C')` for consistent pattern matching.
- Added `log_warn()` helper for stderr error reporting in Lua filter.
- Added font fallback warning surfacing in `build.sh`.
- Added log excerpt display on compilation failure in `build.sh`.
- Added "what this will do" summary in `install.sh` before confirmation.
- Fixed `\imageplaceholder` producing broken `<img>` in DOCX/HTML.
- Fixed image alt text: empty alt for uncaptioned images (WCAG 2.1).
- Fixed `\note` prefix inconsistency between preprocess and RawInline.
- Simplified Lua filter: dispatch table, extracted helpers (split_row,
  parse_image, parse_codefile, is_strip_cmd), callout factory.
- Simplified build system: Makefile delegates to build.sh, collapsed
  generate functions.
- Simplified .sty modules: deleted no-op `\two@digits`, moved `\thd`/`\tbody`
  to huawei-tables.sty, inlined `\lg@label`.
- Trimmed AGENTS.md: moved L2/L3/L7/L10 from locked decisions to conventions.

## v1.7.0 (2026-08-17)

- Added "Limpeza" chapter to Portuguese sample for pt/en parity.
- Fixed `\codefile` with `\IfFileExists` guard.
- Removed dead imports from samples.
- Fixed `install.sh` PDF preservation.

## v1.6.0 (2026-08-12)

- `changelog` environment now emits its own section heading.
- `[nochangelog]` suppresses the heading and entries in one switch.

## v1.5.0 (2026-08-12)

- New `hutable` environment: full-grid tables with Huawei-red header and
  alternating body rows.
- Floats now default to `[H]` placement (in-source order).

## v1.4.0 (2026-08-10)

- Default image size increased: width 65% → 90%, height 40% → 50%.
- H1 section title size adjusted (18pt → 20pt).

## v1.3.0 (2026-08-10)

- `nochangelog` option now hides version, date, and time on cover page.
- Document date defaults to `\today` (compilation date).

## v1.2.0 (2026-08-09)

- Added key-value sizing options to `\image` and `\imagecap`.
- Fixed PDF copy-paste of URLs in code blocks (disabled Cascadia Code ligatures).
- Fixed italic font rendering (AutoFakeSlant for fonts without italic variants).

## v1.1.0 (2026-08-08)

- Added Huawei-branded table styling: red header bar, alternating row colors.
- Changed table and figure caption labels to black (was Huawei red).

## v1.0.0 (2026-08-05)

- Initial version.
- Added callout boxes, badge, and changelog support.
- Huawei Cloud guide template with branded cover, header, TOC, giant chapter
  numbers, objectives block, code blocks, tables, and images.
- English (default) and Portuguese language support.
