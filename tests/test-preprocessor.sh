#!/usr/bin/env bash
# test-preprocessor.sh — Unit tests for adoc_docx_preprocessor.py
# Exercises process_adoc() directly (no asciidoctor/pandoc in the loop):
# pipe escaping, badge contract, changelog bullets, :noanswers:,
# signatures edge cases, target-aware testcase markers, and
# [.codefile] inlining (path resolution, fence guard, graceful degrade).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$REPO_ROOT" << 'PYEOF'
import contextlib
import importlib.util
import io
import os
import sys
import tempfile

repo_root = sys.argv[1]
mod_path = repo_root + "/templates/_base/adoc_docx_preprocessor.py"
spec = importlib.util.spec_from_file_location(
    "adoc_docx_preprocessor", mod_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

PASS = 0
FAIL = 0


def check(name, cond):
    global PASS, FAIL
    if cond:
        print(f"  PASS: {name}")
        PASS += 1
    else:
        print(f"  FAIL: {name}")
        FAIL += 1


def process(content, template, target, base_dir=None):
    return mod.process_adoc(content, template, target, base_dir)


# Common header for synthetic documents
HEADER = ":lang: en\n:version: 1.0.0\n\n"


def changelog(entry):
    return "++++\n\\begin{changelog}\n" + entry + "\n\\end{changelog}\n++++\n"


print("=== Pipe escaping ===")

# 1. Pipe in changelog item is escaped for the AsciiDoc table cell
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item Use (Step | Action) pairs.}"), 'guide', 'md')
check("pipe escape: cell content escaped", "(Step \\| Action)" in out)
check("pipe escape: a| cell row", "| 1.0.0 | 2026-01-01 a|" in out)
check("pipe escape: bullet line", "* Use (Step \\| Action) pairs." in out)

# 2. Already-escaped pipe is not escaped twice
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item already escaped \\| pipe}"), 'guide', 'md')
check("no double-escape: \\| kept", "escaped \\| pipe" in out)
check("no double-escape: no \\\\|", "\\\\|" not in out)

# Pipe escaping in the other table handlers (stakeholders, closing
# record, signatures, test summary) — every cell goes through _esc_cell
out = process(HEADER + "++++\n\\begin{stakeholders}\n"
              "\\stakeholderorg{Alpha | Beta}\n"
              "\\end{stakeholders}\n++++\n", 'poc', 'md')
check("pipe escape: stakeholders org cell", "Alpha \\| Beta" in out)

out = process(HEADER + "++++\n\\begin{closingrecord}\n"
              "\\closingrow{Item | X}{Value}\n"
              "\\end{closingrecord}\n++++\n", 'poc', 'md')
check("pipe escape: closing record label cell", "Item \\| X" in out)

out = process(HEADER + "++++\n\\begin{signatures}\n"
              "\\signaturecell{Alice | Bob}{Dev}{a@x}{City}\n"
              "\\end{signatures}\n++++\n", 'poc', 'md')
check("pipe escape: signatures name cell", "Alice \\| Bob" in out)

out = process(HEADER + "++++\n\\begin{testsummary}\n"
              "\\testsummaryrow{TC-01}{Title | Sub}"
              "{\\testresultbadge{Pass}}\n"
              "\\end{testsummary}\n++++\n", 'testbook', 'md')
check("pipe escape: test summary title cell", "Title \\| Sub" in out)
check("pipe escape: test summary badge", "**[Pass]**" in out)

print("=== Badge contract ===")

# 3. [.badge]#text# — docx target emits the docx_fix sentinel
out = process(HEADER + "[.badge]#Ready#\n", 'guide', 'docx')
check("badge docx: sentinel with text", "**[BADGE:Ready]**" in out)

# 4. [.badge]#text# — md target keeps the text, no sentinel
out = process(HEADER + "[.badge]#Ready#\n", 'guide', 'md')
check("badge md: text preserved", "**[Ready]**" in out)
check("badge md: no sentinel", "BADGE:" not in out)

