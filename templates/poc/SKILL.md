---
name: huawei-template-poc
description: Create or edit Huawei Cloud Proof of Concept or homologation documents using the AsciiDoc POC template. Use when the user wants to write, extend, or fix a POC, homologation script, or validation document for Huawei Cloud. Triggers on keywords like huawei-template-poc, POC, proof of concept, homologation, homologação, roteiro de homologação, asciidoc poc.
---

# Huawei Cloud POC/Homologation — Skill

Create, edit, and compile Huawei Cloud Proof of Concept (PoC) and
technical homologation documents using the `poc` template. Source format
is AsciiDoc (`.adoc`); PDF is generated via `asciidoctor -b huawei-latex`
→ LaTeX → XeLaTeX.

## When to use

Use this skill when the task is to **write, extend, or fix a Huawei Cloud
PoC or homologation document**. POC documents follow a 3-part, 15-section
structure: **Preamble** (Executive Summary, Background, Goal & Objectives,
Solution Overview), **Scope & Planning** (Scope, Premises, Methodology,
Activities, Schedule, Responsibility Matrix), and **Conclusion** (Expected
Results, Actual Results, Comments, Conclusion, Signatures). The template
provides 7 POC-specific environments: stakeholders table, objective block,
result badges (Pass/Partial/Fail/Skip), activities list (roman numerals),
evidence checklist (checkboxes), closing record, and signatures. Content
defaults to English; set `:lang: pt` for Portuguese labels. Do **not** use
this for general AsciiDoc documents — the formatting is hard-coded to the
Huawei house style (AGENTS.md L9).

## Context loading (do this first)

Before creating or editing any document, read these files to load the full
project context:

1. **`templates/poc/poc.cls`** — the class file. Shared formatting lives in
   `templates/_base/huawei-*.sty` modules. POC-specific formatting (result
   badges, stakeholders, closing record, signatures) lives in `poc.cls`.
2. **`templates/_base/huawei-latex-converter.rb`** — the AsciiDoc-to-LaTeX
   converter. Maps AsciiDoc roles to Huawei LaTeX commands.
3. **`README.md`** (repo root) — project setup, compilation instructions,
   install steps, and project layout.
4. **`AGENTS.md`** (repo root) — locked decisions, file editing rules,
   versioning workflow, and project standards.
5. **`templates/poc/README.md`** — human-readable template overview.

Read all five files before proceeding to the Quick start below. Do not
guess role names, header attributes, or formatting conventions — look them
up in the converter and this SKILL.md.

---

## Core Components (shared across all templates)

These modules are loaded from `templates/_base/` and require no
template-specific configuration:

| Module | Provides |
|--------|----------|
| `huawei-colors.sty` | Huawei brand colors (huaweired, tipbg/fg, warningbg/fg, infobg/fg, codebg, auxiliary palette) |
| `huawei-fonts.sty` | HarmonyOS Sans (body), Cascadia Code (mono) with fallbacks |
| `huawei-lang.sty` | Language support, `\lg@doctitle`, `\lg@docversion` |
| `huawei-page.sty` | A4 page layout, headers, footers |
| `huawei-tables.sty` | `[.hutable]` and `[.longhutable]` roles, `\thd`, `\tbody` |
| `huawei-code.sty` | Code blocks with syntax highlighting |
| `huawei-callouts.sty` | `WARNING:`, `TIP:`, `NOTE:` admonition boxes |
| `huawei-images.sty` | `\image`, `\imagecap`, `\diagramcap`, `\imageplaceholder` |
| `huawei-changelog.sty` | Changelog environment and `\changelogentry` |
| `huawei-titles.sty` | Section numbering, heading style |
| `huawei-toc.sty` | Auto-generated table of contents |
| `huawei-cover.sty` | Cover page (title, version, date, authors) |
| `huawei-shared.sty` | `\inlinecode`, `\badge`, `\menu`, `\note`, `\param` |

Note: `huawei-badges.sty` (`\huaweibadge`) is also in `templates/_base/`
but is currently loaded only by `poc.cls`. It provides the generic badge
rendering used by `\pocresult`.

---

## Template-Specific Features

### Header attributes

| Attribute | Purpose | Example |
|-----------|---------|---------|
| `:template: poc` | Selects the POC class file | Required |
| `:lang: pt` | Portuguese labels (default: English) | Optional |
| `:version: 1.0.0` | Document version on cover page | Required |
| `:date: 2026-09-18` | Override the date on cover page | Optional |
| `:authors: Name` | Author(s) on cover page | Optional |
| `:nochangelog:` | Suppress changelog section | Optional |
| `:noauthors:` | Hide authors even if set | Optional |
| `:notime:` | Hide compilation time on cover | Optional |

### Section structure (15 sections, 3 parts)

