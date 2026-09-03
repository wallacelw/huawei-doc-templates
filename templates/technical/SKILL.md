---
name: huawei-template-technical
description: Create or edit Huawei Cloud technical reports using the technical report template (DOCX engine). Use when the user wants to create a report, technical report, analysis report, or DOCX document for Huawei Cloud. Triggers on keywords like huawei-template-technical, huawei report, technical report, analysis report, relatório técnico, docx.
---

# Huawei Cloud Technical Report — Skill

Create and generate Huawei Cloud technical reports (`.docx`) using the
`huawei_technical` Python library and the bundled Huawei technical report
template.

## When to use

Use this skill when the task is to **create a Huawei Cloud technical report
or DOCX document**. The output is a `.docx` file (and optionally a `.pdf`
via LibreOffice). Do **not** use this for general DOCX files — the formatting
is hard-coded to the Huawei house style (AGENTS.md L9).

> **Note:** This template was renamed from "analysis report" to "technical
> report". The skill name changed from `huawei-template-docx` to
> `huawei-template-technical`. The function `create_analysis_report()` is
> kept as a backward-compatibility alias for `create_technical_report()`.

---

## Quick start — creating a new report

1. **Ask for the essentials** (if not already provided):
   - **Title** — e.g. "ECS Creation Page Technical Report"
   - **Language** — English (default) or Portuguese
   - **Project name** — used as the folder name (e.g. `ecs-technical`)

2. **Create a self-contained project folder** at `documents/<project-name>/`:
   - Inside the folder, create:
     - `generate.py` — the report generator (see skeleton below).
     - `assets/` subfolder for project-specific images.

3. **Run the generator** with `python3 generate.py` from inside the
   project folder.

4. **Report** the output file path to the user.

---

## Hard requirements

- **Python 3.8+** with `python-docx >= 1.1` and `lxml >= 4.9`.
  Install with: `pip install -r templates/technical/requirements.txt`
- **LibreOffice** (optional) — needed only for PDF export via `to_pdf()`.
- **The bundled template** — `templates/technical/common-assets/technical-report-template.docx`
  must be present. It provides the styles, sections, and page layout.

---

## Project layout (this directory)

```
templates/technical/
├── huawei_technical.py             # the library — all formatting helpers live here
├── SKILL.md                        # this file (opencode skill)
├── README.md                       # human docs (brief)
├── requirements.txt                # Python dependencies
└── common-assets/
    └── technical-report-template.docx  # brand DOCX template (styles + layout)

# Each document has its own folder:
documents/
└── my-report/
    ├── generate.py             # report generator script
    └── assets/                 # project-specific images

# Samples:
examples/technical/
├── en/
│   └── generate.py             # English sample
└── pt/
    └── generate.py             # Portuguese sample
```

**Rule of thumb:** content/structure goes in `generate.py`; look-and-feel
goes in `huawei_technical.py` and the template. Do not inline formatting
overrides in the generator unless the user asks.

---

## Template structure

The bundled `technical-report-template.docx` is a **generalized** Huawei Cloud
technical report template. It preserves all styles, formatting, headers,
footers, copyright, and safety pages, but replaces specific incident content
with `{{PLACEHOLDER}}` markers that are filled at generation time.

### Standard technical report sections

| # | Section | Placeholder | Description |
|---|---|---|---|
| 1 | Problem Description and Impact | `{{PROBLEM_DESCRIPTION}}` | What went wrong and its impact |
| 2 | Root Cause Analysis | `{{ROOT_CAUSE_ANALYSIS}}` | Step-by-step analysis |
| 3 | Root Cause | `{{ROOT_CAUSE}}` | The identified root cause |
| 4 | Trigger Condition | `{{TRIGGER_CONDITION}}` | When the issue occurs |
| 5 | Workaround and Impact | (container section) | |
| 5.1 | Impact | `{{IMPACT}}` | Impact of the workaround |
| 5.2 | Back up data before the workaround | `{{BACKUP_DATA}}` | Backup steps (or N/A) |
| 5.3 | Workaround | `{{WORKAROUND}}` | Step-by-step workaround |
| 5.4 | Verification after the workaround | `{{VERIFICATION}}` | How to verify the fix |
| 5.5 | Rollback Operation | `{{ROLLBACK}}` | How to undo the workaround |
| 5.6 | Cleanup Operation | `{{CLEANUP}}` | Post-fix cleanup steps |

### Version info table placeholders

| Cell | Placeholder | Example |
|---|---|---|
| Detailed version | `{{VERSION}}` | `HCS 8.5.1` |
| Installation Scenario | `{{SCENARIO}}` | `Standard Scenario` |
| Trigger Condition | `{{TRIGGER_CONDITION}}` | (also in table) |

### Cover page placeholders

| Cell | Placeholder | Example |
|---|---|---|
| Report title | `{{TITLE}}` | `[Analysis Report] ...` |
| Release date | `{{RELEASE_DATE}}` | `2025-08-13` |

### Other template content (preserved, not placeholder-driven)

| Section | Content |
|---|---|
| Cover page | Title, version, date (in a styled table) |
| Copyright | Copyright notice |
| Company info | Huawei Technologies Co., Ltd. address and website |
| Safety | Safety statement and vulnerability handling process |
| Management Scale | "Irrelevant to the scale of management" |
| Contents | Auto-generated table of contents |

### When to use this template vs. the LaTeX guide

- **DOCX technical report** — formal incident/issue reports with the standard
  6-section structure (problem → root cause → trigger → workaround). Best for
  customer-facing technical/analysis reports.
