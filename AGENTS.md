# AGENTS.md — Project Standards

This file defines the conventions, locked decisions, and workflows for
any agent or human working on this repository. Read it before making
changes.

---

## Scope

This file governs development of the **template repository itself** —
the classes, converters, scripts, tests, samples, and documentation that
make up the templates.

**User documents are standalone deliverables, not repository content.**
Documents created via the skills (in `documents/<name>/`) are gitignored;
git operations (commit, push, tag) apply only to template code, never to
user documents. A document's own versioning is its `:version:` attribute
+ changelog block (L11); L17's tag-per-change applies to template
releases only.

---

## Project overview

See [README.md](README.md) for project overview, setup, and layout.

**Source format:** AsciiDoc (`.adoc`). Authors write AsciiDoc; the build
system converts it to LaTeX (`.tex`) via a custom Ruby converter
(`huawei-latex-converter.rb`), then compiles to PDF via XeLaTeX.
LaTeX is generated, not hand-edited.

---

## Workflow

1. Edit `.Adoc` source files.
2. Validate end-to-end (see below) — including `make all-formats` for all
   output formats (PDF, DOCX, MD, HTML).
3. Quality pass: spawn a fresh subagent to review all changes (see below).
4. Commit with a clear message (see Git conventions).
5. Push: `git push origin main && git push --tags`.
6. Repeat.

**Always commit and push after completing a unit of work** (template repo
work — see Scope). Do not accumulate multiple unrelated changes in one
commit. Do not leave uncommitted changes.

---

## End-to-End Validation

Before committing, validate the change from **all** relevant perspectives:

1. **Compile + test:** Run `make samples` (converts `.adoc` → `.tex` → PDF
   for all template samples) and `make test` (runs `test-pdf-compile.sh`,
   `test-preprocessor.sh`, `round-trip.sh`, `test-docx-fix.sh`,
   `test-sync.sh`, `test-converter.sh`).
   All must pass.
   Verify 0 raw LaTeX blocks in output.

   **Generate all output formats:** After every change, also run
   `make all-formats` to produce DOCX, Markdown, and HTML for all
   samples. This ensures that changes to the converter, class files,
   or shared modules do not break secondary output formats. Check
   that each format renders correctly (headings, tables, callouts,
   code blocks, images). PDF is the primary reference (L18); DOCX,
   MD, and HTML must match it as closely as possible. Do not commit
   until all four formats are verified.

2. **Cross-file consistency:** If you changed one file, check every file that
   references it:
    - Changed `guide.cls`, `technical.cls`, `testbook.cls`, or `poc.cls`? Check `SKILL.md` command tables,
      `README.md` (template), both samples (`documents/<name>-pt/` + `documents/<name>-en/`),
      and `setup-guide.adoc`.
   - Changed a `templates/_base/huawei-*.sty` module? Check all templates that
     load it, all samples, and `setup-guide.adoc`.
   - Changed `huawei-latex-converter.rb`? Check all templates' PDF output —
     run `make samples`. Check HTML output with `asciidoctor -b html5`.
   - Changed `docx_fix.py` or `embed-images.py`? Check all templates' DOCX/MD
     output.
   - Changed a sample `.adoc`? Recompile and verify the PDF, then regenerate
     multi-format output.
   - Changed `scripts/install.sh`? Check `README.md` setup section and `SKILL.md`
     quick-start steps.
   - Added a new command/environment? Document in `SKILL.md` + `README.md`,
     demonstrate in all samples.

3. **Documentation accuracy:** Read the affected documentation sections and
   verify they match the actual code. Command tables, examples, and
   descriptions should reflect current behavior — not stale descriptions.

4. **Edge cases:** Consider:
   - New template? Verify Makefile auto-discovery, `scripts/build.sh` auto-detection,
     `scripts/install.sh` auto-discovery, all test scripts.
   - New command? Check it renders correctly in PDF, DOCX, MD, and HTML.
   - New image asset? Verify TEXINPUTS resolution (project `assets/` first,
     then `common-assets/`).
   - `:lang: pt` header attribute? Check both PT and EN samples compile.
   - `:nochangelog:` attribute? Verify changelog suppression works.
   - Version bump? Check `test-sync.sh` passes (cls version = setup-guide
     version = git tag).

---

## Quality Pass

After validation passes, spawn a **fresh `@oracle` session** (new session,
no prior context) to do a thorough quality pass through all changes. Oracle
reviews only the diff and changed files — not the conversation history —
ensuring an independent, unbiased review.

### Why fresh context

A subagent with prior context knows what was *intended* and may overlook
issues a fresh reviewer would catch. A new session reviews only what the
code actually does, not what it was supposed to do.