# 5. Result roles map to title-case markers (regression)
out = process(HEADER + "[.result-pass]#Pass#\n", 'testbook', 'docx')
check("result-pass role: **[Pass]**", "**[Pass]**" in out)

print("=== Changelog bullets ===")

# 6. Multi-item entries render as bullets, not a ' + ' join
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item First change. \\item Second change.}"), 'guide', 'md')
check("changelog bullets: a| cell", "a|" in out)
check("changelog bullets: two bullet lines",
      "* First change." in out and "* Second change." in out)
check("changelog bullets: no ' + ' join", "' + '" not in out)

print("=== POC changelog ===")

# 7. POC template converts the changelog passthrough
POC_CL = HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}{\\item POC change.}")
out = process(POC_CL, 'poc', 'md')
check("poc changelog: table present", "| Version | Date | Changes" in out)

# 8. :nochangelog: suppresses it
out = process(":lang: en\n:version: 1.0.0\n:nochangelog:\n\n"
              + changelog("  \\changelogentry{1.0.0}{2026-01-01}"
                          "{\\item POC change.}"), 'poc', 'md')
check("poc changelog: suppressed by :nochangelog:",
      "| Version | Date | Changes" not in out)

print("=== :noanswers: ===")

# 9. Test Result and Remarks hidden with :noanswers: (PDF parity)
TC = ("++++\n\\begin{testcase}{Demo}\n"
      "  \\testresult{Pass}\n"
      "  \\testremarks{Works}\n"
      "\\end{testcase}\n++++\n")
out = process(HEADER + TC, 'testbook', 'docx')
check("noanswers off: Test Result shown", "Test Result" in out)
check("noanswers off: Remarks shown", "Remarks" in out)
out = process(":lang: en\n:version: 1.0.0\n:noanswers:\n\n" + TC,
              'testbook', 'docx')
check("noanswers on: Test Result hidden", "Test Result" not in out)
check("noanswers on: Remarks hidden", "Remarks" not in out)

print("=== Inline LaTeX conversions ===")

# 10. \texttt{text} → `text`
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item Run \\texttt{make} now}"), 'guide', 'md')
check("texttt: `make`", "`make`" in out)

# 11. $\to$ → →
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item a $\\to$ b}"), 'guide', 'md')
check("to arrow: a → b", "a \u2192 b" in out)

# 12. LaTeX quotes → Unicode curly quotes
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item Use ``make'' today}"), 'guide', 'md')
check("latex quotes: “make”", "\u201cmake\u201d" in out)

# Paired-quote conversion must not corrupt '' inside code args
# (SQL empty string stays literal)
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item Use \\inlinecode{WHERE x = ''} now}"), 'guide', 'md')
check("quotes: '' literal inside code arg", "`WHERE x = ''`" in out)

print("=== Signatures ===")

# 13. Single-cell row: no IndexError, empty second cell keeps the grid
SIG1 = ("++++\n\\begin{signatures}\n"
        "\\signaturecell{Alice}{Dev}{a@x}{City}\n"
        "\\end{signatures}\n++++\n")
sig_out = None
try:
    sig_out = process(HEADER + SIG1, 'poc', 'md')
    ok = True
except Exception:
    ok = False
check("signatures 1-cell row: no exception", ok)
check("signatures 1-cell row: Alice present",
      sig_out is not None and "Alice" in sig_out)
check("signatures 1-cell row: empty second cell",
      sig_out is not None
      and any(line == "|" for line in sig_out.split("\n")))

# 2-cell row: both signatures present
SIG2 = ("++++\n\\begin{signatures}\n"
        "\\signaturecell{Alice}{Dev}{a@x}{City} & "
        "\\signaturecell{Bob}{Lead}{b@x}{Town}\n"
        "\\end{signatures}\n++++\n")
out = process(HEADER + SIG2, 'poc', 'md')
check("signatures 2-cell row: both present",
      "Alice" in out and "Bob" in out)

