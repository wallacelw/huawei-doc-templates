# AGENTS.md — Project Standards

This file defines the conventions, locked decisions, and workflows for
any agent or human working on this repository. Read it before making
changes.

---

## Project overview

See [README.md](README.md) for project overview, setup, and layout.

---

## Locked decisions (do NOT change)

These decisions were explicitly made and must not be reversed without user
approval. Changing them breaks existing documents and reproducibility.

> **Note:** L2, L3, L7, L10 were moved to Conventions in v2.0.0 (see [CHANGELOG.md](CHANGELOG.md)). Numbers are retained for traceability.

### L1. Engine: XeLaTeX only
- `guide.cls` loads `fontspec`, which requires XeLaTeX or LuaLaTeX.
- `pdflatex` will **not** work. Never remove `fontspec` or switch to pdflatex.
- `.latexmkrc` sets `$pdf_mode = 5` (xelatex). Do not change this.

### L4. Template default timezone is America/Sao_Paulo (GMT-3)
- The template's `.latexmkrc` files set `$ENV{TZ} = "America/Sao_Paulo"`.
- Projects can override TZ in their own `.latexmkrc` (last one wins).
- This default matches the primary user timezone; override for other regions.

### L5. Cover page shows version + date + time automatically
- `\setdocdate` defaults to `\today` (compilation date).
- Time comes from TeX's `\time` primitive (HH:MM, respects TZ env).
- Both are shown on the cover page by default. Pass `[notime]` class option
  to hide the time.
- `[nochangelog]` also hides version, date, and time on the cover page
  (see L12).
- `\setdocdate{...}` can override the date, but time is always compilation
  time (when shown).

### L6. Self-contained project folders
- Every document lives in its own folder. Source files (`.tex` and
  `.latexmkrc`) go in a `src/` subfolder; generated outputs (PDF, DOCX,
  MD, HTML) go in the document root.
- Never scatter `.tex` files directly in the workspace root.
- The `.latexmkrc` sets `TEXINPUTS` pointing to `templates/<name>/` and `templates/_base/`.

### L8. Font fallback chain
- Main font: HarmonyOS Sans -> Liberation Sans (sole fallback).
- Mono font: Cascadia Code -> DejaVu Sans Mono (sole fallback).
- Brand fonts are loaded with `\IfFontExistsTF`; if missing, a single
  fallback is used with a class warning.
- Removed fallbacks: Arial, Consolas, fontspec default.
- `install.sh` installs both brand fonts; the fallbacks are safety nets.

### L9. Colors are hardcoded to Huawei brand
- `huaweired` (`#C7000B`), `codebg` (`#F6F8FA`), `codetext` (`#1F2328`),
  `linkblue` (`#0000FF`), `ruleblack` (`#000000`).
- Callout colors: `warningbg/fg` (amber), `tipbg/fg` (green), `infobg/fg` (blue).
- Do not change these values. They match the Huawei house style.

### L11. Auto-version on every AI-assisted change
- Every AI-assisted edit to a document must bump `\setdocversion` and add a
  `\changelogentry` (newest first) in the `changelog` block.
- Bump levels: patch (typo/wording), minor (new content/section), major
  (structural/breaking).
- Recompile after bumping. The PDF must always reflect the latest version.
- See `SKILL.md` "Versioning workflow" for the full procedure.

### L12. Changelog can be disabled with `[nochangelog]`
- The `changelog` environment emits its own section heading (language-aware:
  "Changelog" / "Histórico de versões"); do not add a `\section` before it.
- The `nochangelog` class option makes `changelog` and `\changelogentry`
  no-ops, suppressing the heading AND entries in one switch (content stays
  in `.tex` but nothing is rendered).
- It also hides version, date, and time on the cover page (see L5).
- Use when the changelog grows too large for the PDF.
- Default: changelog is shown.

