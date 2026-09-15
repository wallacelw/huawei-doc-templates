# Huawei Cloud Technical Report — AsciiDoc Document Template

Produces a Huawei Cloud technical report PDF from AsciiDoc source. The
pipeline is AsciiDoc → LaTeX (via `huawei-latex-converter.rb`) → PDF
(XeLaTeX). HTML, DOCX, and Markdown are generated from the same `.adoc`
source.

Reports follow a fixed 5-section structure: problem → root cause analysis
→ root cause → trigger condition → workaround. Each section uses an
AsciiDoc role: `[.problem]`, `[.rootcauseanalysis]`, `[.rootcause]`,
`[.triggercondition]`, `[.workaround]`.

> **Setup:** see the [root README](../../README.md) for installation,
> environment setup, and compilation instructions.
> See [SKILL.md](SKILL.md) for the full AsciiDoc syntax reference.

## Quick start

Create a file `src/main.adoc`:

```adoc
:template: technical
:lang: en
:version: 1.0.0

= [Analysis Report] Issue title

[.problem]
Describe the problem here.

[.rootcauseanalysis]
Analysis details here.
```

Compile from the repo root:

```bash
make technical-en
```

Or manually:

```bash
scripts/build-adoc.sh src/main.adoc src/main.tex && latexmk src/main.tex
```

## Header attributes

| Attribute | Effect |
|---|---|
| `:lang: pt` | Switches all predefined labels to Portuguese. Default is English. |
| `:notime:` | Hides the compilation time on the cover page. |
| `:nochangelog:` | Suppresses the changelog section and hides version, date, and time on the cover page. |
| `:noauthors:` | Hides the authors on the cover page. |

## Samples

Two samples demonstrate all roles and passthrough blocks:

- [`examples/technical/pt/src/main.adoc`](../../examples/technical/pt/src/main.adoc) — Portuguese
- [`examples/technical/en/src/main.adoc`](../../examples/technical/en/src/main.adoc) — English

Compile with `make technical-pt` / `make technical-en` from the repo root.