# Escaped ampersand in a cell must not split the cell (\& is literal)
out = process(HEADER + "++++\n\\begin{signatures}\n"
              "\\signaturecell{Alice}{R\\&D Lead}{a@x}{City}\n"
              "\\end{signatures}\n++++\n", 'poc', 'md')
check("signatures: \\& not a cell separator", "R&D Lead" in out)

print("=== Target-aware testcase markers ===")

# 14. TESTCASE-START/END only for the docx target
TC2 = ("++++\n\\begin{testcase}{Demo}\n"
       "  \\testobjective{Check.}\n"
       "\\end{testcase}\n++++\n")
out = process(HEADER + TC2, 'testbook', 'docx')
check("testcase markers: docx emits TESTCASE-START", "TESTCASE-START" in out)
out = process(HEADER + TC2, 'testbook', 'md')
check("testcase markers: md skips TESTCASE-START", "TESTCASE-START" not in out)

print("=== \\badge command ===")

# 15. \badge{text} — same target-aware contract as [.badge]#text#
out = process(HEADER + changelog(
    "  \\changelogentry{1.0.0}{2026-01-01}"
    "{\\item Badge \\badge{New} here}"), 'guide', 'docx')
check("badge command: docx sentinel", "**[BADGE:New]**" in out)

print("=== Cover meta line ===")

# 16. Version meta line on the cover; :nochangelog: hides it (L12)
out = process(HEADER + "Body.\n", 'guide', 'md')
check("cover meta: **v1.0.0** shown", "**v1.0.0**" in out)
out = process(":lang: en\n:version: 1.0.0\n:nochangelog:\n\nBody.\n",
              'guide', 'md')
check("cover meta: hidden by :nochangelog:", "**v1.0.0**" not in out)

print("=== Language-aware result badges ===")

# 17. POC + pt: result roles → Portuguese \pocresult labels
out = process(":lang: pt\n:version: 1.0.0\n\n[.result-pass]#Pass#\n",
              'poc', 'docx')
check("poc+pt: result-pass → **[Atendido]**", "**[Atendido]**" in out)
out = process(":lang: pt\n:version: 1.0.0\n\n[.result-fail]#Fail#\n",
              'poc', 'docx')
check("poc+pt: result-fail → **[Falha]**", "**[Falha]**" in out)

# 18. testbook + pt: result-* roles stay EN (they are POC constructs —
# \pocresult labels are POC-gated in _result_badge_texts); testbook's own
# \testresultbadge is PT-aware (see "PT testbook badges" below)
out = process(":lang: pt\n:version: 1.0.0\n\n[.result-pass]#Pass#\n",
              'testbook', 'docx')
check("testbook+pt: result-pass stays **[Pass]**", "**[Pass]**" in out)

# 19. \testresultbadge preserves case (Blocked, not BLOCKED)
out = process(HEADER + "++++\n\\begin{testsummary}\n"
              "\\testsummaryrow{TC-01}{Title}"
              "{\\testresultbadge{Blocked}}\n"
              "\\end{testsummary}\n++++\n", 'testbook', 'md')
check("testresultbadge: case preserved (**[Blocked]**)",
      "**[Blocked]**" in out)

print("=== PT signatures + classification ===")

# 20. PT signature greeting matches PDF (At.te,), not Atenciosamente
SIG_PT = (":lang: pt\n:version: 1.0.0\n\n++++\n\\begin{signatures}\n"
          "\\signaturecell{Alice}{Dev}{a@x}{City}\n"
          "\\end{signatures}\n++++\n")
out = process(SIG_PT, 'poc', 'md')
check("pt signature: At.te,", "At.te," in out)
check("pt signature: no Atenciosamente", "Atenciosamente" not in out)

# 21. PT classification label matches full PDF wording
out = process(":lang: pt\n:version: 1.0.0\n\n"
              + changelog("  \\changelogentry{1.0.0}{2026-01-01}"
                          "{\\item Status: \\pocwithreservations}"),
              'poc', 'md')