### Process

1. Spawn a fresh `@oracle` with the diff (`git diff`) and a one-sentence
   summary of what changed. Oracle reviews without any prior context.
2. Oracle reports findings (HIGH / MEDIUM / LOW).
3. The same `@fixer` session uses oracle's findings to fix HIGH and
   MEDIUM issues.
4. Re-validate: `make samples && make test`.
5. LOW findings may be deferred to a follow-up.
6. Commit only after fixes are validated.

### Review for

- **Bugs:**
  - Logic errors (wrong variable, inverted condition, off-by-one)
  - Unhandled edge cases (empty input, missing files, non-zero exits)
  - Race conditions (concurrent access, ordering dependencies)
  - Resource leaks (unclosed handles, orphaned processes, temp files)

- **Error handling:**
  - Failures degrade gracefully, not just crash
  - Error messages are actionable (tell user how to fix)
  - Exit codes correct (0=success, non-zero=failure)
  - Cleanup runs on failure (trap handlers, finally blocks)

- **Security:**
  - No secrets in logs, process list, or error messages
  - User input validated and sanitized
  - File permissions appropriate (not world-readable for secrets)
  - No command injection (quoted variables, no eval on user input)

- **Simplicity:**
  - No over-engineering (YAGNI)
  - No unnecessary abstractions or indirection
  - Dead code removed
  - Complex logic has explanatory comments

- **Maintainability:**
  - Functions do one thing (single responsibility)
  - No magic numbers that should be configurable
  - Dependencies are explicit, not hidden
  - Changes don't require touching unrelated code

- **Modularity:**
  - Clear separation of concerns
  - Shared logic extracted into reusable helpers
  - No circular dependencies
  - Modules can be tested independently

- **Consistency:**
  - Naming conventions followed throughout
  - Style alignment (indentation, quoting, formatting)
  - Cross-file references valid (names, paths, flags)
  - Patterns match existing codebase conventions

- **Quality of life:**
  - Output formatted consistently (alignment, colors, spacing)
  - Dry-run/preview mode accurate
  - Help text matches actual flags and behavior
  - Interactive prompts have sensible defaults

- **Documentation:**
  - Docs match current behavior, not stale descriptions
  - Examples are correct and runnable
  - No duplication across docs (each topic documented once)
  - Text is direct and objective

- **Stale references:**
  - No references to removed files, models, or flags
  - Version numbers current
  - Config values match actual defaults
  - Comments match code (not outdated TODOs)

- **Performance:**
  - No redundant calls or repeated parsing
  - No blocking operations where async would work
  - Startup/shutdown time reasonable
  - Resource usage proportional to workload

- **Backwards compatibility:**
  - No breaking changes without migration path
  - Deprecated features have upgrade instructions
  - Config format backward-compatible
  - Upgrade path tested (old → new version)

### When to skip

Trivial changes only (one-line typo, doc-only edit with no code impact).
When in doubt, run the quality pass.

---

## Locked decisions (do NOT change)

These decisions were explicitly made and must not be reversed without user
approval. Changing them breaks existing documents and reproducibility.

> **Note:** L2, L3, L7, L10 were moved to Conventions in v2.0.0 (see [CHANGELOG.md](CHANGELOG.md)). Numbers are retained for traceability.

### L1. PDF engine: XeLaTeX only. Source format: AsciiDoc.
- `guide.cls` loads `fontspec`, which requires XeLaTeX or LuaLaTeX.
- `pdflatex` will **not** work. Never remove `fontspec` or switch to pdflatex.
- `.latexmkrc` sets `$pdf_mode = 5` (xelatex). Do not change this.
- Source files are AsciiDoc (`.adoc`). LaTeX (`.tex`) is generated by
  `huawei-latex-converter.rb` and is a build artifact — never hand-edit it.

### L4. Template default timezone is America/Sao_Paulo (GMT-3)
- The template's `.latexmkrc` files set `$ENV{TZ} = "America/Sao_Paulo"`.
- Projects can override TZ in their own `.latexmkrc` (last one wins).
- This default matches the primary user timezone; override for other regions.

### L5. Cover page shows version + date + time automatically
- Version comes from the `:version:` AsciiDoc header attribute.
- Date defaults to compilation date. Time comes from TeX's `\time` primitive
  (HH:MM, respects TZ env).
- Both are shown on the cover page by default. Pass `:notime:` attribute
  to hide the time.
- `:nochangelog:` also hides version, date, and time on the cover page
  (see L12).
- `:date:` attribute can override the date, but time is always compilation
  time (when shown).

