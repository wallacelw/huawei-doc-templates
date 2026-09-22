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

Labels are the exact texts the PDF renders, covering all three badge
categories: EN testbook (Pass, Partial, Fail, Skip, Blocked, Untested —
also the POC labels in English), PT POC (Atendido, Parcial, Falha,
Ignorado), and PT testbook (Aprovado, Reprovado, Bloqueado, Não testado).
Each label is generated at BOTH nominal widths — testbook
\\testresultbadge uses 1.5 cm, POC \\pocresult/\\huaweibadge uses 2 cm.
The canvas auto-fits the rendered text (mirroring tcolorbox): width =
max(text + 2*padding, nominal width), so long labels get a wider pill
instead of clipped text.  docx_fix embeds each PNG at its natural size
(pixels / 300 dpi), so badges render 1:1 with no downscaling.  There is
no NEW badge (nothing emits [NEW] since v6.5.1).
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont

DPI = 300
PT = DPI / 72.0          # points → pixels
CM = DPI / 2.54          # centimetres → pixels

FONT_PATH = "/usr/share/fonts/truetype/harmonyos/HarmonyOS_Sans_Bold.ttf"

# Badge specifications: (label, bg_hex, frame_hex, is_pill)
# Pills replicate \huaweibadge (rounded, framed, BLACK bold text — the
# PDF sets no text color).  Labels are the exact texts the PDF renders:
# EN testbook, PT POC, and PT testbook (see the module docstring).
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
    # Portuguese testbook labels (\testresultbadge, lang=pt — canonical
    # strings matching testbook.cls under [portuguese])
    ("Aprovado",    "E8F5E9", "62B230", True),
    ("Reprovado",   "FFD9D9", "C7000B", True),   # red!15 bg
    ("Bloqueado",   "FFF3E0", "ED6D00", True),
    ("Não testado", "F6F8FA", "000000", True),   # ruleblack frame
]

TEXT_COLOR = "000000"   # PDF \huaweibadge sets no text color → black
WIDTHS_CM = (1.5, 2.0)  # nominal widths: testbook 1.5cm, POC 2cm (canvas
                        # auto-fits wider when the text needs it)


def _hex(rgb_hex):
    return (int(rgb_hex[0:2], 16), int(rgb_hex[2:4], 16), int(rgb_hex[4:6], 16))


def make_pill(label, bg, frame, min_width_cm=2.0):
    """Rounded pill badge (\\huaweibadge replica) with BLACK bold text.

    Canvas auto-fits the rendered text (mirrors tcolorbox auto-sizing):
    width = max(text + 2*pad_x + 2*frame_w, min_width_cm).  min_width_cm
    is the nominal pill width (testbook 1.5cm, POC 2cm) — short labels
    keep it, long labels grow so the text fits with comfortable padding.
    """
    min_width_px = int(min_width_cm * CM)
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
    # Auto-fit canvas: text plus comfortable padding, never narrower
    # than the nominal width (a fixed 1.5cm canvas clipped "Reprovado"
    # and "Não testado").
    width_px = int(max(text_w + 2 * pad_x + 2 * frame_w, min_width_px))

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


def _text_margin_gap(img, side):
    """Count background columns between the frame and the first text pixel.

    Scans the vertical middle band (where the rounded frame runs at the
    full canvas width), starting just inside the frame band, and counts
    consecutive light (pill-background) columns until the first dark
    (text) pixel.  Independent of make_pill's layout math — a canvas
    too narrow for its text leaves no background gap.
    """
    w, h = img.size
    frame_w = max(1, int(0.8 * PT))
    skip = frame_w + 2               # frame band + anti-aliasing bleed
    y0, y1 = h // 2 - 6, h // 2 + 6  # middle band rows
    cols = (range(skip, w - skip) if side == "left"
            else range(w - 1 - skip, skip - 1, -1))
    gap = 0
    for x in cols:
        dark = False
        for y in range(y0, y1):
            r, g, b, a = img.getpixel((x, y))
            if a != 0 and (r * 299 + g * 587 + b * 114) < 200000:
                dark = True         # luminance < 200 → text pixel
                break
        if dark:
            break
        gap += 1
    return gap


def verify_badge(path, min_gap=2):
    """Reload a generated PNG and check the text clears the frame.

    Pass = at least min_gap columns of pill background between the
    frame and the text on BOTH sides (no text pixel may reach the
    canvas edges).  A fixed-width canvas that clips its text (the
    1.5cm "Não testado" regression) fails this check.
    """
    img = Image.open(path).convert("RGBA")
    left = _text_margin_gap(img, "left")
    right = _text_margin_gap(img, "right")
    return (left >= min_gap and right >= min_gap), left, right


def main():
    out_dir = os.path.dirname(os.path.abspath(__file__))
    failures = []
    for label, bg, frame, is_pill in SPECS:
        if not is_pill:
            continue
        for width_cm in WIDTHS_CM:
            img = make_pill(label, bg, frame, min_width_cm=width_cm)
            # Width tag keeps the decimal: "1.5cm", "2cm" (matches the
            # _badge_cm lookup in docx_fix._replace_badge_runs).  The
            # tag is the NOMINAL width — the canvas may be wider
            # (auto-fit); docx_fix embeds at the PNG's natural size.
            width_tag = '%gcm' % width_cm
            path = os.path.join(out_dir, 'badge-{}-{}.png'.format(label, width_tag))
            img.save(path)
            ok, gap_l, gap_r = verify_badge(path)
            print("  {:32s} {:4d}x{:3d}px  margins {}/{}px  {}".format(
                os.path.basename(path), img.size[0], img.size[1],
                gap_l, gap_r, "OK" if ok else "CLIPPED"))
            if not ok:
                failures.append(path)
    if failures:
        print("\nFAIL: badge text clipped or touching the frame in:")
        for path in failures:
            print("  " + path)
        sys.exit(1)
    print("\nAll badge PNGs verified: text fits with margin on both sides.")


if __name__ == "__main__":
    main()