### L13. New documents go in `documents/`
- All user-created documents live in `documents/<doc-name>/` subfolders.
  Source files (`.tex`, `.latexmkrc`) go in `documents/<doc-name>/src/`;
  generated outputs go in `documents/<doc-name>/`.
- The `documents/` folder at the repo root is the default location.
- Each document is self-contained: `src/` (with `.tex` and `.latexmkrc`),
  `assets/`.
- Skills create new document folders inside `documents/` by default.
- Samples and examples stay in `examples/`; `documents/` is for user work.

### L14. Floats default to [H] (in-source order, no drifting)
- The class loads `float` and sets `\fps@figure`/`\fps@table` to `H`, so
  `figure` and `table` floats appear exactly where declared, in source order.
- This matches the inline-figure design (`\image`/`\imagecap` are non-floating).
- Users may still override a single float with an explicit `[h]`, `[t]`, `[b]`,
  or `[p]`; the default only applies when no placement is given.
- Tables use the `hutable` environment (full-grid, Huawei-red header, alternating
  body rows). Do not reintroduce raw `tabular` + manual `\midrule`/`\bottomrule`
  in samples — use `hutable`.

### L15. Shared formatting lives in `templates/_base/` modules
- All template classes load shared `.sty` modules from `templates/_base/`.
- Modules: huawei-colors, huawei-fonts, huawei-lang, huawei-page, huawei-tables,
  huawei-code, huawei-callouts, huawei-images, huawei-changelog, huawei-shared.
- Template-specific code (cover, TOC, section styling) stays in the template `.cls` file.
- Do not add `\RequirePackage` calls inside `.sty` modules — all packages are loaded
  by the template class file.

### L16. Multi-format output via Pandoc + Lua filter
- LaTeX remains the single source of truth. DOCX, Markdown, and HTML are
  generated outputs, not hand-edited.
- The Lua filters `templates/guide/guide-pandoc.lua` and
  `templates/technical/technical-pandoc.lua` translate all custom
  commands and environments to Pandoc AST elements.
- The filter uses **global functions** (`Pandoc`, `RawBlock`, `RawInline`) —
  do NOT add a `return` table at the end; return tables silently fail.
- Format check is `raw.format ~= "latex"` (not `"tex"`).
- `make all-formats` generates all 15 outputs (MD + DOCX + HTML for guide pt/en + setup-guide + technical pt/en).
- Generated outputs are gitignored (build artifacts). Only the filter, reference
  DOCX, HTML template, and Python script are committed.

### L17. Version tag + validation after each change
- After every change (bug fix, feature, docs edit), create a new git version tag
  (e.g., `v2.0.1`, `v2.0.2`, `v2.1.0`).
- Before tagging, validate: compile all samples (`make samples`, which includes guide and technical samples), run all tests
  (`make test`, which runs `test-filter.sh`, `round-trip.sh`, `test-docx-fix.sh`,
  and `test-sync.sh`), and verify 0 raw LaTeX blocks in output.
- Tag format: `v<major>.<minor>.<patch>` — patch for fixes, minor for features,
  major for breaking changes.
- Push the tag: `git push --tags`.
- See [CHANGELOG.md](CHANGELOG.md) for the version history.
- The tag is the release — there are no separate release branches.

### L18. PDF is the reference — all formats follow it
- LaTeX → PDF is the primary output and the visual reference.
- DOCX, Markdown, and HTML are secondary outputs that should match the
  PDF as closely as possible in styling: fonts, colors, callout boxes,
  table styling, heading appearance, and spacing.
- When adding or changing any visual element, update all formats to
  match the PDF. The Lua filter, reference DOCX, and HTML template must
  stay in sync with `guide.cls` and `technical.cls`.

---

## Conventions

These are stable naming and structural conventions. Changing them would be a
major version bump, not a violation of a locked decision.

### Class name: `guide` or `technical` (L2)
- Guide: `\documentclass{guide}` or `\documentclass[portuguese]{guide}`.
- Technical: `\documentclass{technical}` or `\documentclass[portuguese]{technical}`.