### L6. Self-contained project folders
- Every document lives in its own folder. Source files (`.adoc` and
  `.latexmkrc`) go in a `src/` subfolder; generated outputs (PDF, DOCX,
  MD, HTML) go in the document root.
- Never scatter `.adoc` files directly in the workspace root.
- The `.latexmkrc` sets `TEXINPUTS` pointing to `templates/<name>/` and `templates/_base/`.

### L8. Font fallback chain
- Main font: HarmonyOS Sans -> Liberation Sans (sole fallback).
- Mono font: Cascadia Code -> DejaVu Sans Mono (sole fallback).
- Brand fonts are loaded with `\IfFontExistsTF`; if missing, a single
  fallback is used with a class warning.
- Removed fallbacks: Arial, Consolas, fontspec default.
- `scripts/install.sh` installs both brand fonts; the fallbacks are safety nets.

### L9. Colors are hardcoded to Huawei brand
- Corporate: `huaweired` (`#C7000B`, PMS 185C), `ruleblack` (`#000000`).
- Callout colors (aligned to brand auxiliary palette, see L20):
  `warningbg/fg` (orange `#FFF3E0`/`#ED6D00`), `tipbg/fg` (green
  `#E8F5E9`/`#62B230`), `infobg/fg` (blue `#E0F7FA`/`#30B5C5`).
- Code block: `codebg` (`#F6F8FA`), `codetext` (`#1F2328`),
  `codeborder` (`#E1E4E8`).
- Hyperlinks: `linkblue` (`#0000FF`).
- Do not change these values. They match the Huawei house style.
- Source: `brand-guidelines/BRAND-GUIDELINES.md` (HUAWEI CLOUD BRAND
  GUIDELINES V1.0, Section 2.11–2.13).

### L11. Auto-version on every AI-assisted change
- Every AI-assisted edit to a document must bump the `:version:` header
  attribute and add a `\changelogentry` (newest first) in the `changelog`
  passthrough block.
- Bump levels: patch (typo/wording), minor (new content/section), major
  (structural/breaking).
- Recompile after bumping. The PDF must always reflect the latest version.
- See `SKILL.md` "Versioning workflow" for the full procedure.

### L12. Changelog can be disabled with `:nochangelog:`
- The `changelog` environment emits its own section heading (language-aware:
  "Changelog" / "Histórico de versões"); do not add a heading before it.
- The `:nochangelog:` attribute makes `changelog` and `\changelogentry`
  no-ops, suppressing the heading AND entries in one switch (content stays
  in `.adoc` but nothing is rendered).
- It also hides version, date, and time on the cover page (see L5).
- Use when the changelog grows too large for the PDF.
- Default: changelog is shown.

### L13. New documents go in `documents/`
- All user-created documents live in `documents/<doc-name>/` subfolders.
  Source files (`.adoc`, `.latexmkrc`) go in `documents/<doc-name>/src/`;
  generated outputs go in `documents/<doc-name>/`.
- The `documents/` folder at the repo root is the default location.
- Each document is self-contained: `src/` (with `.adoc` and `.latexmkrc`),
  `assets/`.
- Skills create new document folders inside `documents/` by default.
- Samples also live in `documents/` (e.g., `documents/guide-pt/`,
  `documents/guide-en/`, `documents/setup-guide/`).

### L14. Floats default to [H] (in-source order, no drifting)
- The class loads `float` and sets `\fps@figure`/`\fps@table` to `H`, so
  `figure` and `table` floats appear exactly where declared, in source order.
- This matches the inline-image design (`image::` is non-floating).
- Users may still override a single float with an explicit `[h]`, `[t]`, `[b]`,
  or `[p]`; the default only applies when no placement is given.
- Tables use the `hutable` role (full-grid, Huawei-red header, alternating
  body rows). Do not reintroduce raw `tabular` + manual `\midrule`/`\bottomrule`
  in samples — use `[.hutable]`.

### L15. Core/template inheritance: shared components in `templates/_base/`
- **Core components** live in `templates/_base/` and are inherited by all templates:
  - Base class: huawei-base.cls (shared class options portuguese/indentbody/notime/
    nochangelog/noauthors, `\LoadClass` of article, all shared package loads, the 13
    huawei-* module loads, and `\setdoctitle`).
  - LaTeX modules: huawei-colors, huawei-fonts, huawei-lang, huawei-page, huawei-tables,
    huawei-code, huawei-callouts, huawei-images, huawei-changelog, huawei-shared,
    huawei-cover, huawei-titles, huawei-toc, huawei-badges.
  - (Note: `huawei-badges` is only loaded by templates that use badges: `testbook` and `poc`.)
  - Converter: huawei-latex-converter.rb (AsciiDoc → LaTeX, shared by all templates).
  - Output styling: huawei.css (HTML), huawei.js (copy-to-clipboard), docinfo.html.
  - Pre-processing: adoc_docx_preprocessor.py (DOCX/MD/HTML — converts passthrough blocks/roles).
  - Post-processing: docx_fix.py (DOCX), embed-images.py (MD).
  - Diagram config: puppeteer-config.json (mermaid --no-sandbox).
