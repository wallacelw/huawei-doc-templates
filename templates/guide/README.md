# Huawei Cloud Guide — LaTeX Template

A LaTeX template that produces a Huawei Cloud guide PDF: cover page, header,
table of contents, giant chapter numbers, objectives box, code blocks, tables,
callout boxes, badges, colors, spacing, and fonts.

> **Setup:** see the [root README](../../README.md) for installation,
> environment setup, VS Code configuration, and compilation instructions.
> See [SKILL.md](SKILL.md) for the full command and environment reference.

## Language

By default the guide renders in **English** — built-in labels such as
*Contents*, *General Objective:*, *Objective:*, *Prerequisites:* and
*Step by step:* are in English. Pass the **`portuguese`** class option
(`\documentclass[portuguese]{guide}`) to switch all labels to Portuguese and
load `babel` with `brazilian` instead.

## Class options

```latex
\documentclass[portuguese,indentbody,notime,nochangelog]{guide}
```

| Option | Effect |
|---|---|
| `portuguese` | Switches all predefined labels to Portuguese; loads `babel` with `brazilian`. Default off (English). |
| `indentbody` | Indents all running text by `\contentindent` (0.6 cm). Default off (text flush to the left margin). |
| `notime` | Hides the compilation time (HH:MM) on the cover page. Default off (time is shown). |
| `nochangelog` | Suppresses the changelog section entirely (no-ops) and hides version, date, and time on the cover page. Use when it grows too large. Default off (changelog is shown). |

### Label translations

| Token | English (default) | Portuguese (`[portuguese]`) |
|---|---|---|
| TOC title | Contents | Sumário |
| Cover title default | Guide | Guia |
| `\generalobjective` label | General Objective: | Objetivo Geral: |
| `\objective` label | Objective: | Objetivo: |
| `\prerequisites` label | Prerequisites: | Pré-requisitos: |
| `\stepbystep` label | Step by step: | Passo a passo: |
| Footer page label | Page | Página |

## Document structure

The body order is fixed: `\makecover` → `\maketoc` → `\startbody` → sections
→ `changelog` → `\end{document}`.

See [SKILL.md](SKILL.md) for the complete skeleton and all available commands
and environments.

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
| Warning box | `#FDF8EE` bg / `#D4A72C` border (muted gold) |
| Tip box | `#EDF6ED` bg / `#5BA85B` border (muted sage) |
| Info box | `#EDF3F9` bg / `#4A8BB5` border (muted slate) |

Colors are defined in `templates/_base/huawei-colors.sty` and fonts in
`templates/_base/huawei-fonts.sty`. Both are reusable via `\textcolor{name}{...}`
and `\codefont` respectively.

## Customization

- **Logos:** replace files in `common-assets/` keeping the names, or use
  `\setheaderlogo{path}` / `\setcoverlogo{path}` in the preamble.
- **Colors:** edit the `\definecolor` block in `templates/_base/huawei-colors.sty`.
- **Fonts:** edit font setup in `templates/_base/huawei-fonts.sty`.
- **Sizes/spacing:** each concern is in a commented section of `guide.cls`
  (`TITLES`, `CODE`, `HEADER AND FOOTER`, etc.) — find the section and edit there.

## Samples

Two samples demonstrate all commands and environments:

- [`examples/guide/pt/main.tex`](../../examples/guide/pt/main.tex) — Portuguese
- [`examples/guide/en/main.tex`](../../examples/guide/en/main.tex) — English

Compile with `make pt` / `make en` from the repo root, or `latexmk main.tex`
from either folder.
