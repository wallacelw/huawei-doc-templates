# Huawei Cloud Test Book — AsciiDoc Document Template

Produces a Huawei Cloud POC/acceptance test case PDF from AsciiDoc source.
The pipeline is AsciiDoc → LaTeX (via `huawei-latex-converter.rb`) → PDF
(XeLaTeX). HTML, DOCX, and Markdown are generated from the same `.adoc`
source.

Test cases use passthrough blocks (`++++\n\begin{testcase}...\end{testcase}\n++++`)
because they have complex internal structure not representable in plain
AsciiDoc. The `testsummary` environment also uses a passthrough block.

> **Setup:** see the [root README](../../README.md) for installation,
> environment setup, and compilation instructions.
> See [SKILL.md](SKILL.md) for the full AsciiDoc syntax reference.

## Quick start

Create a file `src/main.adoc`:

```adoc
:template: testbook
:lang: en
:version: 1.0.0

= POC Test Cases: ECS Provisioning

== Introduction

[.objectives]
--
General Objective: Verify ECS instance provisioning.

Prerequisites:

* Huawei Cloud account with IAM admin privileges.
* VPC and subnet already created.
--

== Test Cases

=== ECS Instance Management

++++
\begin{testcase}{Create ECS instance}
  \testobjective{Verify that an ECS instance can be created.}
  \begin{testprerequisites}
    \teststep{Account is active.}
    \teststep{VPC exists.}
  \end{testprerequisites}
  \begin{testprocedure}
    \teststep{Navigate to ECS}
    \teststep{Click Create}
    \teststep{Fill parameters and click OK}
  \end{testprocedure}
  \begin{testexpected}
    \teststep{Instance is created.}
    \teststep{Status is Running.}
  \end{testexpected}
  \testresult{\testresultbadge{Pass}}
  \testremarks{Test with basic and general-purpose specs.}
\end{testcase}
++++

== Conclusion

++++
\begin{testsummary}
  \testsummaryrow{1}{Create ECS instance}{\testresultbadge{Pass}}
\end{testsummary}
++++
```

Compile from the repo root:

```bash
make testbook-en
```

Or manually:

```bash
scripts/build-adoc.sh src/main.adoc -o src/main.tex && latexmk src/main.tex
```

## Header attributes

| Attribute | Effect |
|---|---|
| `:lang: pt` | Switches all predefined labels to Portuguese; loads `babel` with `brazilian`. Default is English. |
| `:indentbody:` | Indents all running text by 0.6 cm. Default off (text flush to the left margin). |
| `:notime:` | Hides the compilation time (HH:MM) on the cover page. Default off (time is shown). |
| `:nochangelog:` | Suppresses the changelog section and hides version, date, and time on the cover page. Default off (changelog is shown). |
| `:noauthors:` | Hides the authors on the cover page. Default off (authors shown if set). |
| `:noanswers:` | Hides the **Test Result** and **Remarks** fields in all test cases. Use to produce a blank test book for testers to fill in by hand. Default off (all fields shown). |

### Label translations

| Token | English (default) | Portuguese (`:lang: pt`) |
|---|---|---|
| TOC title | Contents | Sumário |
| Cover title default | Test Book | Test Book |
| Test objective label | Objective | Objetivo |
| Test prerequisites label | Prerequisites | Pré-requisitos |
| Test procedure label | Procedure | Procedimento |
| Expected result label | Expected Result | Resultado Esperado |
| Remarks label | Remarks | Observações |
| Test result label | Test Result | Resultado do Teste |
| Test result badge: Pass | Pass | Aprovado |
| Test result badge: Fail | Fail | Reprovado |
| Test result badge: Blocked | Blocked | Bloqueado |
| Test result badge: Untested | Untested | Não testado |
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
| Test case fields | Stacked blocks: full-width red mini header bar (Huawei-red bg, white bold text) + content below, in breakable tcolorbox with 3pt red left-rule |
| Code background | `#F6F8FA` |
| Code text color | `#1F2328` |
| Link color | `#0000FF` (no underline) |
| Brand red | `#C7000B` (`huaweired` — H1 chapter rules, test case left-rule and labels, accents, badge) |
| Warning box | `#FFF3E0` bg / `#ED6D00` border |
| Tip box | `#E8F5E9` bg / `#62B230` border |
| Info box | `#E0F7FA` bg / `#30B5C5` border |

Colors are defined in `templates/_base/huawei-colors.sty` and fonts in
`templates/_base/huawei-fonts.sty`.

## Samples

Two samples demonstrate all roles and passthrough blocks:

- [`documents/testbook-pt/src/main.adoc`](../../documents/testbook-pt/src/main.adoc) — Portuguese
- [`documents/testbook-en/src/main.adoc`](../../documents/testbook-en/src/main.adoc) — English

Compile with `make testbook-pt` / `make testbook-en` from the repo root.