- **Template classes** build on `huawei-base.cls`: guide, technical, and poc call
  `\LoadClassWithOptions{huawei-base}`; testbook declares its extra `noanswers`
  option in the child class, passes remaining options through with
  `\DeclareOption*`, then calls `\LoadClass{huawei-base}`.
- **Template-specific** code stays in `templates/<name>/<name>.cls`:
  - guide: base template (no additions beyond core).
  - technical: 5-section structure (problem, rootcauseanalysis, rootcause, triggercondition, workaround).
  - testbook: testcase/testsummary environments, test result badges, `:noanswers:` option.
  - poc: result badges, stakeholders, closing record, signatures.
- Each SKILL.md is self-sufficient (no shared/external references) but organized with
  "Core Components" and "Template-Specific Features" sections.
- Do not add `\RequirePackage` calls inside `.sty` modules — packages are loaded by
  class files: the shared packages by `huawei-base.cls`, template-specific packages
  (tabularx, amssymb, seqsplit) by the template class.

### L16. AsciiDoc is the single source of truth. LaTeX is generated.
- AsciiDoc (`.adoc`) is the source format that authors edit. LaTeX (`.tex`)
  is generated by `huawei-latex-converter.rb` and compiled to PDF via XeLaTeX.
- Never hand-edit a generated `.tex` file — changes will be overwritten.
- The `.cls` and `.sty` files are still hand-maintained (LaTeX rendering engine).
- DOCX and Markdown are generated via a pre-processor
  (`adoc_docx_preprocessor.py`) then `asciidoctor -b docbook` →
  `pandoc -f docbook`. DOCX is post-processed by `docx_fix.py --fix`;
  HTML is generated via the pre-processor → `asciidoctor -b html5` with
  `huawei.css`.
- Generated outputs (`.tex`, `.docx`, `.md`, `.html`) are gitignored build artifacts.

### L17. Version tag + validation after each change
- Applies to template releases only — user documents are versioned via
  L11 (`:version:` + changelog), never via git tags.
- After every change (bug fix, feature, docs edit), create a new git version tag
  (e.g., `v6.0.1`, `v6.0.2`, `v6.1.0`).
- Before tagging, validate: compile all samples (`make samples`, which converts
  `.adoc` → `.tex` → PDF for all templates), run all tests
  (`make test`, which runs `test-pdf-compile.sh`, `test-preprocessor.sh`,
  `round-trip.sh`, `test-docx-fix.sh`, `test-sync.sh`, and
  `test-converter.sh`), and verify 0 raw LaTeX blocks in output.
- Tag format: `v<major>.<minor>.<patch>` — patch for fixes, minor for features,
  major for breaking changes.
- Push the tag: `git push --tags`.
- See [CHANGELOG.md](CHANGELOG.md) for the version history.
- The tag is the release — there are no separate release branches.

### L18. PDF is the reference — all formats follow it
- AsciiDoc → LaTeX → PDF is the primary output and the visual reference.
- DOCX, Markdown, and HTML are secondary outputs that should match the
  PDF as closely as possible in styling: fonts, colors, callout boxes,
  table styling, heading appearance, and spacing.
- When adding or changing any visual element, update all formats to
  match the PDF. The Ruby converter, reference DOCX, and HTML template/CSS must
   stay in sync with `guide.cls`, `technical.cls`, `testbook.cls`, and `poc.cls`.

### L19. Authors are optional and hideable with `:noauthors:`
- `:authors:` header attribute sets one or more authors displayed on the cover page.
- If not set, nothing is shown (no placeholder, no empty space).
- The `:noauthors:` attribute hides authors even if set (like
  `:nochangelog:` suppresses the changelog).
- In `guide.cls`, authors appear below the cover text, above version/date/time.
- In `technical.cls`, authors appear as a row in the cover version table.
- In `testbook.cls`, authors appear below the cover text, above version/date/time.
- In `poc.cls`, authors appear below the cover text, above version/date/time.
- The attribute is processed by `huawei-latex-converter.rb` (shared).

