---
name: huawei-template-ppt
description: Create or edit Huawei Cloud slide decks using the PPT template. Use when the user wants to create slides, a presentation, or a slide deck for Huawei Cloud. Triggers on keywords like huawei-template-ppt, huawei slides, apresentação, slide deck, pptx.
---

# Huawei Cloud PPT — Skill

Create and generate Huawei Cloud slide decks (`.pptx`) using the
`huawei_ppt` Python library and the bundled Huawei brand template.

## When to use

Use this skill when the task is to **create a Huawei Cloud slide deck or
presentation**. The output is a `.pptx` file (and optionally a `.pdf` via
LibreOffice). Do **not** use this for general PPTX files — the formatting
is hard-coded to the Huawei house style (AGENTS.md L9).

---

## Quick start — creating a new slide deck

1. **Ask for the essentials** (if not already provided):
   - **Title** — e.g. "HCS Overview Training"
   - **Language** — English (default) or Portuguese
   - **Project name** — used as the folder name (e.g. `hcs-training`)

2. **Create a self-contained project folder** at `documents/<project-name>/`:
   - Inside the folder, create:
     - `generate.py` — the deck generator (see skeleton below).
     - `assets/` subfolder for project-specific images.

3. **Run the generator** with `python3 generate.py` from inside the
   project folder.

4. **Report** the slide count and output file path to the user.

---

## Hard requirements

- **Python 3.8+** with `python-pptx >= 0.6.21` and `lxml >= 4.9`.
  Install with: `pip install -r templates/ppt/requirements.txt`
- **LibreOffice** (optional) — needed only for PDF export via `to_pdf()`.
- **The bundled template** — `templates/ppt/common-assets/huawei-template.pptx`
  must be present. It provides the slide masters and layout definitions.

---

## Project layout (this directory)

```
templates/ppt/
├── huawei_ppt.py              # the library — all formatting helpers live here
├── SKILL.md                   # this file (opencode skill)
├── README.md                  # human docs (brief)
├── requirements.txt           # Python dependencies
└── common-assets/
    └── huawei-template.pptx   # brand PPT template (slide masters + layouts)

# Each document has its own folder:
documents/
└── my-slides/
    ├── generate.py            # deck generator script
    └── assets/                # project-specific images

# Samples:
examples/ppt/
├── en/
│   └── generate.py            # English sample
└── pt-br/
    └── generate.py            # Portuguese sample
```

**Rule of thumb:** content/structure goes in `generate.py`; look-and-feel
goes in `huawei_ppt.py` and the template. Do not inline formatting
overrides in the generator unless the user asks.

---

## API reference

### Deck creation

| Function | Signature | Returns |
|---|---|---|
| `new_deck` | `new_deck(template_path=None)` | `(prs, layouts)` — presentation + layout dict |
| `save_deck` | `save_deck(prs, filepath)` | Absolute path to saved `.pptx` |
| `to_pdf` | `to_pdf(pptx_path)` | Path to generated `.pdf` |

### Slide builders

| Function | Signature | Returns |
|---|---|---|
| `add_slide` | `add_slide(prs, layouts, layout_name)` | Slide object |
| `title_slide` | `title_slide(prs, layouts, module, subtitle, tag)` | None |
| `authorship_slide` | `authorship_slide(prs, layouts, author="", employee_id="", version="v1.0", date="")` | None |
| `chapter_slide` | `chapter_slide(prs, layouts, title, subtitle="")` | None |
| `content_slide` | `content_slide(prs, layouts, title)` | Slide object |
| `thank_you_slide` | `thank_you_slide(prs, layouts)` | None |
| `last_slide` | `last_slide(prs, layouts)` — deprecated alias for `thank_you_slide` | None |

### Content helpers

| Function | Signature | Returns |
|---|---|---|
| `text_box` | `text_box(slide, text, left, top, width, height, size=14, color=DARK, bold=False, align=PP_ALIGN.LEFT)` | TextBox shape |
| `set_title` | `set_title(slide, title, color=RED, size=24, top=0.35)` | None |
| `add_table` | `add_table(slide, headers, rows, left=None, top=TOP_CONTENT+0.2, col_widths=None)` | Table shape |
| `table_bottom` | `table_bottom(table_shape)` | Bottom Y in inches |
| `callout` | `callout(slide, kind, text, left=LEFT_MARGIN, top=None, width=CONTENT_WIDTH)` | TextBox shape |

### Flowchart helpers

| Function | Signature | Returns |
|---|---|---|
| `flow_box` | `flow_box(slide, text, left, top, width=2.5, height=0.6, fill=GRAY_BG, font_color=DARK, font_size=11, bold=False)` | Shape |
| `flow_arrow` | `flow_arrow(slide, left, top, width=0.4, height=0.4, direction='down')` | Shape |
| `flow_decision` | `flow_decision(slide, text, left, top, width=2.0, height=1.0)` | Shape |
| `flowchart_vertical` | `flowchart_vertical(slide, steps, left=..., top=..., box_width=2.5, box_height=0.55, gap=0.35)` | Bottom Y |
| `flowchart_horizontal` | `flowchart_horizontal(slide, steps, left=..., top=..., box_width=2.2, box_height=0.6, gap=0.3)` | Right X |