| # | Section (EN) | Section (PT) | Part | Specific? |
|---|-------------|-------------|------|-----------|
| 1 | Executive Summary | Resumo Executivo | Preamble | Yes (stakeholders) |
| 2 | Background | Contexto | Preamble | No (text) |
| 3 | Goal and Objectives | Objetivos e Metas | Preamble | Yes (`.objective`) |
| 4 | Solution Overview | Visão da Solução | Preamble | No (text + diagrams) |
| 5 | Scope | Escopo | Planning | No (hutable) |
| 6 | Premises and Preparation | Premissas e Preparação | Planning | No (lists) |
| 7 | Methodology | Metodologia | Planning | Yes (badges, evidence) |
| 8 | Planned Activities | Atividades Planejadas | Planning | Yes (roman numerals) |
| 9 | Schedule | Cronograma | Planning | No (hutable) |
| 10 | Responsibility Matrix | Matriz de Responsabilidades | Planning | No (hutable) |
| 11 | Expected Results | Resultados Esperados | Conclusion | No (hutable) |
| 12 | Actual Results | Resultados Obtidos | Conclusion | Yes (badges) |
| 13 | Comments and Remarks | Comentários e Observações | Conclusion | No (text) |
| 14 | Conclusion | Conclusão | Conclusion | Yes (closing record) |
| 15 | Signatures | Assinaturas | Conclusion | Yes (signature grid) |

Sections are flexible — authors can add, remove, or reorder them. The
template does not enforce section order.

### POC-specific environments

#### 1. Stakeholders table (passthrough)

Contact table grouped by organization. Uses a passthrough block (`++++`).

```asciidoc
++++
\begin{stakeholders}
\stakeholderorg{Organization Name}
\stakeholderrow{Name}{email}{phone}{role}
\stakeholderorg{Another Org}
\stakeholderrow{Name}{email}{phone}{role}
\end{stakeholders}
++++
```

- `\stakeholderorg{name}` — org group header row (Huawei red background)
- `\stakeholderrow{name}{email}{phone}{role}` — contact row

#### 2. Objective block

Highlighted box for the goal statement in Section 3.

```asciidoc
[.objective]
Migrate the application to Huawei Cloud and validate that the
target architecture meets all requirements.
```

#### 3. Result badges (inline)

Colored badges for POC/homologation results. Language-aware labels.

| Role | AsciiDoc | LaTeX | Color | PT label | EN label |
|------|----------|-------|-------|----------|----------|
| Pass | `[.result-pass]#Pass#` | `\pocresult{Pass}` | Green | Atendido | Pass |
| Partial | `[.result-partial]#Partial#` | `\pocresult{Partial}` | Orange | Atendido com ressalvas | Partial |
| Fail | `[.result-fail]#Fail#` | `\pocresult{Fail}` | Red | Não atendido | Fail |
| Skip | `[.result-skip]#Skip#` | `\pocresult{Skip}` | Gray | Não testado | Skip |

#### 4. Activities list (roman numerals)

Ordered list with roman numeral numbering (i, ii, iii, ...).

```asciidoc
[.activities]
. First activity
. Second activity
. Third activity
```

#### 5. Evidence checklist (checkboxes)

Unordered list with checkbox bullets.

```asciidoc
[.evidence]
* Architecture diagram of the deployed environment
* Screenshots of relevant configurations
* Logs and test results
```

#### 6. Closing record (passthrough)

Final classification table with checkboxes.

```asciidoc
++++
\begin{closingrecord}
\closingrow{Preliminary result}{\checkbox{Homologated} \checkbox{With reservations} \checkbox{Not homologated}}
\closingrow{Critical pending items}{None}
\closingrow{Deadline for complementary evidence}{2026-10-15}
\closingrow{Responsible parties}{Jane Doe, John Smith}
\closingrow{Final observations}{PoC successful.}
\end{closingrecord}
++++
```

- `\closingrow{item}{value}` — row in the closing record table
- `\checkbox{label}` — checkbox with label

#### 7. Signatures (passthrough)

Formal sign-off block in a 2x2 grid.

```asciidoc
++++
\begin{signatures}
\signaturecell{Name}{Title}{email}{Address} & \signaturecell{Name}{Title}{email}{Address} \\ \hline
\signaturecell{Name}{Title}{email}{Address} & \signaturecell{Name}{Title}{email}{Address} \\ \hline
\end{signatures}
++++
```

Use `\signaturecell` for each cell, with `&` between columns and `\\ \hline` at the end of each row.

---

## Changelog and Versioning

### Changelog environment

The changelog is rendered using a passthrough block. Entries are listed
newest first. Suppress with `:nochangelog:` header attribute.