### L20. Auxiliary brand color palette (Brand Guidelines Section 2.12)
- Six auxiliary colors are defined in `templates/_base/huawei-colors.sty`:
  `rosered` (`#C40054`, PMS 7636), `darkred` (`#7F0001`, PMS 483C),
  `huaweiorange` (`#ED6D00`, PMS 165C), `huaweiyellow` (`#FCC800`, PMS 7406C),
  `huaweigreen` (`#62B230`, PMS 3501C), `huaweiblue` (`#30B5C5`, PMS 2227C).
- Monochrome palette: `huaweiblack` (`#000000`), `huaweigray90` (`#E5E5E5`),
  `huaweigray80` (`#CCCCCC`), `huaweigray50` (`#808080`),
  `huaweigray30` (`#4D4D4D`), `huaweiwhite` (`#FFFFFF`).
- CBG-only red (`#CE0E2D`, PMS 186C) is intentionally excluded — reserved
  for Consumer BG, not for Cloud Computing BU documents.
- Auxiliary colors must be used together with their main colors (per brand
  guidelines). Use for charts, diagrams, and classification attributes.
- Do not change these values. Source: `brand-guidelines/BRAND-GUIDELINES.md`.

### L22. Custom environments use AsciiDoc roles and passthrough blocks.
- Huawei-specific environments map to AsciiDoc roles:
  `[.objectives]`, `[.hutable]`, `[.problem]`, `[.rootcauseanalysis]`, etc.
- The `changelog` and `testcase` environments use LaTeX passthrough blocks
  (`++++\n\begin{changelog}...\end{changelog}\n++++`) because they have
  complex internal structure not representable in AsciiDoc.
- The Ruby converter (`huawei-latex-converter.rb`) translates roles to
  the corresponding LaTeX commands and environments.

### L23. Document metadata uses AsciiDoc header attributes.
- `:template: guide|technical|testbook|poc` — selects the template class.
- `:lang: en|pt` — sets the language (replaces `\documentclass[portuguese]`).
- `:version: X.Y.Z` — sets the document version (replaces `\setdocversion`).
- `:date: YYYY-MM-DD` — sets the document date (replaces `\setdocdate`).
- `:authors: Name` — sets the authors (replaces `\setdocauthors`).
- `:nochangelog:` — suppresses the changelog (replaces class option).
- `:noauthors:` — hides the authors (replaces class option).
- `:notime:` — hides the compilation time (replaces class option).
- The Ruby converter reads these attributes and generates the corresponding
  LaTeX preamble commands and class options.

---

## Conventions

These are stable naming and structural conventions. Changing them would be a
major version bump, not a violation of a locked decision.

### Class name: `guide` or `technical` (L2)
- Guide: `:template: guide` header attribute.
- Technical: `:template: technical` header attribute.
- The Ruby converter maps the `:template:` attribute to the correct
  `\documentclass` call.

### Callout box names: `warning`, `tip`, `infobox` (L3)
- AsciiDoc admonitions map directly: `WARNING:`, `TIP:`, `NOTE:`.
- Never reintroduce `aviso`, `dica`, or `info` environments.

### Skill prefix: `huawei-template-` (L7)
- All skills are named `huawei-template-<name>` (e.g. `huawei-template-guide`).
- The prefix is set in the SKILL.md frontmatter `name` field.

### Body order (L10)
- Cover → TOC → body (sections) → changelog → end. Generated automatically
  by the Ruby converter from the AsciiDoc document structure.
- `\startbody` resets page numbering to 1.

---

## Template features

See `templates/guide/SKILL.md` for the full command and environment reference
(class options, header attributes, AsciiDoc syntax, environments,
and content commands). SKILL.md is the canonical source; `templates/guide/README.md`
has the human-readable version with examples.

---

## Project structure

See [README.md "Project layout"](README.md) for the full tree.

---

## Compilation

- **Use `make`** (see [README.md](README.md) for full Makefile reference).
- **Build pipeline:** `asciidoctor -b huawei-latex` → `.tex` → `latexmk` → PDF.
- **Wrapper script:** `scripts/build-adoc.sh` handles the asciidoctor → LaTeX
  conversion step before latexmk.
- **Never use `pdflatex`** — will fail on `fontspec` (locked, see L1).
- **Never hand-edit `.tex`** — it is generated (locked, see L21).
- Multi-format output: `make all-formats` (see [README.md](README.md) for details).

---

## Sample and example conventions

- **Two samples per template**: each template `<name>` has exactly two samples
  in `documents/<name>-pt/` and `documents/<name>-en/` (Portuguese and English).
  Samples demonstrate all available AsciiDoc roles and syntax.
- **Assets folders**: template shared assets (logos, sample images) live in
  `templates/<name>/common-assets/`. Each document has its own `assets/`
  folder for project-specific images and files. LaTeX resolves `assets/` to
  the project folder first, then falls back to `common-assets/` via TEXINPUTS.
  Logos default to `common-assets/` (template-level).