### Callout kinds (locked — AGENTS.md L3)

| Kind | Background | Icon | Use |
|---|---|---|---|
| `'warning'` | Amber | ⚠ | Warning / caution — potential pitfalls |
| `'tip'` | Green | ✓ | Tip / suggestion — best practices |
| `'infobox'` | Blue | ℹ | Informational note — helpful context |

### Internal helpers

| Function | Purpose |
|---|---|
| `get_layouts(prs)` | Build layout name → layout dict |
| `remove_all_slides(prs)` | Clear all slides from template |
| `clean_zip(filepath)` | Rewrite ZIP with deterministic ordering |
| `_emu(v)` | Convert inches (float) or EMU (int) to EMU |

---

## Constants

| Name | Value | Description |
|---|---|---|
| `SLIDE_W` | 13.3 | Slide width in inches |
| `SLIDE_H` | 7.5 | Slide height in inches |
| `LEFT_MARGIN` | 0.8 | Left content margin |
| `RIGHT_MARGIN` | 0.8 | Right content margin |
| `CONTENT_WIDTH` | 11.7 | Available content width |
| `TOP_CONTENT` | 1.5 | Top position for content below title |
| `CENTER_X` | 6.65 | Horizontal center of slide |

---

## Brand colors (locked — AGENTS.md L9)

| Name | Hex | Use |
|---|---|---|
| `RED` | `#C7000B` | Huawei brand red (headers, accents) |
| `WHITE` | `#FFFFFF` | White |
| `NEAR_WHITE` | `#E8E8E8` | Light text on dark backgrounds |
| `GRAY_BG` | `#F6F8FA` | Alternating table row / code background |
| `LIGHT_GRAY` | `#F2F2F2` | Light gray |
| `DARK` | `#1F2328` | Body text |
| `MED_GRAY` | `#666666` | Secondary text |
| `LIGHT_DARK` | `#4A4A4A` | Tertiary text |
| `AMBER_BG/FG/BD` | `#FDF8EE` / `#8A6D00` / `#D4A72C` | Warning callout (muted gold) |
| `GREEN_BG/FG/BD` | `#EDF6ED` / `#2E6B2E` / `#5BA85B` | Tip callout (muted sage) |
| `BLUE_BG/FG/BD` | `#EDF3F9` / `#1B5170` / `#4A8BB5` | Infobox callout (muted slate) |

---

## Skeleton `generate.py`

```python
#!/usr/bin/env python3
"""Generate a Huawei Cloud slide deck."""

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 '..', '..', 'templates', 'ppt'))
from huawei_ppt import *

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

def main():
    prs, layouts = new_deck()

    title_slide(prs, layouts,
                "My Presentation Title",
                "Subtitle line",
                "Tag line")
    authorship_slide(prs, layouts, author="Author Name",
                     employee_id="emp123", version="v1.0",
                     date="August 2026")

    s = content_slide(prs, layouts, "First Section")
    text_box(s, "Content goes here.",
             Inches(LEFT_MARGIN), Inches(TOP_CONTENT),
             Inches(CONTENT_WIDTH), Inches(3), 16, DARK)

    s = content_slide(prs, layouts, "With Table")
    add_table(s, ["Column A", "Column B"], [
        ["Row 1", "Value"],
        ["Row 2", "Value"],
    ])

    s = content_slide(prs, layouts, "With Callout")
    callout(s, 'tip', "This is a helpful tip.")

    thank_you_slide(prs, layouts)

    path = save_deck(prs, os.path.join(OUT_DIR, "my-deck.pptx"))
    print(f"Saved: {path}")

if __name__ == "__main__":
    main()
```

---

## Compilation

From the project folder:

```bash
python3 generate.py                    # creates .pptx
python3 -c "from huawei_ppt import to_pdf; to_pdf('my-deck.pptx')"  # optional PDF
```

PDF export requires LibreOffice (`soffice`) installed and available on PATH.

---

## Agent workflow checklist

1. Import `huawei_ppt` at the top of `generate.py` (use `sys.path.insert`
   to point to `templates/ppt/`).
2. Use `new_deck()` to start from the clean template.
3. Add slides using `title_slide`, `authorship_slide` (page-2 back cover),
   `chapter_slide`, `content_slide`, and `thank_you_slide` (closing page).
4. Add content with `text_box`, `add_table`, `callout`.
5. Use `table_bottom()` to position callouts below tables.
6. Save with `save_deck()` (auto-cleans the ZIP).
7. Run `python3 generate.py` and verify the output.
