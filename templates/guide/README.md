# Huawei Cloud Guide — AsciiDoc Document Template

Produces a Huawei Cloud guide PDF from AsciiDoc source. The pipeline is
AsciiDoc → LaTeX (via `huawei-latex-converter.rb`) → PDF (XeLaTeX).
HTML, DOCX, and Markdown are generated from the same `.adoc` source.

> **Setup:** see the [root README](../../README.md) for installation,
> environment setup, and compilation instructions.
> See [SKILL.md](SKILL.md) for the full AsciiDoc syntax reference.

## Quick start

Create a file `src/main.adoc`:

```adoc
:template: guide
:lang: en
:version: 1.0.0

= My Guide Title

.Body content goes here.
```

Compile from the repo root:

```bash
make guide-en
```

Or manually:

```bash
scripts/build-adoc.sh src/main.adoc -o src/main.tex && latexmk src/main.tex
```

## Header attributes

AsciiDoc header attributes replace LaTeX class options:

| Attribute | Effect |
|---|---|
| `:lang: pt` | Switches all predefined labels to Portuguese; loads `babel` with `brazilian`. Default is English. |
| `:indentbody:` | Indents all running text by 0.6 cm. Default off (text flush to the left margin). |
| `:notime:` | Hides the compilation time (HH:MM) on the cover page. Default off (time is shown). |
| `:nochangelog:` | Suppresses the changelog section and hides version, date, and time on the cover page. Default off (changelog is shown). |
| `:noauthors:` | Hides the authors on the cover page. Default off (authors shown if set). |

### Label translations

| Token | English (default) | Portuguese (`:lang: pt`) |
|---|---|---|
| TOC title | Contents | Sumário |
| Cover title default | Guide | Guia |
| General objective label | General Objective: | Objetivo Geral: |
| Objective label | Objective: | Objetivo: |
| Prerequisites label | Prerequisites: | Pré-requisitos: |
| Step-by-step label | Step by step: | Passo a passo: |
| Footer page label | Page | Página |

## Format reference

| Element | Value |
|---|---|
| Page | A4 |
| Margins | top/bottom 3 cm · left/right 2 cm |
| Body font | HarmonyOS Sans, 10.5 pt |
| Code font | Cascadia Code, 10 pt |
| Body leading | ~14 pt |
| Space between paragraphs | 4 pt |
| H1 title | 20 pt bold right-aligned + 56 pt number left-aligned + 1.5 pt rule |
| H2 / H3 / H4 titles | 18 / 16 / 14 pt, regular |
| Code background | `#F6F8FA` |
| Code text color | `#1F2328` |
| Link color | `#0000FF` (no underline) |
| Brand red | `#C7000B` (`huaweired` — H1 chapter rules, accents, badge) |
| Warning box | `#FFF3E0` bg / `#ED6D00` border |
| Tip box | `#E8F5E9` bg / `#62B230` border |
| Info box | `#E0F7FA` bg / `#30B5C5` border |

Colors are defined in `templates/_base/huawei-colors.sty` and fonts in
`templates/_base/huawei-fonts.sty`.

## Samples

Two samples demonstrate all roles and passthrough blocks:

- [`documents/guide-pt/src/main.adoc`](../../documents/guide-pt/src/main.adoc) — Portuguese
- [`documents/guide-en/src/main.adoc`](../../documents/guide-en/src/main.adoc) — English

Compile with `make guide-pt` / `make guide-en` from the repo root.