### Callout box names: `warning`, `tip`, `infobox` (L3)
- Never reintroduce `aviso`, `dica`, or `info` environments.

### Skill prefix: `huawei-template-` (L7)
- All skills are named `huawei-template-<name>` (e.g. `huawei-template-guide`).
- The prefix is set in the SKILL.md frontmatter `name` field.

### Body order (L10)
- `\makecover` -> `\maketoc` -> `\startbody` -> sections -> `changelog` -> `\end{document}`.
- `\startbody` resets page numbering to 1.

---

## Template features

See `templates/guide/SKILL.md` for the full command and environment reference
(class options, preamble commands, document structure commands, environments,
and content commands). SKILL.md is the canonical source; `templates/guide/README.md`
has the human-readable version with examples.

---

## Project structure

See [README.md "Project layout"](README.md) for the full tree.

---

## Compilation

- **Use `make`** (see [README.md](README.md) for full Makefile reference).
- **Never use `pdflatex`** — will fail on `fontspec` (locked, see L1).
- Multi-format output: `make all-formats` (see [README.md](README.md) for details).

---

## Sample and example conventions

- **Two samples per template**: each template `<name>` has exactly two samples
  in `examples/<name>/pt/` and `examples/<name>/en/` (Portuguese and English).
  Samples demonstrate all available commands and environments.
- **Assets folders**: template shared assets (logos, sample images) live in
  `templates/<name>/common-assets/`. Each document has its own `assets/`
  folder for project-specific images and files. LaTeX resolves `assets/` to
  the project folder first, then falls back to `common-assets/` via TEXINPUTS.
  Logos default to `common-assets/` (template-level).
- **Template explanation**: each sample includes an `\begin{infobox}` on the
  first page explaining which template it uses and what it demonstrates.
- **Setup guide is additional**: `examples/setup-guide/` is not a sample — it
  is a real-world document used for validation and actual installation
  instructions. Its multi-entry changelog (27 entries vs 15/13 in samples)
  exercises versioning in depth, and it demonstrates features in a
  practical context.
- **Setup guide PDF in root**: `make examples` copies `setup-guide.pdf` to the
  repo root for easy reading. The copy is gitignored (build artifact).
- **Self-contained**: each sample/example has its own `.latexmkrc` with
  `TEXINPUTS` pointing to `templates/<name>/`. Never share `.latexmkrc` files.

---

## How to create a new skill

Skills are discovered from `templates/<name>/SKILL.md`. The `opencode.json`
at the repo root registers `templates/` as a discovery path.

### Steps

1. **Create the template directory** `templates/<name>/` with:
   - `<name>.cls` — the LaTeX class file
   - `SKILL.md` — the skill definition (see format below)
   - `README.md` — human-readable documentation
   - `.latexmkrc` — latexmk config (XeLaTeX, TZ=America/Sao_Paulo default)
   - `common-assets/` — logos, sample images
   - Samples live in `examples/<name>/pt/` and `examples/<name>/en/` (see below)

2. **SKILL.md format** — must start with YAML frontmatter:
   ```yaml
   ---
   name: huawei-template-<name>
   description: <when to trigger this skill>
   ---
   ```
   - The `name` field MUST have the `huawei-template-` prefix (see Conventions).
   - `install.sh` reads this `name` field to determine the install directory.
   - The `description` field determines when the skill triggers. Keep it
     specific to avoid false activations.

3. **SKILL.md body** should include:
   - **When to use** — clear trigger conditions
   - **Quick start** — step-by-step for creating a new document
   - **Commands reference** — all commands and environments the class provides
   - **Skeleton** — a minimal `.tex` template the skill can use as a starting
     point
   - **Hard requirements** — engine, fonts, compilation rules
   - **Project folder convention** — always create a self-contained folder
   - **Timezone note** — document that TZ is per-project, not template-level

