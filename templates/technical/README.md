# Huawei Cloud Technical Report Template

LaTeX class (`technical.cls`) for generating Huawei-branded technical
reports with a fixed 6-section structure (problem → root cause → trigger
→ workaround). Output is PDF via XeLaTeX; DOCX, Markdown, and HTML via
Pandoc.

## Setup

See the [root README](../../README.md) for environment setup and
`install.sh` for one-command installation.

## Usage

See [SKILL.md](SKILL.md) for the full command reference, document
skeleton, and workflow checklist.

Quick example:

```latex
\documentclass{technical}
\setreporttitle{[Analysis Report] Issue title}
\setreportversion{HCS 8.5.1}
\setreportdate{2025-08-13}
\setreportscenario{Standard Scenario}
\setheadertitle{Huawei Cloud -- Technical Report}

\begin{document}
\makecover \maketoc \startbody

\begin{problem}
Describe the problem here.
\end{problem}

% ... other sections ...

\end{document}
```

Compile with `latexmk main.tex` (XeLaTeX).