check("pt classification: Homologada com ressalvas",
      "Homologada com ressalvas" in out)

print("=== Language-aware table headers ===")

# 22. PT closing-record header
out = process(":lang: pt\n:version: 1.0.0\n\n++++\n\\begin{closingrecord}\n"
              "\\closingrow{A}{B}\n"
              "\\end{closingrecord}\n++++\n", 'poc', 'md')
check("pt closingrecord: Item | Registro", "| Item | Registro" in out)

# 23. PT changelog header
out = process(":lang: pt\n:version: 1.0.0\n\n"
              + changelog("  \\changelogentry{1.0.0}{2026-01-01}"
                          "{\\item Change.}"), 'poc', 'md')
check("pt changelog: Versão | Data | Alterações",
      "| Versão | Data | Alterações" in out)

# 24. EN regression: closing-record + changelog headers
out = process(HEADER + "++++\n\\begin{closingrecord}\n"
              "\\closingrow{A}{B}\n"
              "\\end{closingrecord}\n++++\n", 'poc', 'md')
check("en closingrecord: Item | Record", "| Item | Record" in out)
out = process(HEADER
              + changelog("  \\changelogentry{1.0.0}{2026-01-01}"
                          "{\\item Change.}"), 'poc', 'md')
check("en changelog: Version | Date | Changes",
      "| Version | Date | Changes" in out)

# 25. PT stakeholders header
out = process(":lang: pt\n:version: 1.0.0\n\n++++\n\\begin{stakeholders}\n"
              "\\stakeholderorg{Org}\n"
              "\\end{stakeholders}\n++++\n", 'poc', 'md')
check("pt stakeholders: Nome | E-mail | Telefone | Papel",
      "| Nome | E-mail | Telefone | Papel" in out)

print("=== Technical cover parity ===")

# 26. technical + setreport* passthrough: meta uses report values
TECH_HDR = (":lang: en\n:version: 3.6.1\n:notime:\n\n")
TECH_PASSTHROUGH = ("++++\n\\setreportversion{HCS 8.5.1}\n"
                    "\\setreportdate{2025-08-13}\n"
                    "\\setreportscenario{Standard Scenario}\n++++\n")
out = process(TECH_HDR + TECH_PASSTHROUGH + "Body.\n", 'technical', 'md')
check("technical meta: **vHCS 8.5.1** — 2025-08-13",
      "**vHCS 8.5.1** — 2025-08-13" in out)
check("technical meta: no doc version v3.6.1 in meta",
      "v3.6.1" not in out)

# 27. Version table rows present
check("technical table: | *Version* | HCS 8.5.1",
      "| *Version* | HCS 8.5.1" in out)
check("technical table: | *Date* | 2025-08-13",
      "| *Date* | 2025-08-13" in out)
check("technical table: | *Scenario* | Standard Scenario",
      "| *Scenario* | Standard Scenario" in out)

# 28. Type label present
check("technical: type label 'Technical Report'",
      "Technical Report" in out)

# 29. technical + :nochangelog: → no meta, but the version table stays
# (PDF technical.cls renders the table outside \if@changelog; only
# covermeta is gated — L12).
out = process(":lang: en\n:version: 3.6.1\n:nochangelog:\n\n"
              + TECH_PASSTHROUGH + "Body.\n", 'technical', 'md')
check("technical nochangelog: no meta line",
      "**vHCS 8.5.1**" not in out)
check("technical nochangelog: version table present",
      "| *Version* | HCS 8.5.1" in out)

# 30. technical + :authors: → Author row
out = process(":lang: en\n:version: 3.6.1\n:notime:\n:authors: Jane Doe\n\n"
              + TECH_PASSTHROUGH + "Body.\n", 'technical', 'md')
check("technical authors: | *Author* | Jane Doe",
      "| *Author* | Jane Doe" in out)

# 31. Regression: guide cover unchanged
out = process(HEADER + "Body.\n", 'guide', 'md')
check("guide regression: **v1.0.0** meta", "**v1.0.0**" in out)
check("guide regression: generic cover text",
      "Huawei Technologies CO., LTD" in out)

