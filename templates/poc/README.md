# Huawei Cloud POC/Homologation — AsciiDoc Document Template

Produces a Huawei Cloud Proof of Concept or technical homologation PDF from
AsciiDoc source. The pipeline is AsciiDoc → LaTeX (via
`huawei-latex-converter.rb`) → PDF (XeLaTeX). HTML, DOCX, and Markdown are
generated from the same `.adoc` source.

POC documents follow a 3-part, 15-section structure: Preamble (Executive
Summary, Background, Goal & Objectives, Solution Overview), Scope & Planning
(Scope, Premises, Methodology, Activities, Schedule, Responsibility Matrix),
and Conclusion (Expected Results, Actual Results, Comments, Conclusion,
Signatures). Seven POC-specific environments are provided: stakeholders
table, objective block, result badges, activities list, evidence checklist,
closing record, and signatures.

> **Setup:** see the [root README](../../README.md) for installation,
> environment setup, and compilation instructions.
> See [SKILL.md](SKILL.md) for the full AsciiDoc syntax reference.

## Quick start

Create a file `src/main.adoc`:

```adoc
= Proof of Concept
:template: poc
:lang: en
:version: 1.0.0
:authors: Jane Doe

== Executive Summary

Summary text.

++++
\begin{stakeholders}
\stakeholderorg{Customer}
\stakeholderrow{Name}{email}{phone}{role}
\end{stakeholders}
++++

== Goal and Objectives

[.objective]
Validate Huawei Cloud services for the target workload.

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
```

Compile from the repo root:

```bash
make poc-en
```

Or manually:

```bash
scripts/build-adoc.sh src/main.adoc -o src/main.tex && latexmk src/main.tex
```

## Header attributes

| Attribute | Effect |
|---|---|
| `:lang: pt` | Switches all predefined labels to Portuguese. Default is English. |
| `:version: X.Y.Z` | Sets the document version on the cover page. |
| `:authors: Name` | Sets the author(s) on the cover page. |
| `:notime:` | Hides the compilation time on the cover page. |
| `:nochangelog:` | Suppresses the changelog and hides version/date/time on cover. |
| `:noauthors:` | Hides authors even if set. |

### Label translations

| Token | English (default) | Portuguese (`:lang: pt`) |
|---|---|---|
| Pass | Pass | Atendido |
| Partial | Partial | Atendido com ressalvas |
| Fail | Fail | Não atendido |
| Skip | Skip | Não testado |
| Signature greeting | Sincerely, | At.te, |
| Closing item | Item | Item |
| Closing record | Record | Registro |

## Samples

Two samples demonstrate all 15 sections and all POC-specific environments:

- [`examples/poc/pt/src/main.adoc`](../../examples/poc/pt/src/main.adoc) — Portuguese
- [`examples/poc/en/src/main.adoc`](../../examples/poc/en/src/main.adoc) — English

Compile with `make poc-pt` / `make poc-en` from the repo root.
