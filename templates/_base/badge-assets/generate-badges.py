#!/usr/bin/env python3
"""Generate badge PNG assets that replicate the PDF \\huaweibadge look.

Run this script once (or when the badge design changes) to regenerate the
PNGs in this directory.  docx_fix.py embeds these images in DOCX output to
replace the flat character-styled [Pass]/[Fail]/... text runs with rounded
pill badges matching the PDF.

PDF reference (huawei-badges.sty \\huaweibadge):
    tcbox[on line, colback=BG, colframe=FRAME, boxrule=0.8pt, arc=2pt,
          fontupper=\\bfseries\\small]{\\makebox[WIDTH][c]{TEXT}}

    The PDF sets NO text color → badge text is BLACK on all pills.
    Frame colors: Pass=tipfg(62B230), Partial/Blocked=warningfg(ED6D00),
    Fail=huaweired(C7000B), Skip/Untested=ruleblack(000000).

Labels are the exact texts the PDF renders: title-case English plus the
Portuguese \\pocresult labels (Atendido, Parcial, Falha, Ignorado).  Each
label is generated at BOTH native widths — testbook \\testresultbadge uses
1.5 cm, POC \\pocresult/\\huaweibadge uses 2 cm — so docx_fix embeds at
native size with no downscaling.  There is no NEW badge (nothing emits
[NEW] since v6.5.1).
"""

import os
from PIL import Image, ImageDraw, ImageFont

DPI = 300
PT = DPI / 72.0          # points → pixels
CM = DPI / 2.54          # centimetres → pixels

FONT_PATH = "/usr/share/fonts/truetype/harmonyos/HarmonyOS_Sans_Bold.ttf"

# Badge specifications: (label, bg_hex, frame_hex, is_pill)
# Pills replicate \huaweibadge (rounded, framed, BLACK bold text — the
# PDF sets no text color).  Labels are the exact texts the PDF renders:
# title-case English plus the Portuguese \pocresult labels.
SPECS = [
    # label       bg       frame    pill?
    ("Pass",     "E8F5E9", "62B230", True),
    ("Partial",  "FFF3E0", "ED6D00", True),
    ("Fail",     "FFD9D9", "C7000B", True),   # red!15 bg (15% red + 85% white)
    ("Skip",     "F6F8FA", "000000", True),   # ruleblack frame (PDF: codebg/ruleblack)
    ("Blocked",  "FFF3E0", "ED6D00", True),
    ("Untested", "F6F8FA", "000000", True),   # ruleblack frame
    # Portuguese POC labels (\pocresult, lang=pt)
    ("Atendido", "E8F5E9", "62B230", True),
    ("Parcial",  "FFF3E0", "ED6D00", True),
    ("Falha",    "FFD9D9", "C7000B", True),   # red!15 bg (15% red + 85% white)
    ("Ignorado", "F6F8FA", "000000", True),
]

TEXT_COLOR = "000000"   # PDF \huaweibadge sets no text color → black
WIDTHS_CM = (1.5, 2.0)  # testbook 1.5cm, POC 2cm — native render, no scaling


def _hex(rgb_hex):
    return (int(rgb_hex[0:2], 16), int(rgb_hex[2:4], 16), int(rgb_hex[4:6], 16))


def make_pill(label, bg, frame, width_cm=2.0):
    """Rounded pill badge (\\huaweibadge replica) with BLACK bold text."""
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
    height_px = int(text_h + 2 * pad_y + 2 * frame_w)

    img = Image.new("RGBA", (width_px, height_px), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    # Frame (outer rounded rect)
    draw.rounded_rectangle(
        [0, 0, width_px - 1, height_px - 1], radius=arc,
        fill=_hex(bg), outline=_hex(frame), width=frame_w)
    # Text (centred) — BLACK (PDF sets no text color)
    tx = (width_px - text_w) // 2 - bbox[0]
    ty = (height_px - text_h) // 2 - bbox[1]
    draw.text((tx, ty), label, font=font, fill=_hex(TEXT_COLOR))
    return img


def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    for label, bg, frame, is_pill in SPECS:
        if not is_pill:
            continue
        for width_cm in WIDTHS_CM:
            img = make_pill(label, bg, frame, width_cm=width_cm)
            # width tag keeps the decimal: "1.5cm", "2cm" (matches the
            # _badge_cm lookup in docx_fix._replace_badge_runs).
            width_tag = '%gcm' % width_cm
            path = os.path.join(out_dir, 'badge-{}-{}.png'.format(label, width_tag))
            img.save(path)
            print("  {}".format(path))


if __name__ == "__main__":
    main()