print("=== Codefile blocks ===")

# 32. [.codefile] with a real file → [source,lang] block with the content
with tempfile.TemporaryDirectory() as tmp:
    # Simulate the document layout: .adoc in src/, assets in assets/
    adoc_dir = os.path.join(tmp, "src")
    os.makedirs(adoc_dir)
    os.makedirs(os.path.join(tmp, "assets"))
    with open(os.path.join(tmp, "assets", "example-script.sh"), "w") as f:
        f.write("#!/bin/bash\necho hello\n")
    out = process(
        HEADER + "[.codefile,file=assets/example-script.sh,lang=bash]\n"
        "----\n----\n", 'guide', 'docx', adoc_dir)
    check("codefile: [source,bash] emitted", "[source,bash]" in out)
    check("codefile: file content inlined", "echo hello" in out)
    check("codefile: role line removed", "[.codefile" not in out)

    # Fallback: file next to the .adoc (src/), no lang → [source]
    with open(os.path.join(adoc_dir, "local.txt"), "w") as f:
        f.write("plain text\n")
    out = process(
        HEADER + "[.codefile,file=local.txt]\n----\n----\n",
        'guide', 'md', adoc_dir)
    check("codefile: no lang → [source]", "\n[source]\n" in out)
    check("codefile: fallback to adoc dir", "plain text" in out)

    # Non-empty listing body is discarded (PDF: the body is ignored)
    out = process(
        HEADER + "[.codefile,file=local.txt,lang=text]\n"
        "----\nignored body\n----\n", 'guide', 'html', adoc_dir)
    check("codefile: listing body discarded", "ignored body" not in out)
    check("codefile: file content wins", "plain text" in out)

    # NOTE: inside file content stays literal (no DOCX callout sentinel)
    with open(os.path.join(tmp, "assets", "note.sh"), "w") as f:
        f.write("# NOTE: literal inside script\n")
    out = process(
        HEADER + "[.codefile,file=assets/note.sh,lang=bash]\n----\n----\n",
        'guide', 'docx', adoc_dir)
    check("codefile: NOTE in content stays literal",
          "# NOTE: literal inside script" in out and "\u2016" not in out)

# 33. Missing file → block left as-is, warning on stderr, no crash
with tempfile.TemporaryDirectory() as tmp:
    err = io.StringIO()
    miss_out = None
    try:
        with contextlib.redirect_stderr(err):
            miss_out = process(
                HEADER + "[.codefile,file=assets/missing.sh,lang=bash]\n"
                "----\n----\n", 'guide', 'docx', tmp)
        ok = True
    except Exception:
        ok = False
    check("codefile missing: no exception", ok)
    check("codefile missing: block left as-is",
          miss_out is not None
          and "[.codefile,file=assets/missing.sh,lang=bash]" in miss_out)
    check("codefile missing: warning on stderr",
          "warning" in err.getvalue() and "missing.sh" in err.getvalue())

# 34. Content with a ---- line → fence lengthened past it
with tempfile.TemporaryDirectory() as tmp:
    adoc_dir = os.path.join(tmp, "src")
    os.makedirs(adoc_dir)
    with open(os.path.join(adoc_dir, "dashes.txt"), "w") as f:
        f.write("echo start\n----\necho end\n")
    out = process(
        HEADER + "[.codefile,file=dashes.txt]\n----\n----\n",
        'guide', 'md', adoc_dir)
    check("codefile: fence lengthened past ---- line",
          any(line == "-----" for line in out.split("\n")))
    check("codefile: content around dashes preserved",
          "echo start" in out and "echo end" in out)

print("=== PT technical cover labels ===")

# 35. technical + pt: cover table labels render in Portuguese
TECH_PT_HDR = ":lang: pt\n:version: 3.6.1\n:notime:\n:authors: Jane Doe\n\n"
TECH_PT_PASS = ("++++\n\\setreportversion{HCS 8.5.1}\n"
                "\\setreportdate{2025-08-13}\n"
                "\\setreportscenario{Cenario Padrao}\n++++\n")
