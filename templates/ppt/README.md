# Huawei Cloud PPT Template

Slide deck generator for Huawei Cloud presentations using `python-pptx`.

## Quick start

```bash
pip install -r requirements.txt
python3 generate.py   # from your project folder
```

## Files

- **`huawei_ppt.py`** — reusable library with all helpers, constants, and
  slide builders. Import this in your `generate.py`.
- **`common-assets/huawei-template.pptx`** — Huawei brand PPT template with
  slide masters and layouts.
- **`requirements.txt`** — Python dependencies.

## Documentation

- **API reference and full usage guide:** see [`SKILL.md`](SKILL.md)
- **Project setup and installation:** see root [`README.md`](../../README.md)

## Requirements

- Python 3.8+
- python-pptx >= 0.6.21
- lxml >= 4.9
- LibreOffice (optional, for PDF export)
