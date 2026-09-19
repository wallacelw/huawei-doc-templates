# Huawei Document Templates

A collection of templates for Huawei Cloud documents. Each template lives
under `templates/<name>/` and is self-contained: class file, samples,
skill, assets, and build config. Documents are written in AsciiDoc
(`.adoc`); PDF is generated via `asciidoctor -b huawei-latex` → LaTeX →
XeLaTeX.

**See what the output looks like:** [`documents/gallery/`](documents/gallery/) —
screenshots of the cover page, content pages, code blocks, tables, callouts,
and changelog.

## Quick start

**One-liner (clone + install):**

```bash
curl -fsSL https://raw.githubusercontent.com/wallacelw/huawei-doc-templates/main/scripts/install.sh | bash
```

If an existing installation is detected, the one-liner prompts to update
(`Update v6.0.9 → v6.1.0? [Y/n]`) and pulls the latest version.

**Or step by step:**

```bash
git clone https://github.com/wallacelw/huawei-doc-templates.git
cd huawei-doc-templates
./scripts/install.sh
```

When run interactively (`./scripts/install.sh`), you'll be prompted for optional
components (default yes):

- Install opencode skills? `[Y/n]`
- Configure VS Code LaTeX Workshop? `[Y/n]`

When run via one-liner, all components are installed automatically.

