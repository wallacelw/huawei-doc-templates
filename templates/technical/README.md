# Huawei Cloud Technical Report Template (DOCX)

Reusable Python library (`huawei_technical.py`) for generating Huawei-branded
technical reports as `.docx` files using the bundled template.

## Setup

See the [root README](../../README.md) for environment setup and
`install.sh` for one-command installation.

Install Python dependencies:

```bash
pip install -r templates/technical/requirements.txt
```

## Usage

See [SKILL.md](SKILL.md) for the full API reference, skeleton generator,
and workflow checklist.

Quick example:

```python
from huawei_technical import new_report, add_heading, add_paragraph, save_report

doc = new_report()
add_heading(doc, "Problem Description", level=1)
add_paragraph(doc, "Describe the problem here.")
save_report(doc, "report.docx")
```