4. **Add to `install.sh`** — the script auto-discovers templates by scanning
   `templates/*/SKILL.md`. No changes needed if the structure is correct.

5. **Add to root `README.md`** — add a row to the Templates table.

### Skill naming rules
- Prefix: `huawei-template-` (see Conventions)
- Examples: `huawei-template-guide`, `huawei-template-technical`
- The skill name in frontmatter must match the directory name under `templates/`
  minus the `huawei-template-` prefix.

---

## How to extend the existing template

### Adding a new command to `guide.cls` or `technical.cls`
1. Define the command in the appropriate `.cls` file (`guide.cls` or `technical.cls`) with a `\newcommand`.
2. Use internal prefix `\lg@` for internal macros (e.g. `\lg@docversion`).
3. Add the command to the reference tables in `SKILL.md` and `README.md`.
4. Demonstrate the command in both samples (`examples/guide/pt/` and `examples/guide/en/`).
5. Compile both samples to verify: `make samples`.
6. Commit only if both samples compile without errors.

### Adding a new environment
- Same steps as above, but use `\newenvironment` or `tcolorbox`.
- If using `tcolorbox`, add colors to the COLORS section with `\definecolor`.
- Document the environment's color, border, and breakability.

### Adding a new color
- Define in the COLORS section of `guide.cls` with `\definecolor`.
- Use HTML hex values: `\definecolor{name}{HTML}{RRGGBB}`.
- Do not change existing color values (locked, see L9).

---

## File editing rules

- **`guide.cls`** — guide-specific formatting (cover, TOC, titles). Shared
  formatting lives in `templates/_base/huawei-*.sty` modules. Changes here
  affect every document. Test with both samples before committing.
- **`technical.cls`** — technical-report-specific formatting (cover, TOC, titles). Same rules as `guide.cls`: test with both samples before committing.
- **`.tex` files** — content only. No formatting overrides, no `\usepackage`,
  no `\renewcommand`. All look-and-feel comes from `guide.cls`. After any
  AI-assisted edit, bump version and add changelog entry (see L11).
- **`SKILL.md`** — canonical command and environment reference. Must stay in
  sync with `guide.cls`. Every command in the class must be documented here.
  Every locked decision must be respected.
- **`README.md`** (root) — comprehensive installation, setup, and project info
  for all templates. The single source of truth for environment setup,
  requirements, compilation, and project layout.
- **`README.md`** (template) — brief template-specific details only (class
  options, format tokens, customization). Points to root README for setup and
  SKILL.md for commands. Do not duplicate content from either.
- **`AGENTS.md`** (this file) — update when standards change or new locked
  decisions are made.
- **Samples** — must always compile. They are the user's reference. Any new
  feature must be demonstrated in both samples.
- **`install.sh`** — reads skill name from SKILL.md frontmatter. Do not
  hardcode skill names in the script.

---

## Git conventions

- Commit messages: imperative mood, concise first line, detail in body.
- Never commit build artifacts (`.aux`, `.log`, `.out`, `.toc`,
  `.xdv`, `.fls`, `.fdb_latexmk`, `.synctex.gz`). They are in `.gitignore`.
- **Compiled PDFs are committed**: `examples/guide/pt/main.pdf`,
  `examples/guide/en/main.pdf`, `examples/setup-guide/setup-guide.pdf`,
  `examples/technical/pt/main.pdf`, and `examples/technical/en/main.pdf`
  are committed to git for validation. All other PDFs are gitignored.
  Always recompile and commit updated PDFs when `.tex` or `.cls` files change.
- A commit that breaks sample compilation must not be pushed to `main`.
- **One change, commit, push.** Make one logical change, commit it, and push
  immediately. Do not accumulate multiple unpushed commits. This keeps the
  remote in sync, makes each change individually revertable, and avoids losing
  work to a local-only working tree.