Then open the project in [opencode](https://opencode.ai) and run:

```
/skill huawei-template-guide
```

### Pre-compiled setup guide

The `documents/setup-guide/` folder contains the full installation guide
in all four output formats. You can read these before cloning the repo to
understand the setup process:

| File | Best for |
|---|---|
| `documents/setup-guide/setup-guide.pdf` | Reading on screen or printing — full visual styling (brand colors, callout boxes, cover page) |
| `documents/setup-guide/setup-guide.md` | Copy-pasting commands — code blocks copy cleanly; feed to AI/LLM tools |
| `documents/setup-guide/setup-guide.docx` | Collaborative editing in Microsoft Word — track changes, comments |
| `documents/setup-guide/setup-guide.html` | Web publishing — responsive, self-contained, viewable in any browser |

> **Tip:** If you need to copy commands from the guide, use the **Markdown**
> file. PDF copy-paste often breaks on ligatures and special characters.

Run `make setup-guide` to regenerate all four formats after changing the source.

## Requirements

- **OS:** Ubuntu 22.04+ (WSL or native)
- That's it — `install.sh` handles everything else.

`install.sh` installs:

- XeLaTeX + latexmk + LaTeX packages (`texlive-xetex`, `texlive-latex-extra`,
  `texlive-lang-portuguese`)
- fvextra ≥ 1.5 (updated from CTAN if the system version is too old)
- HarmonyOS Sans font (body text — from GitHub releases, SHA-256 verified)
- Cascadia Code font (code — via `fonts-cascadia-code`)
- asciidoctor + asciidoctor-diagram (Ruby gems via Gemfile)
- opencode skills (copies each `templates/*/SKILL.md` to `~/.config/opencode/skills/`)
- VS Code LaTeX Workshop extension + settings (local and remote)

> `pdflatex` won't work — the templates use `fontspec` (system fonts), which
> requires XeLaTeX. `install.sh` installs and configures XeLaTeX automatically.

### Uninstalling

**One-liner:**

```bash
curl -fsSL https://raw.githubusercontent.com/wallacelw/huawei-doc-templates/main/scripts/uninstall.sh | bash
```

**Or from the repo:**

```bash
./scripts/uninstall.sh                  # interactive menu (5 options)
./scripts/uninstall.sh --all            # remove everything except apt packages
./scripts/uninstall.sh --all --packages # also remove apt packages (WARNING: breaks other TeX)
./scripts/uninstall.sh --all --repo     # also delete the repo directory
./scripts/uninstall.sh --all --dry-run  # preview what would be removed
```

Interactive menu options:

1. All installed components (skills, modules, font, VS Code) — safe
2. Everything + apt packages (WARNING: breaks other TeX)
3. Delete repository directory (all files, guides, documents)
4. Remove 100% — everything + apt + repo (nuclear option)
5. Choose specific components individually

`uninstall.sh` removes: opencode skills, `.sty` modules from TDS, HarmonyOS Sans
font, `/etc/LatexMk` xelatex fix, VS Code settings + extensions. Use `--packages`
to also remove apt packages (texlive, latexmk, fonts, pandoc). Use `--repo` to
also delete the repository directory (requires typing `yes` to confirm).

## Building documents

## Compilation

### Using the Makefile (recommended)

```bash
make                 # show help (list all available targets)
make all             # compile everything: all samples + setup-guide + all formats (MD + DOCX + HTML)
make samples         # compile all template samples (guide + technical + testbook + poc, PT + EN)
make guide-pt        # compile Portuguese guide sample only
make guide-en        # compile English guide sample only
make technical-pt    # compile Portuguese technical sample only
make technical-en    # compile English technical sample only
make testbook-pt     # compile Portuguese testbook sample only
make testbook-en     # compile English testbook sample only
make poc-pt          # compile Portuguese POC sample only
make poc-en          # compile English POC sample only
make technical-samples # compile technical report samples (PT + EN, PDF)
make technical DIR=documents/my-report  # compile a technical report (latexmk in src/)
make setup-guide     # compile setup guide only
make project DIR=documents/my-guide   # compile a specific project (auto-detects .adoc)
make menu            # interactive format selection (PDF/DOCX/MD/HTML)
make preview DIR=documents/guide-en  # generate HTML preview and open in browser
make watch DIR=documents/guide-en    # watch .adoc files and recompile PDF on save (requires entr or inotifywait)
make all-formats     # generate DOCX + MD + HTML for all samples + setup-guide
make clean           # remove all build artifacts
make clean-formats   # remove generated multi-format files
```

Bare `make` prints a self-documenting help summary (the Makefile is
self-documenting via `## ` annotations on each target). `make --help` is
reserved by GNU make and prints make's own usage; use `make` or `make help`
for the project target list.

### Build pipeline

Each document follows this pipeline:

1. **AsciiDoc → LaTeX:** `asciidoctor -b huawei-latex -r templates/_base/huawei-latex-converter.rb src/main.adoc -o src/main.tex`
2. **LaTeX → PDF:** `latexmk src/main.tex` (XeLaTeX, configured in `.latexmkrc`)
3. **AsciiDoc → HTML:** `asciidoctor -b html5 -a stylesheet=huawei.css src/main.adoc`
4. **AsciiDoc → DOCX/MD:** via `asciidoctor -b docbook` → `pandoc -f docbook`

The `scripts/build-adoc.sh` wrapper handles step 1 before latexmk.

### Using latexmk directly

```bash
cd documents/guide-pt/src && latexmk main.tex   # Portuguese sample
cd documents/guide-en/src && latexmk main.tex   # English sample
cd documents/setup-guide/src && latexmk setup-guide.tex   # setup guide
```

Note: the `.tex` file must already exist (generated by `build-adoc.sh`).
If it doesn't, run `scripts/build-adoc.sh` first.

### Interactive build menu

Use `build.sh` to interactively select which output formats to generate:

```bash
./scripts/build.sh documents/guide-en    # interactive menu for the EN sample
./scripts/build.sh --all documents/guide-en   # non-interactive: all formats
./scripts/build.sh --pdf --docx documents/guide-pt   # non-interactive: PDF + DOCX only
make menu                       # invokes build.sh in interactive mode
```

The menu shows PDF, DOCX, Markdown, and HTML options. Enter one or more
numbers (e.g., `1 3 4` for PDF + MD + HTML), or `all` for everything.

## Timezone

The cover page shows the compilation date and time. The template defaults to
`America/Sao_Paulo` (GMT-3). Override in your project's `.latexmkrc`:

```perl
$ENV{TZ} = "UTC";  # override the template default
```

Set `:notime:` in the AsciiDoc header to hide the time on the cover page.

## Multi-format output (DOCX, Markdown, HTML)

AsciiDoc is the source of truth. LaTeX and PDF are generated from it.
DOCX, Markdown, and HTML are secondary outputs.

### Requirements

- `pandoc >= 3.0` (install via `install.sh` or your package manager)
- `asciidoctor` (Ruby gem, installed by `install.sh`)

### Usage

```bash
make all-formats    # MD + DOCX + HTML for all samples + setup-guide
make md             # Markdown only (guide pt + en + setup-guide)
make docx           # DOCX only (guide pt + en + setup-guide)
make html           # HTML only (guide pt + en + setup-guide)
make clean-formats  # remove generated multi-format files
```

HTML is generated directly from AsciiDoc with `huawei.css` for Huawei brand
styling. DOCX and Markdown are generated via `asciidoctor -b docbook` →
`pandoc -f docbook`, using each template's reference DOCX for custom styles.

Generated outputs are gitignored (build artifacts). Only the converter, CSS,
reference DOCX, HTML template, and Python script are committed.

### Which format should I use?

Each format serves a different purpose. Choose based on your workflow:

| Format | Best for | Copy-paste | Limitations |
|---|---|---|---|
| **PDF** | Reading, printing, visual reference, distribution | Poor — ligatures, special chars, and code blocks do not copy cleanly | Not editable; copy-paste unreliable |
| **Markdown** | Copy-paste, version control diffs, feeding to AI/LLM tools | Excellent — code blocks and text copy cleanly | No visual styling (brand colors, callout boxes) |
| **DOCX** | Collaborative editing in Microsoft Word, track changes | Good — but code blocks may lose formatting | Requires Word; styling approximates PDF |
| **HTML** | Web publishing, online documentation, responsive viewing | Good — browser handles selection | Self-contained file is large; no page breaks |

> **Tip:** If you need to copy commands or code from a document, use the
> **Markdown** output (`make md`). PDF copy-paste often breaks on ligatures
> and special characters — MD preserves code blocks as plain text.

## VS Code (optional)

The repo ships `.vscode/settings.json` pre-configured for **latexmk (XeLaTeX)**.
Install the [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop)
extension, open the repo root, and edit `.adoc` source files to auto-compile
(LaTeX Workshop triggers on the generated `.tex`).
Note: `.tex` files are generated from `.adoc` — edit the `.adoc` source instead.

## Templates

| Template | Skill | Description |
|---|---|---|
| [`guide`](templates/guide/) | `/skill huawei-template-guide` | Huawei Cloud guide — branded cover, header, TOC, giant chapter numbers, objectives block, code blocks, tables, callout boxes, badges, changelog. English (default) and Portuguese. Source: AsciiDoc → LaTeX → PDF. |
| [`technical`](templates/technical/) | `/skill huawei-template-technical` | Huawei Cloud technical report — 5-section structure (problem → root cause analysis → root cause → trigger condition → workaround), branded cover with version info table, TOC, callout boxes, tables, code blocks. Source: AsciiDoc → LaTeX → PDF. Portuguese and English. |
| [`testbook`](templates/testbook/) | `/skill huawei-template-testbook` | Huawei Cloud test case document — POC/acceptance test cases with structured `testcase` environment (Objective, Prerequisites, Procedure, Expected Result, Remarks, Test Result), test scope and acceptance method tables, `:noanswers:` attribute for clean handouts. Source: AsciiDoc → LaTeX → PDF. Portuguese and English. |
| [`poc`](templates/poc/) | `/skill huawei-template-poc` | Huawei Cloud Proof of Concept / homologation document — 3-part, 15-section structure (Preamble → Scope & Planning → Conclusion), stakeholders table, result badges (Pass/Partial/Fail/Skip), activities list, evidence checklist, closing record, signatures. Source: AsciiDoc → LaTeX → PDF. Portuguese and English. |

- **Diagram support**: PlantUML, graphviz, and mermaid diagrams can be embedded directly in `.adoc` files using `[plantuml]`, `[graphviz]`, and `[mermaid]` blocks. Requires `asciidoctor-diagram` gem and corresponding tools (Java+PlantUML, graphviz, mermaid-cli).
- **Brand color palette**: Auxiliary colors (Orange, Green, Blue, etc.) and monochrome scale from Huawei Cloud Brand Guidelines. See `brand-guidelines/BRAND-GUIDELINES.md` for the full reference.

See [`templates/guide/SKILL.md`](templates/guide/SKILL.md) for the full AsciiDoc
syntax reference. See [`templates/technical/SKILL.md`](templates/technical/SKILL.md)
for the technical report template syntax reference.

## Project layout

```
.
├── AGENTS.md               # project standards and locked decisions
├── CHANGELOG.md            # version history
├── Gemfile                 # Ruby dependencies (asciidoctor, asciidoctor-diagram)
├── scripts/                # install, uninstall, and build scripts
│   ├── install.sh          # one-command setup (clone + install + verify)
│   ├── uninstall.sh        # remove installed artifacts (interactive or --all)
│   ├── build.sh            # interactive format selection menu
│   └── build-adoc.sh       # asciidoctor → LaTeX conversion wrapper
├── Makefile                 # build convenience (make samples/setup-guide/clean)
├── opencode.json            # skill discovery: scans templates/ for SKILL.md
├── README.md                # this file
├── LICENSE                  # MIT
├── .vscode/
│   └── settings.json        # VS Code + LaTeX Workshop config (latexmk recipe)
├── templates/
│   ├── _base/               # shared formatting modules and converter
│   │   ├── huawei-latex-converter.rb  # AsciiDoc-to-LaTeX converter
│   │   ├── huawei.css               # Huawei brand CSS for HTML output (337 lines)
│   │   ├── huawei-badges.sty        # shared badge rendering (\huaweibadge)
│   │   ├── docx_fix.py              # shared DOCX post-processing
│   │   └── embed-images.py          # shared MD image embedding
│   ├── guide/               # self-contained template + skill
│   │   ├── SKILL.md          # opencode skill + AsciiDoc syntax reference
│   │   ├── README.md         # template-specific details (brief)
│   │   ├── guide.cls         # guide-specific formatting (cover, TOC, titles)
│   │   ├── guide-reference.docx  # custom DOCX styles for Pandoc
│   │   ├── guide-template.html   # HTML5 template with Huawei brand CSS
│   │   ├── create-guide-reference-docx.py  # regenerate guide-reference.docx
│   │   ├── .latexmkrc        # latexmk config (XeLaTeX, TZ=America/Sao_Paulo)
│   │   └── common-assets/      # logos, sample images, example scripts
│   ├── technical/             # technical report template + skill
│   │   ├── technical.cls       # LaTeX class (5-section environments, cover page)
│   │   ├── technical-template.html  # HTML template for Pandoc
│   │   ├── create-technical-reference-docx.py  # DOCX reference style generator
│   │   ├── technical-reference.docx  # reference DOCX with Huawei styles
│   │   ├── SKILL.md          # opencode skill + AsciiDoc syntax reference
│   │   ├── README.md         # template-specific details (brief)
│   │   ├── .latexmkrc        # latexmk config (XeLaTeX)
│   │   └── common-assets/    # logos
│   ├── testbook/             # test case template + skill
│   │   ├── testbook.cls       # LaTeX class (testcase environment, cover page)
│   │   ├── testbook-template.html  # HTML template for Pandoc
│   │   ├── create-testbook-reference-docx.py  # DOCX reference style generator
│   │   ├── testbook-reference.docx  # reference DOCX with Huawei styles
│   │   ├── SKILL.md          # opencode skill + AsciiDoc syntax reference
│   │   ├── README.md         # template-specific details (brief)
│   │   ├── .latexmkrc        # latexmk config (XeLaTeX)
│   │   └── common-assets/    # logos
│   ├── poc/                  # POC/homologation template + skill
│   │   ├── poc.cls            # LaTeX class (result badges, stakeholders, signatures)
│   │   ├── poc-template.html   # HTML template for Pandoc
│   │   ├── create-poc-reference-docx.py  # DOCX reference style generator
│   │   ├── poc-reference.docx  # reference DOCX with Huawei styles
│   │   ├── SKILL.md          # opencode skill + AsciiDoc syntax reference
│   │   ├── README.md         # template-specific details (brief)
│   │   ├── .latexmkrc        # latexmk config (XeLaTeX)
│   │   └── common-assets/    # logos
├── documents/               # all documents (samples, setup-guide, user docs)
│   ├── README.md            # folder description and structure
│   ├── gallery/             # screenshots of sample output
│   ├── guide-pt/            # Portuguese guide sample
│   │   ├── src/
│   │   │   ├── main.adoc
│   │   │   └── .latexmkrc
│   │   └── assets/
│   ├── guide-en/            # English guide sample
│   │   ├── src/
│   │   │   ├── main.adoc
│   │   │   └── .latexmkrc
│   │   └── assets/
│   ├── technical-pt/        # Portuguese technical report sample
│   │   ├── src/
│   │   │   ├── main.adoc
│   │   │   └── .latexmkrc
│   │   └── main.pdf
│   ├── technical-en/        # English technical report sample
│   │   ├── src/
│   │   │   ├── main.adoc
│   │   │   └── .latexmkrc
│   │   └── main.pdf
│   ├── testbook-pt/         # Portuguese test cases sample
│   │   ├── src/
│   │   │   ├── main.adoc
│   │   │   └── .latexmkrc
│   │   └── main.pdf
│   ├── testbook-en/         # English test cases sample
│   │   ├── src/
│   │   │   ├── main.adoc
│   │   │   └── .latexmkrc
│   │   └── main.pdf
│   ├── poc-pt/              # Portuguese POC/homologation sample
│   │   ├── src/
│   │   │   ├── main.adoc
│   │   │   └── .latexmkrc
│   │   └── main.pdf
│   ├── poc-en/              # English POC/homologation sample
│   │   ├── src/
│   │   │   ├── main.adoc
│   │   │   └── .latexmkrc
│   │   └── main.pdf
│   ├── setup-guide/         # real-world ECS + SSH + MaaS gateway guide
│   │   ├── src/
│   │   │   ├── setup-guide.adoc
│   │   │   └── .latexmkrc
│   │   └── assets/
│   └── my-guide/            # example: a new user document project
│       ├── src/
│       │   ├── main.adoc
│       │   └── .latexmkrc   # TEXINPUTS → ../../../templates/_base/ + ../../../templates/guide/; $out_dir='..'
│       └── assets/           # project-specific images
└── tests/
    ├── test-filter.sh   # Lua filter unit tests (legacy, skipped)
    ├── round-trip.sh    # cross-format validation (MD + DOCX + HTML)
    ├── test-docx-fix.sh # DOCX --fix post-processing smoke test
    └── test-sync.sh     # version + doc consistency check
```

## Adding a new template

See [`AGENTS.md`](AGENTS.md) for the full guide on creating templates and skills.
Adding a template requires zero changes to the Makefile, `build.sh`, `build-adoc.sh`,
`install.sh`, or test scripts — all auto-discover templates and samples.

## License

MIT — see [LICENSE](LICENSE).

## History

See [`CHANGELOG.md`](CHANGELOG.md) for version history.