- **Template explanation**: each sample includes a `NOTE:` admonition on the
  first page explaining which template it uses and what it demonstrates.
- **Setup guide is additional**: `documents/setup-guide/` is not a sample — it
  is a real-world document used for validation and actual installation
  instructions. Its multi-entry changelog exercises versioning in depth, and
  it demonstrates features in a practical context.
- **Self-contained**: each sample/example has its own `.latexmkrc` with
  `TEXINPUTS` pointing to `templates/<name>/`. Never share `.latexmkrc` files.

---

## How to create a new skill

Skills are discovered from `templates/<name>/SKILL.md`. The `opencode.json`
at the repo root registers `templates/` as a discovery path.

### Steps

1. **Create the template directory** `templates/<name>/` with:
   - `<name>.cls` — the LaTeX class file (build on
     `templates/_base/huawei-base.cls` via `\LoadClassWithOptions`;
     add only template-specific options, packages, and environments)
   - `SKILL.md` — the skill definition (see format below)
   - `README.md` — human-readable documentation
   - `.latexmkrc` — latexmk config (XeLaTeX, TZ=America/Sao_Paulo default)
   - `common-assets/` — logos, sample images
   - Samples live in `documents/<name>-pt/` and `documents/<name>-en/` (see below)

2. **SKILL.md format** — must start with YAML frontmatter:
   ```yaml
   ---
   name: huawei-template-<name>
   description: <when to trigger this skill>
   ---
   ```
   - The `name` field MUST have the `huawei-template-` prefix (see Conventions).
   - `scripts/install.sh` reads this `name` field to determine the install directory.
   - The `description` field determines when the skill triggers. Keep it
     specific to avoid false activations.

3. **SKILL.md body** should include:
   - **When to use** — clear trigger conditions
   - **Quick start** — step-by-step for creating a new document
   - **AsciiDoc syntax reference** — all roles, attributes, and passthrough
     patterns the template supports
   - **Skeleton** — a minimal `.adoc` template the skill can use as a starting
     point
   - **Hard requirements** — engine, fonts, compilation rules
   - **Project folder convention** — always create a self-contained folder
   - **Timezone note** — document that TZ is per-project, not template-level

4. **Add to `scripts/install.sh`** — the script auto-discovers templates by scanning
   `templates/*/SKILL.md`. No changes needed if the structure is correct.

5. **Add to root `README.md`** — add a row to the Templates table.

### Skill naming rules
- Prefix: `huawei-template-` (see Conventions)
- Examples: `huawei-template-guide`, `huawei-template-technical`
- The skill name in frontmatter must match the directory name under `templates/`
  minus the `huawei-template-` prefix.

---

## How to extend the existing template

### Adding a new command to `guide.cls`, `technical.cls`, `testbook.cls`, or `poc.cls`
1. Define the command in the appropriate `.cls` file (`guide.cls`, `technical.cls`, `testbook.cls`, or `poc.cls`) with a `\newcommand`. If the command is shared across templates, define it in the appropriate `templates/_base/huawei-*.sty` module instead; shared class-level code (class options, package loads, commands like `\setdoctitle`) goes in `templates/_base/huawei-base.cls`.
2. Use internal prefix `\lg@` for internal macros (e.g. `\lg@docversion`).
3. Add the AsciiDoc role or passthrough pattern to `huawei-latex-converter.rb`.
4. Add the syntax to the reference tables in `SKILL.md` and `README.md`.
5. Demonstrate the syntax in all template samples (`documents/guide-pt/`, `documents/guide-en/`, `documents/technical-pt/`, `documents/technical-en/`, `documents/testbook-pt/`, `documents/testbook-en/`, `documents/poc-pt/`, `documents/poc-en/`).
6. Compile both samples to verify: `make samples`.
7. Commit only if both samples compile without errors.

### Adding a new environment
- Same steps as above, but use `\newenvironment` or `tcolorbox`.
- If using `tcolorbox`, add colors to `templates/_base/huawei-colors.sty` with `\definecolor`.
- For AsciiDoc: add a role (e.g., `[.myenv]`) or a passthrough block if the
  environment has complex internal structure.
- Document the environment's color, border, and breakability.

### Adding a new color
- Define in `templates/_base/huawei-colors.sty` with `\definecolor`.
- Use HTML hex values: `\definecolor{name}{HTML}{RRGGBB}`.
- Do not change existing color values (locked, see L9).