out = process(TECH_PT_HDR + TECH_PT_PASS + "Body.\n", 'technical', 'md')
check("pt technical cover: | *Versao* | HCS 8.5.1",
      "| *Vers\u00e3o* | HCS 8.5.1" in out)
check("pt technical cover: | *Data* | 2025-08-13",
      "| *Data* | 2025-08-13" in out)
check("pt technical cover: | *Cenario* label",
      "| *Cen\u00e1rio* | Cenario Padrao" in out)
check("pt technical cover: | *Autor* | Jane Doe",
      "| *Autor* | Jane Doe" in out)
# EN regression: labels stay English
out = process(TECH_HDR + TECH_PASSTHROUGH + "Body.\n", 'technical', 'md')
check("en technical cover: | *Version* | HCS 8.5.1",
      "| *Version* | HCS 8.5.1" in out)
check("en technical cover: no Versao label", "| *Vers\u00e3o*" not in out)

print("=== PT general-objective label ===")

# 36. [.general-objective]#...# — PT label matches \lg@generalobjectivelabel
out = process(":lang: pt\n:version: 1.0.0\n\n"
              "[.general-objective]#Verificar o acesso ao Console.#\n",
              'guide', 'md')
check("pt general-objective: **Objetivo Geral:**",
      "**Objetivo Geral:**" in out)
check("pt general-objective: no EN label", "General Objective" not in out)
# EN regression
out = process(HEADER + "[.general-objective]#Verify access.#\n", 'guide', 'md')
check("en general-objective: **General Objective:**",
      "**General Objective:**" in out)

print("=== PT HTML caption attributes ===")

# 37. html + pt: caption/admonition attributes injected into the header
out = process(":lang: pt\n:version: 1.0.0\n\nBody.\n", 'guide', 'html')
check("pt html: :tip-caption: Dica", ":tip-caption: Dica" in out)
check("pt html: :note-caption: Informacao",
      ":note-caption: Informa\u00e7\u00e3o" in out)
check("pt html: :warning-caption: Importante",
      ":warning-caption: Importante" in out)
check("pt html: :caution-caption: Importante",
      ":caution-caption: Importante" in out)
check("pt html: :important-caption: Importante",
      ":important-caption: Importante" in out)
check("pt html: :figure-caption: Figura", ":figure-caption: Figura" in out)
check("pt html: :table-caption: Tabela", ":table-caption: Tabela" in out)
check("pt html: :toc-title: Sumario", ":toc-title: Sum\u00e1rio" in out)
# Not injected for docx/md or en
out = process(":lang: pt\n:version: 1.0.0\n\nBody.\n", 'guide', 'docx')
check("pt docx: no caption attrs", ":figure-caption:" not in out)
out = process(":lang: pt\n:version: 1.0.0\n\nBody.\n", 'guide', 'md')
check("pt md: no caption attrs", ":figure-caption:" not in out)
out = process(HEADER + "Body.\n", 'guide', 'html')
check("en html: no caption attrs", ":figure-caption:" not in out)

print("=== PT testbook result badges ===")

# 38. testbook + pt: \testresultbadge enums render PT labels (source stays EN)
TB_PT_HDR = ":lang: pt\n:version: 1.0.0\n\n"
for _src, _pt in [("Pass", "Aprovado"), ("Fail", "Reprovado"),
                  ("Blocked", "Bloqueado"), ("Untested", "N\u00e3o testado")]:
    out = process(TB_PT_HDR + "++++\n\\begin{testsummary}\n"
                  "\\testsummaryrow{1}{T}{\\testresultbadge{" + _src + "}}\n"
                  "\\end{testsummary}\n++++\n", 'testbook', 'md')
    check("pt testbook badge: " + _src + " -> **[" + _pt + "]**",
          "**[" + _pt + "]**" in out)