```asciidoc
++++
\begin{changelog}
\changelogentry{1.1.0}{2026-09-20}{Added stakeholder table and result badges.}
\changelogentry{1.0.0}{2026-09-18}{Initial version.}
\end{changelog}
++++
```

### Versioning workflow

Every AI-assisted edit must bump the `:version:` header attribute and add
a `\changelogentry` (newest first). Bump levels:

- **patch** — typo/wording fix (e.g., 1.0.0 → 1.0.1)
- **minor** — new content/section (e.g., 1.0.0 → 1.1.0)
- **major** — structural/breaking change (e.g., 1.0.0 → 2.0.0)

Recompile after bumping. The PDF must always reflect the latest version.

---

## Quick start

1. Create a self-contained document folder:
   ```
   documents/my-poc/
   ├── src/
   │   ├── main.adoc
   │   └── .latexmkrc
   └── assets/
   ```

2. Create a `.latexmkrc` in `src/` with the following content:
   ```perl
   $ENV{TEXINPUTS} = "../:../../../templates/_base/:../../../templates/poc/:" . ($ENV{TEXINPUTS} || "");
   $ENV{TZ} = "America/Sao_Paulo";
   $pdf_mode = 5;
   $xelatex = 'xelatex -interaction=nonstopmode %O %S';
   $out_dir = '..';
   $aux_dir = '.';
   ```

3. Write the `.adoc` file using the skeleton below.

4. Compile:
   ```bash
   ./scripts/build-adoc.sh documents/my-poc/src/main.adoc -o documents/my-poc/src/main.tex
   cd documents/my-poc/src && latexmk -xelatex main.tex
   ```

---

## Skeleton

```asciidoc
= Document Title
:template: poc
:lang: en
:version: 1.0.0
:authors: Author Name
:nochangelog:

== Executive Summary

Summary text.

++++
\begin{stakeholders}
\stakeholderorg{Organization}
\stakeholderrow{Name}{email}{phone}{role}
\end{stakeholders}
++++

== Background

Why this PoC exists.

== Goal and Objectives

[.objective]
High-level goal statement.

* Objective 1
* Objective 2

== Solution Overview

Application and architecture description.

== Scope

[.hutable]
|===
| Domain | What Will Be Tested

| Item | Description
|===

== Premises and Preparation

* Prerequisite 1
* Prerequisite 2

== Methodology

=== Result Classification

[.hutable]
|===
| Result | Interpretation

| [.result-pass]#Pass# | Executed and evidenced.
| [.result-partial]#Partial# | Proven with restrictions.
| [.result-fail]#Fail# | Not executed or incompatible.
| [.result-skip]#Skip# | No execution condition.
|===

=== Evidence to Be Collected

[.evidence]
* Evidence item 1
* Evidence item 2

== Planned Activities

[.activities]
. First activity
. Second activity

== Schedule

[.hutable]
|===
| Day | Time | Activity | Responsible

| Day 1 | 09:00-12:00 | Activity | Party
|===

== Responsibility Matrix

[.hutable]
|===
| Party | Responsibilities

| Customer | Validate results.
| Huawei Cloud | Provide support.
|===

== Expected Results

[.hutable]
|===
| Deliverable | Minimum Content

| Report | Description.
|===

== Actual Results

[.activities]
. *First activity.*
+
Description of what was done.
[.result-pass]#Pass#

== Comments and Remarks

Observations and caveats.

== Conclusion

++++
\begin{closingrecord}
\closingrow{Preliminary result}{\checkbox{Homologated} \checkbox{With reservations} \checkbox{Not homologated}}
\closingrow{Critical pending items}{None}
\closingrow{Deadline for complementary evidence}{}
\closingrow{Responsible parties}{}
\closingrow{Final observations}{}
\end{closingrecord}
++++

== Signatures

++++
\begin{signatures}
\signaturecell{Name}{Title}{email}{Address} & \signaturecell{Name}{Title}{email}{Address} \\ \hline
\end{signatures}
++++
```

---

## Hard requirements

- **Engine:** XeLaTeX only (the class loads `fontspec`). Never use pdflatex.
- **Source format:** AsciiDoc (`.adoc`). LaTeX is generated — never hand-edit `.tex`.
- **Fonts:** HarmonyOS Sans (body), Cascadia Code (mono). Install via
  `scripts/install.sh`.
- **Compilation:** `asciidoctor -b huawei-latex` → `.tex` → `latexmk` → PDF.

## Project folder convention

Every document lives in its own folder under `documents/`. Source files
(`.adoc`, `.latexmkrc`) go in `src/`; generated outputs go in the document
root. Each document is self-contained.

## Timezone note

The `.latexmkrc` sets `TZ = "America/Sao_Paulo"` (GMT-3) by default.
Override in your project's `.latexmkrc` for other regions (last one wins).
