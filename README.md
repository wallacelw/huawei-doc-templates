# Huawei Document Templates

A collection of LaTeX templates for Huawei Cloud documents. Each template
lives under `templates/<name>/` and is self-contained: class file, samples,
skill, assets, and build config. Documents compile to PDF via XeLaTeX.

**See what the output looks like:** [`examples/gallery/`](examples/gallery/) —
screenshots of the cover page, content pages, code blocks, tables, callouts,
and changelog.

## Quick start

**One-liner (clone + install):**

```bash
curl -fsSL https://raw.githubusercontent.com/wallacelw/huawei-doc-templates/main/install.sh | bash
```

**Or step by step:**

```bash
git clone https://github.com/wallacelw/huawei-doc-templates.git
cd huawei-doc-templates
./install.sh
```

Then open the project in [opencode](https://opencode.ai) and run:

```
/skill huawei-template-guide
```

to create a new guide document.

## Requirements

- **OS:** Ubuntu 22.04+ (WSL or native)
- That's it — `install.sh` handles everything else.

`install.sh` installs:

- XeLaTeX + latexmk + LaTeX packages (`texlive-xetex`, `texlive-latex-extra`,
  `texlive-lang-portuguese`)
- fvextra ≥ 1.5 (updated from CTAN if the system version is too old)
- HarmonyOS Sans font (body text — from GitHub releases, SHA-256 verified)
- Cascadia Code font (code — via `fonts-cascadia-code`)
- opencode skills (copies each `templates/*/SKILL.md` to `~/.config/opencode/skills/`)
- VS Code LaTeX Workshop extension + settings (local and remote)

> `pdflatex` won't work — the templates use `fontspec` (system fonts), which
> requires XeLaTeX. `install.sh` installs and configures XeLaTeX automatically.

## Building documents

## Compilation

### Using the Makefile (recommended)

```bash
make                 # show help (list all available targets)
make all             # compile everything: samples + setup-guide + technical reports + all formats
make samples         # compile PT + EN samples
make examples        # compile setup-guide, copy PDF to repo root
make pt              # compile Portuguese sample only
make en              # compile English sample only
make technical-samples # compile technical report samples (PT + EN, PDF)
make technical DIR=documents/my-report  # compile a technical report (latexmk in src/)
make setup-guide     # compile setup guide only
make project DIR=examples/my-guide   # compile a specific project (auto-detects .tex)
make menu            # interactive format selection (PDF/DOCX/MD/HTML)
make all-formats     # generate DOCX + MD + HTML for all samples + technical
make clean           # remove all build artifacts
make clean-formats   # remove generated multi-format files
```

Bare `make` prints a self-documenting help summary (the Makefile is
self-documenting via `## ` annotations on each target). `make --help` is
reserved by GNU make and prints make's own usage; use `make` or `make help`
for the project target list.

### Using latexmk directly

```bash
cd examples/guide/pt/src && latexmk main.tex   # Portuguese sample
cd examples/guide/en/src && latexmk main.tex   # English sample
cd examples/setup-guide/src && latexmk setup-guide.tex   # setup guide
```

### Interactive build menu

Use `build.sh` to interactively select which output formats to generate:

```bash
./build.sh examples/guide/en    # interactive menu for the EN sample
./build.sh --all examples/guide/en   # non-interactive: all formats
./build.sh --pdf --docx examples/guide/pt   # non-interactive: PDF + DOCX only
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

Pass the `[notime]` class option to hide the time on the cover page.

## Multi-format output (DOCX, Markdown, HTML)

LaTeX is the source of truth. DOCX, Markdown, and HTML are generated via
[Pandoc](https://pandoc.org/) + a Lua filter that translates all custom
commands to Pandoc AST elements.

### Requirements

- `pandoc >= 3.0` (install via `install.sh` or your package manager)

### Usage

```bash
make all-formats    # MD + DOCX + HTML for all samples + technical reports
make md             # Markdown only (pt + en)
make docx           # DOCX only (pt + en)
make html           # HTML only (pt + en)
make clean-formats  # remove generated multi-format files
```

The Lua filter (`templates/guide/guide-pandoc.lua`) handles all custom commands (see [`SKILL.md`](templates/guide/SKILL.md) for the full reference). DOCX uses custom styles from `guide-reference.docx` (theme fonts: HarmonyOS Sans); HTML uses `guide-template.html` with Huawei brand CSS.

Generated outputs are gitignored (build artifacts). Only the filter, reference
DOCX, HTML template, and Python script are committed.

## VS Code (optional)

The repo ships `.vscode/settings.json` pre-configured for **latexmk (XeLaTeX)**.
Install the [LaTeX Workshop](https://marketplace.visualstudio.com/items?itemName=James-Yu.latex-workshop)
extension, open the repo root, and save any `.tex` file to auto-compile.

## Templates

| Template | Skill | Description |
|---|---|---|
| [`guide`](templates/guide/) | `/skill huawei-template-guide` | Huawei Cloud guide — branded cover, header, TOC, giant chapter numbers, objectives block, code blocks, tables, callout boxes, badges, changelog. English (default) and Portuguese. |
| [`technical`](templates/technical/) | `/skill huawei-template-technical` | Huawei Cloud technical report — 6-section structure (problem → root cause → trigger → workaround), branded cover with version info table, TOC, callout boxes, tables, code blocks. PDF via XeLaTeX; DOCX/MD/HTML via Pandoc. Portuguese and English. |

See [`templates/guide/SKILL.md`](templates/guide/SKILL.md) for the full command
and environment reference. See [`templates/technical/SKILL.md`](templates/technical/SKILL.md)
for the technical report template command reference.

## Project layout

```
.
├── AGENTS.md               # project standards and locked decisions
├── CHANGELOG.md            # version history
├── install.sh               # one-command setup (clone + install + verify)
├── Makefile                 # build convenience (make samples/examples/clean)
├── build.sh                # interactive format selection menu
├── opencode.json            # skill discovery: scans templates/ for SKILL.md
├── README.md                # this file
├── LICENSE                  # MIT
├── .luacheckrc             # Lua static analysis config
├── .vscode/
│   └── settings.json        # VS Code + LaTeX Workshop config (latexmk recipe)
├── templates/
│   ├── _base/               # shared formatting modules (huawei-*.sty)
│   ├── guide/               # self-contained template + skill
│   │   ├── SKILL.md          # opencode skill + agent command reference
│   │   ├── README.md         # template-specific details (brief)
│   │   ├── guide.cls         # guide-specific formatting (cover, TOC, titles)
│   │   ├── guide-pandoc.lua  # Pandoc Lua filter (DOCX/MD/HTML output)
│   │   ├── guide-reference.docx  # custom DOCX styles for Pandoc
│   │   ├── guide-template.html   # HTML5 template with Huawei brand CSS
│   │   ├── create-reference-docx.py  # regenerate guide-reference.docx
│   │   ├── .latexmkrc        # latexmk config (XeLaTeX, TZ=America/Sao_Paulo)
│   │   └── common-assets/      # logos, sample images, example scripts
│   └── technical/             # technical report template + skill (LaTeX/PDF)
│       ├── technical.cls       # LaTeX class (6-section environments, cover page)
│       ├── technical-pandoc.lua  # Pandoc Lua filter (DOCX/MD/HTML output)
│       ├── technical-template.html  # HTML template for Pandoc
│       ├── create-technical-reference-docx.py  # DOCX reference style generator
│       ├── technical-reference.docx  # reference DOCX with Huawei styles
│       ├── SKILL.md          # opencode skill + command reference
│       ├── README.md         # template-specific details (brief)
│       ├── .latexmkrc        # latexmk config (XeLaTeX)
│       └── common-assets/    # logos
├── documents/               # user-created documents (one subfolder per doc)
│   ├── README.md            # folder description and structure
│   └── my-guide/            # example: a new document project
│       ├── src/
│       │   ├── main.tex
│       │   └── .latexmkrc   # TEXINPUTS → ../../templates/_base/ + ../../templates/guide/; $out_dir='..'
│       └── assets/           # project-specific images
├── tests/
│   ├── cases/           # Lua filter test cases
│   ├── expected/        # expected filter output (.md.expected)
│   ├── test-filter.sh   # Lua filter unit tests
│   ├── round-trip.sh    # cross-format validation (MD + DOCX + HTML)
│   ├── test-docx-fix.sh # DOCX --fix post-processing smoke test
│   └── test-sync.sh     # version + doc consistency check
└── examples/                 # all examples, samples, and output screenshots
    ├── gallery/             # screenshots of sample output
    ├── guide/               # samples for the guide template
    │   ├── pt/               # Portuguese sample
    │   │   ├── src/
    │   │   │   ├── main.tex
    │   │   │   └── .latexmkrc
    │   │   └── assets/       # project-specific images
    │   └── en/               # English sample
    │       ├── src/
    │       │   ├── main.tex
    │       │   └── .latexmkrc
    │       └── assets/       # project-specific images
    ├── technical/            # samples for the technical report template
    │   ├── pt/               # Portuguese technical report
    │   │   ├── src/
    │   │   │   ├── main.tex
    │   │   │   └── .latexmkrc
    │   │   └── main.pdf
    │   └── en/               # English technical report
    │       ├── src/
    │       │   ├── main.tex
    │       │   └── .latexmkrc
    │       └── main.pdf
    └── setup-guide/          # real-world ECS + SSH + MaaS gateway guide
        ├── src/
        │   ├── setup-guide.tex
        │   └── .latexmkrc
        └── assets/
```

## Adding a new template

See [`AGENTS.md`](AGENTS.md) for the full guide on creating templates and skills.

## License

MIT — see [LICENSE](LICENSE).

## History

See [`CHANGELOG.md`](CHANGELOG.md) for version history.