### Adding a new shared module
- Shared code (Ruby, Python) lives in `templates/_base/`.
- `huawei-latex-converter.rb` converts AsciiDoc to LaTeX for all templates.
- `docx_fix.py` exports a `main(argv, reference_name)` function.
- Template-specific wrappers in `templates/<name>/` call the shared functions.

---

## How to add a new template

1. **Create the template directory** `templates/<name>/` with:
   - `<name>.cls` — the LaTeX class file (build on
     `templates/_base/huawei-base.cls` via `\LoadClassWithOptions`;
     add only template-specific options, packages, and environments)
   - `create-<name>-reference-docx.py` — thin wrapper (~16 lines) that imports
     `templates/_base/docx_fix.py`
   - `<name>-reference.docx` — reference DOCX for Pandoc
   - `<name>-template.html` — HTML template for Pandoc
   - `SKILL.md`, `README.md`, `.latexmkrc`, `common-assets/`

2. **Create samples** in `documents/<name>-pt/` and `documents/<name>-en/`
   with `.adoc` source files.

3. **Done** — no changes needed to:
   - Makefile (auto-discovers via `$(wildcard templates/*/)` + `eval`)
   - scripts/build.sh (auto-detects template from `.latexmkrc` TEXINPUTS)
   - scripts/build-adoc.sh (uses `:template:` attribute from `.adoc` header)
   - scripts/install.sh (auto-discovers template sample dirs)
   - test-sync.sh, test-docx-fix.sh, round-trip.sh (auto-discover templates and samples)
   - test-pdf-compile.sh (auto-discovers template sample logs; setup-guide is hardcoded)

The naming convention is critical:
- Converter: `templates/_base/huawei-latex-converter.rb` (shared)
- DOCX fix: `templates/<name>/create-<name>-reference-docx.py`
- Reference DOCX: `templates/<name>/<name>-reference.docx`
- HTML template: `templates/<name>/<name>-template.html`
- Samples: `documents/<name>-{pt,en}/src/main.adoc`

---

## File editing rules

- **`guide.cls`** — guide-specific code only (the `\setguidetitle` alias). Shared
  class boilerplate (class options, article load, package loads, shared modules)
  lives in `templates/_base/huawei-base.cls`; shared formatting lives in
  `templates/_base/huawei-*.sty` modules. Changes here affect every guide
  document. Test with both samples before committing.
- **`technical.cls`** — technical-report-specific code (metadata commands, 5-section
  environments, cover page). Shared boilerplate lives in `huawei-base.cls`. Same
  rules as `guide.cls`: test with both samples before committing.
- **`testbook.cls`** — test-book-specific code (testcase/testsummary environments,
  test result badges, `noanswers` option). Shared boilerplate lives in
  `huawei-base.cls`. Same rules as `guide.cls`. Test with both samples before
  committing.
- **`poc.cls`** — POC/homologation-specific code (result badges, stakeholders,
  closing record, signatures). Shared boilerplate lives in `huawei-base.cls`.
  Same rules as `guide.cls`. Test with both samples before committing.
- **`templates/_base/huawei-base.cls`** — shared class boilerplate (class options,
  article load, package loads, shared module loads, `\setdoctitle`). Changes
  affect ALL templates. Test with `make samples` before committing.
- **`templates/_base/huawei-latex-converter.rb`** — shared AsciiDoc-to-LaTeX
  converter. Changes affect ALL templates' PDF output. Test with
  `make samples` before committing.
- **`templates/_base/docx_fix.py`** — shared DOCX post-processing. Changes
  affect ALL templates' DOCX output. Test with `make test` before committing.
- **`templates/_base/embed-images.py`** — shared MD image embedding. Changes
  affect all templates' Markdown output. Test with `make all-formats` before
  committing.
- **`.adoc` files** — content only. No formatting overrides, no raw LaTeX
  (except passthrough blocks for changelog and testcase). All look-and-feel
  comes from the template `.cls` file, `templates/_base/` shared modules, and
  the Ruby converter. After any AI-assisted edit, bump version and add
  changelog entry (see L11).
- **`SKILL.md`** — canonical AsciiDoc syntax reference. Must stay in
  sync with all template class files, `templates/_base/` modules, and
  `huawei-latex-converter.rb`. Every role and passthrough pattern must be
  documented here. Every locked decision must be respected.
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
- **`scripts/install.sh`** — reads skill name from SKILL.md frontmatter. Do not
  hardcode skill names in the script.

---

## Code style

- **AsciiDoc** (`.adoc`): 2-space indent for nested content, no trailing
  whitespace. Header attributes on separate lines (`:template: guide`,
  `:lang: en`, `:version: 1.0.0`). Roles use `[.rolename]` prefix syntax.
  Passthrough blocks use `++++` delimiters for changelog and testcase.
  Admonitions use `WARNING:`, `TIP:`, `NOTE:` prefixes. Code blocks use
  `[source,lang]` with `----` delimiters. Tables use `|===` delimiters with
  `[.hutable]` role prefix.
