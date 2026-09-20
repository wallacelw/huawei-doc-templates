#!/usr/bin/env python3
"""Generate badge PNG assets that replicate the PDF \\huaweibadge / \\badge look.

Run this script once (or when the badge design changes) to regenerate the
committed PNGs in this directory.  docx_fix.py embeds these images in DOCX
output to replace the flat character-styled [PASS]/[FAIL]/... text runs
with rounded pill badges matching the PDF.

PDF reference (huawei-badges.sty \\huaweibadge):
    tcbox[on line, colback=BG, colframe=FRAME, boxrule=05pt, arc=2pt,
          fontupper=\\bfseries\\small]{\\makebox[WIDTH][c]{TEXT}}

    \\badge (NEW): \\colorbox{huaweired}{white bold \\footnotesize text}
    — flat rectangle, no rounding, no frame.

Rendered at 300 DPI for crispness; docx_fix scales to the target width
(1.5 cm for testbook test-result badges, 2 cm for POC result badges).
"""

import os
from PIL import Image, ImageDraw, ImageFont

DPI = 300
PT = DPI / 72.0          # points → pixels
CM = DPI / 2.54          # centimetres → pixels

FONT_PATH = "/usr/share/fonts/truetype/harmonyos/HarmonyOS_Sans_Bold.ttf"

# Badge specifications: (label, bg_hex, frame_hex, text_hex, is_pill)
# Pills use \huaweibadge (rounded, framed); NEW uses \badge (flat red).
SPECS = [
    # label      bg       frame    text     pill?
    ("PASS",     "E8F5E9", "62B230", "62B230", True),
    ("PARTIAL",  "FFF3E0", "ED6D00", "ED6D00", True),
    ("FAIL",     "E7D9DA", "C7000B", "C7000B", True),  # red!15 ≈ E7D9DA
    ("SKIP",     "F6F8FA", "1F2328", "1F2328", True),
    ("BLOCKED",  "FFF3E0", "ED6D00", "ED6D00", True),
    ("UNTESTED", "F6F8FA", "1F2328", "1F2328", True),
    ("NEW",      "C7000B", None,     "FFFFFF", False),  # flat red, no frame
]


def _hex(rgb_hex):
    return (int(rgb_hex[0:2], 16), int(rgb_hex[2:4], 16), int(rgb_hex[4:6], 16))


def make_pill(label, bg, frame, text_color, width_cm=2.0):
    """Rounded pill badge (\\huaweibadge replica)."""
    width_px = int(width_cm * CM)
    font_size = int(9 * PT)          # \small = 9pt
    frame_w = max(1, int(0.8 * PT))  # boxrule=0.8pt
    arc = int(2 * PT)                # arc=2pt
    pad_x = int(4 * PT)              # horizontal padding
    pad_y = int(3 * PT)              # vertical padding

    font = ImageFont.truetype(FONT_PATH, font_size)
    # Measure text
    bbox = font.getbbox(label)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    height_px = text_h + 2 * pad_y + 2 * frame_w

    img = Image.new("RGBA", (width_px, height_px), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    # Frame (outer rounded rect)
    draw.rounded_rectangle(
        [0, 0, width_px - 1, height_px - 1], radius=arc,
        fill=_hex(bg), outline=_hex(frame), width=frame_w)
    # Text (centred)
    tx = (width_px - text_w) // 2 - bbox[0]
    ty = (height_px - text_h) // 2 - bbox[1]
    draw.text((tx, ty), label, font=font, fill=_hex(text_color))
    return img


def make_flat(label, bg, text_color):
    """Flat rectangle badge (\\badge replica — \\colorbox)."""
    font_size = int(8 * PT)          # \footnotesize = 8pt
    pad = int(2 * PT)                # \fboxsep ≈ 2pt

    font = ImageFont.truetype(FONT_PATH, font_size)
    bbox = font.getbbox(label)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    width_px = text_w + 2 * pad
    height_px = text_h + 2 * pad

    img = Image.new("RGBA", (width_px, height_px), _hex(bg))
    draw = ImageDraw.Draw(img)
    tx = pad - bbox[0]
    ty = pad - bbox[1]
    draw.text((tx, ty), label, font=font, fill=_hex(text_color))
    return img


def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    for label, bg, frame, text, is_pill in SPECS:
        if is_pill:
            img = make_pill(label, bg, frame, text)
        else:
            img = make_flat(label, bg, text)
        path = os.path.join(out_dir, "badge-{}.png".format(label))
        img.save(path)
        print("  {}".format(path))


if __name__ == "__main__":
    main()