# EN regression: enums preserved
out = process(HEADER + "++++\n\\begin{testsummary}\n"
              "\\testsummaryrow{1}{T}{\\testresultbadge{Pass}}\n"
              "\\end{testsummary}\n++++\n", 'testbook', 'md')
check("en testbook badge: **[Pass]**", "**[Pass]**" in out)
# Unknown value passes through (cls fallback badge)
out = process(TB_PT_HDR + "++++\n\\begin{testsummary}\n"
              "\\testsummaryrow{1}{T}{\\testresultbadge{Custom}}\n"
              "\\end{testsummary}\n++++\n", 'testbook', 'md')
check("pt testbook badge: unknown passes through", "**[Custom]**" in out)

print("=== Signatures E-mail label (lang-aware) ===")

# 39. signatures E-mail label routed through labels['th_email']
# (PDF \lg@sigemail is 'E-mail' for both en and pt)
out = process(HEADER + "++++\n\\begin{signatures}\n"
              "\\signaturecell{Alice}{Dev}{a@x}{City}\n"
              "\\end{signatures}\n++++\n", 'poc', 'md')
check("en signature: E-mail: label", "E-mail: `a@x`" in out)
out = process(":lang: pt\n:version: 1.0.0\n\n++++\n\\begin{signatures}\n"
              "\\signaturecell{Alice}{Dev}{a@x}{City}\n"
              "\\end{signatures}\n++++\n", 'poc', 'md')
check("pt signature: E-mail: label", "E-mail: `a@x`" in out)

print("=== PT image placeholder ===")

# 40. \imageplaceholder inline passthrough — PT label
out = process(":lang: pt\n:version: 1.0.0\n\n"
              "pass:[\\imageplaceholder{assets/x.png}{Tela do Console}]\n",
              'guide', 'md')
check("pt imageplaceholder: Espaco reservado para imagem",
      "Espa\u00e7o reservado para imagem: Tela do Console" in out)
check("pt imageplaceholder: no EN label", "Image placeholder:" not in out)
# EN regression
out = process(HEADER
              + "pass:[\\imageplaceholder{assets/x.png}{Console screen}]\n",
              'guide', 'md')
check("en imageplaceholder: Image placeholder",
      "Image placeholder: Console screen" in out)

print("=== PT HTML caption attributes (placement) ===")

# 41. html + pt: injected attributes land in the header (before the
# first blank line), and the cover block follows them (header order)
out = process(":lang: pt\n:version: 1.0.0\n\nBody.\n", 'guide', 'html')
check("html pt: attrs in header",
      ":note-caption: Informação" in out.split("\n\n")[0])
_out_lines = out.split("\n")
_toc_idx = next((i for i, l in enumerate(_out_lines)
                 if l.startswith(":toc-title:")), -1)
_logo_idx = next((i for i, l in enumerate(_out_lines)
                  if l.startswith("image::")), -1)
check("html pt: cover block after injected attrs",
      _toc_idx != -1 and _logo_idx != -1 and _toc_idx < _logo_idx)

# 42. docx + pt: admonition still becomes a **TYPE‖** sentinel (the
# caption-attribute injection is html-only and must not touch docx)
out = process(":lang: pt\n:version: 1.0.0\n\nNOTE: Aviso.\n", 'guide', 'docx')
check("docx pt: admonition sentinel intact", "**NOTE\u2016**" in out)

print("=== PT testcase result field ===")

# 43. testcase \testresult passthrough: PT field label + PT badge text
out = process(":lang: pt\n:version: 1.0.0\n\n++++\n\\begin{testcase}{Demo}\n"
              "  \\testresult{\\testresultbadge{Pass}}\n"
              "\\end{testcase}\n++++\n", 'testbook', 'docx')
check("pt testcase: Resultado do Teste + **[Aprovado]**",
      "Resultado do Teste" in out and "**[Aprovado]**" in out)

print(f"\nResults: {PASS} passed, {FAIL} failed")
sys.exit(1 if FAIL else 0)
PYEOF