- **LaTeX guide** (`huawei-template-guide`) — informal, legible guides with
  custom section structure, code blocks, images, and step-by-step instructions.
  Best for training materials and how-to guides.

Use `create_technical_report(replacements)` to fill all placeholders at once,
or `fill_template(doc, replacements)` for partial filling. You can also use
`add_heading` / `add_paragraph` / `add_table` / `add_callout` to append
additional content after filling.

---

## API reference

### Report creation

| Function | Signature | Returns |
|---|---|---|
| `load_template` | `load_template(template_path=None)` | Document object from template |
| `new_report` | `new_report(template_path=None)` | Document object (alias for `load_template`) |
| `create_technical_report` | `create_technical_report(replacements, template_path=None)` | Document with placeholders filled |
| `fill_template` | `fill_template(doc, replacements)` | Number of replacements made |
| `save_report` | `save_report(doc, filepath)` | Absolute path to saved `.docx` |
| `to_pdf` | `to_pdf(docx_path)` | Path to generated `.pdf` |

> `create_analysis_report` is a backward-compatibility alias for
> `create_technical_report`.

### Content builders

| Function | Signature | Returns |
|---|---|---|
| `add_heading` | `add_heading(doc, text, level=1)` | Heading paragraph (level 1 gets Huawei red) |
| `add_paragraph` | `add_paragraph(doc, text, style=None)` | Paragraph object |
| `add_table` | `add_table(doc, headers, rows)` | Table with Huawei red header, alternating rows, first column bold |
| `add_callout` | `add_callout(doc, kind, text)` | Single-cell table with colored background |
| `fill_section` | `fill_section(doc, placeholder, text)` | Number of replacements made |

### Callout kinds (locked — AGENTS.md L3)

| Kind | Background | Border | Label | Use |
|---|---|---|---|---|
| `'warning'` | Amber `#FFF8E1` | Amber `#F57C00` | **Important** | Warning / caution — potential pitfalls |
| `'tip'` | Green `#E8F5E9` | Green `#2E7D32` | **Tip** | Tip / suggestion — best practices |
| `'infobox'` | Blue `#E3F2FD` | Blue `#1565C0` | **Info** | Informational note — helpful context |

---

## Brand colors (locked — AGENTS.md L9)

| Name | Hex | Use |
|---|---|---|
| `HUAWEI_RED` | `#C7000B` | Huawei brand red (headers, accents) |
| `CODE_BG` | `#F6F8FA` | Code / alternating table row background |
| `CODE_TEXT` | `#1F2328` | Code text / body text |
| `LINK_BLUE` | `#0000FF` | Links |
| `RULE_BLACK` | `#000000` | Horizontal rules |
| `WHITE` | `#FFFFFF` | White |
| `DARK` | `#1F2328` | Body text |
| `GRAY_BG` | `#F6F8FA` | Alternating table row background |
| `WARNING_BG/FG/BD` | `#FFF8E1` / `#F57C00` / `#F57C00` | Warning callout (amber) |
| `TIP_BG/FG/BD` | `#E8F5E9` / `#2E7D32` / `#2E7D32` | Tip callout (green) |
| `INFO_BG/FG/BD` | `#E3F2FD` / `#1565C0` / `#1565C0` | Infobox callout (blue) |

---

## Skeleton `generate.py`

```python
#!/usr/bin/env python3
"""Generate a Huawei Cloud technical report."""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 '..', '..', 'templates', 'technical'))
from huawei_technical import *

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
    replacements = {
        'TITLE': '[Analysis Report] Report title here',
        'RELEASE_DATE': '2025-08-13',
        'PROBLEM_DESCRIPTION': 'Describe the problem and its impact.',
        'ROOT_CAUSE_ANALYSIS': '1. First analysis step\n2. Second step',
        'ROOT_CAUSE': 'The identified root cause.',
        'TRIGGER_CONDITION': 'When this condition is met, the issue occurs.',
        'IMPACT': 'Impact of applying the workaround.',
        'BACKUP_DATA': 'N/A — no data modification required.',
        'WORKAROUND': '1. Step one\n2. Step two\n3. Step three',
        'VERIFICATION': 'How to verify the fix worked.',
        'ROLLBACK': 'How to undo the workaround.',
        'CLEANUP': 'No cleanup required.',
        'VERSION': 'HCS 8.5.1',
        'SCENARIO': 'Standard Scenario',
    }

    doc = create_technical_report(replacements)
    path = save_report(doc, os.path.join(OUT_DIR, "report.docx"))
    print(f"Saved: {path}")

if __name__ == "__main__":
    main()
```

---

## Compilation

From the project folder:

```bash
python3 generate.py                    # creates .docx
python3 -c "from huawei_technical import to_pdf; to_pdf('report.docx')"  # optional PDF
```

PDF export requires LibreOffice (`soffice`) installed and available on PATH.

---

## Agent workflow checklist

1. Import `huawei_technical` at the top of `generate.py` (use `sys.path.insert`
   to point to `templates/technical/`).
2. Use `create_technical_report(replacements)` to create a report from the
   template with all placeholders filled in one call.
3. Alternatively, use `new_report()` + `fill_template(doc, replacements)` for
   partial or incremental filling.
4. Use `add_heading`, `add_paragraph`, `add_table`, `add_callout` to append
   additional content beyond the standard sections.
5. Save with `save_report()`.
6. Run `python3 generate.py` and verify the output.