- **LaTeX** (`.cls`, `.sty`): 2-space indent, no trailing whitespace,
  sentences end with period. Use `\newcommand` / `\newenvironment` — never
  redefine existing commands. Internal macros use `\lg@` prefix.
- **Ruby** (`huawei-latex-converter.rb`): 2-space indent, `snake_case` for
  methods and variables. Follow existing converter patterns for node types.
- **Shell scripts** (`scripts/build.sh`, `scripts/build-adoc.sh`,
  `scripts/install.sh`, `tests/*.sh`):
  `set -euo pipefail`, 2-space indent, `snake_case` for variables.
- **Python scripts** (`docx_fix.py`, `embed-images.py`): PEP 8, 4-space indent.
- **Makefile**: tabs for recipe lines (never spaces), target names in
  `lowercase`, `.PHONY` for non-file targets.
- **Markdown** (`SKILL.md`, `README.md`, `CHANGELOG.md`): 2-space indent for
  nested lists, sentences end with period, no trailing whitespace.

---

## Git conventions

### Commit messages

Use imperative mood, capitalized first word, no trailing period. First line
≤72 characters, blank line, then body with `-` bullets for details:

```
Add verification checklist tables to all setup-guide chapters

- Chapter 1-7: added hutable with step/what-to-check/expected columns
- Updated changelog entry for 3.1.0
- Recompiled all formats (PDF, DOCX, MD, HTML)
```

Conventional commit style (optional but encouraged):

```
feat: add technical report template with 5-section structure
fix: resolve raw LaTeX leak in Markdown output from \menu command
docs: sync SKILL.md command table with new \imagecap command
```

### Git author

Before committing, verify the git author matches the expected account:

```bash
git config user.name   # wallacelw-bot
git config user.email  # wallacelw-bot@users.noreply.github.com
```

Never set a local `user.name`/`user.email` that differs from the global
config. If a local override exists, remove it:

```bash
git config --local --unset user.name
git config --local --unset user.email
```

### Never commit

- Build artifacts: `.aux`, `.log`, `.out`, `.toc`, `.xdv`, `.fls`,
  `.fdb_latexmk`, `.synctex.gz` (covered by `.gitignore`).
- Generated LaTeX: `.tex` files (build artifacts from `huawei-latex-converter.rb`).
- Generated multi-format outputs: `.docx`, `.md`, `.html` (build artifacts,
  except committed sample PDFs below).
- Secrets: API keys, passwords, tokens, `.env` files.
- Backup files: `*.bak`, `*.bak.*`.

### Compiled PDFs are committed

`documents/guide-pt/main.pdf`, `documents/guide-en/main.pdf`,
`documents/setup-guide/setup-guide.pdf`, `documents/technical-pt/main.pdf`,
`documents/technical-en/main.pdf`, `documents/testbook-pt/main.pdf`,
`documents/testbook-en/main.pdf`, `documents/poc-pt/main.pdf`,
and `documents/poc-en/main.pdf` are committed to git for validation.
All other PDFs are gitignored. Always recompile and commit updated PDFs when
`.adoc`, `.cls`, or `.sty` files change.

The `documents/setup-guide/` folder contains the compiled setup guide
in all four formats (PDF, MD, DOCX, HTML) for users to read before cloning.
These are committed to git. Run `make setup-guide` to regenerate.

### Before committing

- Check `git status` — only stage intended files, no stray artifacts.
- Check `git diff --cached` — review what you are about to commit.
- Run the full End-to-End Validation section above — not just one perspective.
- All changes must be validated before pushing. No exceptions.

### Workflow rules

- A commit that breaks sample compilation must not be pushed to `main`.
- **One change, commit, push.** Make one logical change, commit it, and push
  immediately. Do not accumulate multiple unpushed commits. This keeps the
  remote in sync, makes each change individually revertable, and avoids losing
  work to a local-only working tree.
- **Batching:** Group related changes into one version bump instead of tagging
  each incremental step. A setup-guide rewrite across many edits should be
  one CHANGELOG entry and one tag, not 20 separate tags.

---

## When unsure

- Ask the user before making architectural decisions.
- Ask before changing locked decisions (L1–L23).
- Ask before modifying the build system (Makefile, `scripts/build.sh`,
  `scripts/build-adoc.sh`, `scripts/install.sh`).
- Ask before changing the template structure or adding new templates.
- Do not guess — clarify first.
