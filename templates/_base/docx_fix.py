#!/usr/bin/env python3
"""
Shared DOCX post-processing logic for Huawei document templates.

Provides two operations:
  1. --fix <file.docx>  — Post-process a pandoc-generated DOCX to fix heading
     styles, list indentation, footers, and other styling to match the PDF.
  2. <reference.docx>   — Add custom Huawei styles to a pandoc reference DOCX.

This module is imported by the thin wrapper scripts in each template directory
(templates/guide/create-guide-reference-docx.py and
templates/technical/create-technical-reference-docx.py).

Requires: python-docx (pip install python-docx)
"""

import sys
import subprocess
import re
from docx import Document
from docx.shared import Pt, Cm, Mm, RGBColor, Emu
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_TAB_ALIGNMENT
from lxml import etree


# ── Pandoc version pin ────────────────────────────────────────────────────
# The --fix post-processing depends on pandoc's XML output structure.
# The range below is the TESTED range — an out-of-range pandoc only
# warns now (builds must keep working on future releases); the loud
# style assertions catch actual structure changes.
SUPPORTED_PANDOC_RANGE = ((3, 1, 0), (3, 6, 0))  # >=3.1.0, <3.6.0

# Explicit template name, set from the --template CLI arg (the wrappers
# inject it).  None → fall back to sniffing the output path (backward
# compat for direct docx_fix.py calls).  Mirrors the pre-processor's
# _TARGET pattern.
_TEMPLATE = None

# Document language for footer label localization ("Página" vs "Page").
# Set from the --lang CLI arg (build.sh injects it from :lang:).  Defaults
# to 'en' (backward compat for direct calls / older wrappers).
_LANG = 'en'


def check_pandoc_version():
    """Warn when pandoc is outside the tested range (non-fatal).

    A hard pin would break builds on every future pandoc release; the
    loud style assertions in --fix catch actual output-structure
    changes.  Parse failures and a missing pandoc stay hard errors.
    """
    try:
        result = subprocess.run(
            ['pandoc', '--version'], capture_output=True, text=True, check=True
        )
    except FileNotFoundError:
        raise RuntimeError("pandoc not found — required for DOCX --fix version check")
    version_line = result.stdout.split('\n')[0]
    match = re.match(r'pandoc (\d+)\.(\d+)(?:\.(\d+))?', version_line)
    if not match:
        raise RuntimeError(f"Could not parse pandoc version from: {version_line}")
    major, minor = int(match.group(1)), int(match.group(2))
    patch = int(match.group(3) or 0)
    version = (major, minor, patch)
    min_ver, max_ver = SUPPORTED_PANDOC_RANGE
    if version < min_ver or version >= max_ver:
        log_warn(
            f"pandoc {major}.{minor}.{patch} is outside the tested range "
            f"({min_ver[0]}.{min_ver[1]}.{min_ver[2]}–{max_ver[0]}.{max_ver[1]}.{max_ver[2]}) "
            f"— DOCX structure may differ; proceeding"
        )


def log_warn(msg):
    """Print a warning to stderr (non-fatal, but visible)."""
    print(f"WARNING: {msg}", file=sys.stderr)


def add_or_get_paragraph_style(doc, name):
    """Get an existing paragraph style or create a new one."""
    try:
        return doc.styles[name]
    except KeyError:
        return doc.styles.add_style(name, WD_STYLE_TYPE.PARAGRAPH)


def add_or_get_character_style(doc, name):
    """Get an existing character style or create a new one."""
    try:
        return doc.styles[name]
    except KeyError:
        return doc.styles.add_style(name, WD_STYLE_TYPE.CHARACTER)


def set_cell_shading(style, color_hex):
    """Add cell/paragraph shading via OXML (pPr/shd)."""
    color_hex = color_hex.replace("#", "")
    pPr = style.element.get_or_add_pPr()
    # Remove existing shd
    for existing in pPr.findall(qn("w:shd")):
        pPr.remove(existing)
    shd = parse_xml(
        f'<w:shd {nsdecls("w")} w:fill="{color_hex}" w:val="clear"/>'
    )
    pPr.append(shd)


def set_paragraph_border(style, side, size_str, color_hex, space="1"):
    """Add a paragraph border via OXML (pPr/pBdr/<side>).

    side: 'bottom', 'top', 'left', 'right'
    size_str: e.g. '1.5pt' — parsed to eighth-points for w:sz
    color_hex: e.g. '000000'
    space: border space value (default "1" for most borders; "4" for callout left borders)
    """
    color_hex = color_hex.replace("#", "")
    size_pt = float(size_str.replace("pt", ""))
    size_eighth_pt = int(size_pt * 8)
    pPr = style.element.get_or_add_pPr()
    for existing in pPr.findall(qn("w:pBdr")):
        pPr.remove(existing)
    pBdr = parse_xml(
        f'<w:pBdr {nsdecls("w")}>'
        f'  <w:{side} w:val="single" w:sz="{size_eighth_pt}" '
        f'w:space="{space}" w:color="{color_hex}"/>'
        f'</w:pBdr>'
    )
    pPr.append(pBdr)


def set_left_border(style, color_hex, size_pt=3):
    """Add a left paragraph border via OXML (pPr/pBdr/left).

    Delegates to set_paragraph_border with space="4" for callout-style
    left borders (wider offset from paragraph edge).
    """
    set_paragraph_border(style, "left", f"{size_pt}pt", color_hex, space="4")


def set_left_indent(style, cm_value):
    """Set left indent on a paragraph style."""
    pf = style.paragraph_format
    pf.left_indent = Cm(cm_value)


def set_run_font(style, font_name, size_pt, color_hex=None, bold=False):
    """Configure font properties on a style's base run format."""
    rf = style.font
    rf.name = font_name
    rf.size = Pt(size_pt)
    if color_hex:
        rf.color.rgb = RGBColor.from_string(color_hex.replace("#", ""))
    if bold:
        rf.bold = True


def set_character_shading(style, color_hex):
    """Add run-level shading (rPr/shd) for character styles like badge."""
    color_hex = color_hex.replace("#", "")
    rPr = style.element.get_or_add_rPr()
    for existing in rPr.findall(qn("w:shd")):
        rPr.remove(existing)
    shd = parse_xml(
        f'<w:shd {nsdecls("w")} w:fill="{color_hex}" w:val="clear"/>'
    )
    rPr.append(shd)


def set_theme_fonts(doc, body_font):
    """Set the DOCX theme majorFont/minorFont and docDefaults to body_font.

    python-docx exposes no API for the theme part, so we reach into the
    package parts and mutate theme1.xml via lxml. This makes every style
    that references the theme (asciiTheme="minorHAnsi"/"majorHAnsi")
    inherit body_font, while styles with explicit rFonts (e.g. Source Code
    -> Cascadia Code) keep their explicit font.
    """
    A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"

    # 1. Find the theme part
    theme_part = None
    for part in doc.part.package.iter_parts():
        if str(part.partname) == "/word/theme/theme1.xml":
            theme_part = part
            break
    if theme_part is None:
        raise RuntimeError("word/theme/theme1.xml not found in package")

    # 2. Set majorFont + minorFont (latin, ea, cs) typeface
    root = etree.fromstring(theme_part.blob)
    font_scheme = root.find(f"{{{A_NS}}}themeElements/{{{A_NS}}}fontScheme")
    if font_scheme is None:
        raise RuntimeError("a:fontScheme not found in theme1.xml")
    for font_tag in ("majorFont", "minorFont"):
        group = font_scheme.find(f"{{{A_NS}}}{font_tag}")
        if group is None:
            continue
        for child_name in ("latin", "ea", "cs"):
            child = group.find(f"{{{A_NS}}}{child_name}")
            if child is None:
                child = etree.SubElement(group, f"{{{A_NS}}}{child_name}")
            child.set("typeface", body_font)
    theme_part._blob = etree.tostring(
        root, xml_declaration=True, encoding="UTF-8", standalone=True
    )

    # 3. Update docDefaults/rPrDefault rFonts for consistency
    dd = doc.styles.element.find(qn("w:docDefaults"))
    if dd is not None:
        rpr_default = dd.find(qn("w:rPrDefault"))
        if rpr_default is not None:
            rpr = rpr_default.find(qn("w:rPr"))
            if rpr is not None:
                rfonts = rpr.find(qn("w:rFonts"))
                if rfonts is not None:
                    for attr in ("ascii", "hAnsi", "eastAsia", "cs"):
                        rfonts.set(qn(f"w:{attr}"), body_font)


# ── Helper functions for fix_generated_docx ────────────────────────────────

def _fix_heading_styles(root, W_NS):
    """Fix Heading1-4 styles: color, font, size, spacing, borders, keep rules."""
    for heading_id in ['Heading1', 'Heading2', 'Heading3', 'Heading4']:
        style = None
        for s in root.findall(f"{{{W_NS}}}style"):
            if s.get(f"{{{W_NS}}}styleId") == heading_id:
                style = s
                break
        if style is None:
            raise RuntimeError(
                f"Expected style '{heading_id}' not found in styles.xml — "
                f"pandoc output structure may have changed"
            )

        rPr = style.find(f"{{{W_NS}}}rPr")
        if rPr is None:
            rPr = etree.SubElement(style, f"{{{W_NS}}}rPr")

        # Fix color: black for heading text (PDF uses default = black; red is only
        # for the rule below H1, handled in the Lua filter via table border)
        color = rPr.find(f"{{{W_NS}}}color")
        if color is not None:
            for attr in list(color.attrib.keys()):
                del color.attrib[attr]
            color.set(f"{{{W_NS}}}val", "1F2328")
        else:
            color = etree.SubElement(rPr, f"{{{W_NS}}}color")
            color.set(f"{{{W_NS}}}val", "1F2328")

        # Fix font: remove theme refs, set explicit
        rFonts = rPr.find(f"{{{W_NS}}}rFonts")
        if rFonts is None:
            raise RuntimeError(
                f"Expected w:rFonts in style '{heading_id}' not found in styles.xml — "
                f"pandoc output structure may have changed"
            )
        for attr in list(rFonts.attrib.keys()):
            if "Theme" in attr or "theme" in attr:
                del rFonts.attrib[attr]
        rFonts.set(f"{{{W_NS}}}ascii", "HarmonyOS Sans")
        rFonts.set(f"{{{W_NS}}}hAnsi", "HarmonyOS Sans")

        # Add bottom border to Heading 1
        # Fix bold: H2-H4 should be regular weight (matches PDF \normalfont)
        if heading_id != 'Heading1':
            for tag in ['b', 'bCs', 'i', 'iCs']:
                for elem in rPr.findall(f"{{{W_NS}}}{tag}"):
                    rPr.remove(elem)

        # Add bottom border to Heading 1
        if heading_id == 'Heading1':
            pPr = style.find(f"{{{W_NS}}}pPr")
            if pPr is None:
                pPr = etree.SubElement(style, f"{{{W_NS}}}pPr")
            for pBdr in pPr.findall(f"{{{W_NS}}}pBdr"):
                pPr.remove(pBdr)
            pBdr = etree.Element(f"{{{W_NS}}}pBdr")
            # Insert pBdr before spacing (correct OOXML schema order: pBdr before spacing)
            spacing_elem = pPr.find(f"{{{W_NS}}}spacing")
            if spacing_elem is not None:
                spacing_elem.addprevious(pBdr)
            else:
                pPr.append(pBdr)
            bottom = etree.SubElement(pBdr, f"{{{W_NS}}}bottom")
            bottom.set(f"{{{W_NS}}}val", "single")
            bottom.set(f"{{{W_NS}}}sz", "12")  # 1.5pt = 12 eighth-points
            bottom.set(f"{{{W_NS}}}space", "1")
            bottom.set(f"{{{W_NS}}}color", "C7000B")

        # Fix size (pandoc overrides reference doc sizes — restore PDF values)
        heading_sizes = {'Heading1': '40', 'Heading2': '36', 'Heading3': '32', 'Heading4': '28'}
        target_sz = heading_sizes.get(heading_id)
        if target_sz:
            for tag in ['sz', 'szCs']:
                sz = rPr.find(f"{{{W_NS}}}{tag}")
                if sz is not None:
                    sz.set(f"{{{W_NS}}}val", target_sz)
                else:
                    sz = etree.SubElement(rPr, f"{{{W_NS}}}{tag}")
                    sz.set(f"{{{W_NS}}}val", target_sz)

        # Fix heading spacing to match PDF (guide.cls titlespacing values)
        heading_spacing = {
            'Heading1': ('0', '600'),    # before=0, after=30pt
            'Heading2': ('600', '120'),  # before=30pt, after=6pt
            'Heading3': ('200', '80'),   # before=10pt, after=4pt
            'Heading4': ('160', '80'),   # before=8pt, after=4pt
        }
        target_spacing = heading_spacing.get(heading_id)
        if target_spacing:
            pPr = style.find(f"{{{W_NS}}}pPr")
            if pPr is None:
                pPr = etree.SubElement(style, f"{{{W_NS}}}pPr")
            spacing = pPr.find(f"{{{W_NS}}}spacing")
            if spacing is None:
                spacing = etree.SubElement(pPr, f"{{{W_NS}}}spacing")
            spacing.set(f"{{{W_NS}}}before", target_spacing[0])
            spacing.set(f"{{{W_NS}}}after", target_spacing[1])

        # Add keepNext and keepLines (prevents heading from separating from next paragraph)
        pPr = style.find(f"{{{W_NS}}}pPr")
        if pPr is None:
            pPr = etree.SubElement(style, f"{{{W_NS}}}pPr")
        if pPr.find(f"{{{W_NS}}}keepNext") is None:
            keep_next = etree.Element(f"{{{W_NS}}}keepNext")
            pPr.insert(0, keep_next)
        if pPr.find(f"{{{W_NS}}}keepLines") is None:
            keep_lines = etree.Element(f"{{{W_NS}}}keepLines")
            pPr.insert(1, keep_lines)

    # Fix Heading5-9: add outlineLvl, qFormat, fix font/color to match Heading1-4 pattern
    for level in range(5, 10):
        heading_id = f"Heading{level}"
        for s in root.findall(f"{{{W_NS}}}style"):
            if s.get(f"{{{W_NS}}}styleId") == heading_id:
                pPr = s.find(f"{{{W_NS}}}pPr")
                if pPr is None:
                    pPr = etree.SubElement(s, f"{{{W_NS}}}pPr")
                if pPr.find(f"{{{W_NS}}}outlineLvl") is None:
                    outline = etree.SubElement(pPr, f"{{{W_NS}}}outlineLvl")
                    outline.set(f"{{{W_NS}}}val", str(level - 1))
                if s.find(f"{{{W_NS}}}qFormat") is None:
                    etree.SubElement(s, f"{{{W_NS}}}qFormat")
                rPr = s.find(f"{{{W_NS}}}rPr")
                if rPr is None:
                    # Heading5-9 are optional styles; if they exist, rPr is expected
                    log_warn(
                        f"Style '{heading_id}' exists but has no w:rPr — "
                        f"cannot fix color/font for this heading level"
                    )
                else:
                    color = rPr.find(f"{{{W_NS}}}color")
                    if color is not None:
                        for attr in list(color.attrib.keys()):
                            del color.attrib[attr]
                        color.set(f"{{{W_NS}}}val", "1F2328")
                    rFonts = rPr.find(f"{{{W_NS}}}rFonts")
                    if rFonts is None:
                        log_warn(
                            f"Style '{heading_id}' has rPr but no w:rFonts — "
                            f"cannot fix font for this heading level"
                        )
                    else:
                        for attr in list(rFonts.attrib.keys()):
                            if "Theme" in attr or "theme" in attr:
                                del rFonts.attrib[attr]
                        rFonts.set(f"{{{W_NS}}}ascii", "HarmonyOS Sans")
                        rFonts.set(f"{{{W_NS}}}hAnsi", "HarmonyOS Sans")
                break


def _fix_title_style(root, W_NS, docx_path):
    """Fix Title style (cover page): near-black, HarmonyOS Sans.

    Size is template-conditional: technical uses 24pt (sz 48) with
    tighter spacing (PDF technical.cls title is 24pt); all other
    templates use 36pt (sz 72) with the guide.cls cover spacing.
    """
    _tmpl = _TEMPLATE or ('technical' if 'technical' in docx_path else '')
    _is_technical = (_tmpl == 'technical')
    title_found = False
    for s in root.findall(f"{{{W_NS}}}style"):
        if s.get(f"{{{W_NS}}}styleId") == "Title":
            title_found = True
            rPr = s.find(f"{{{W_NS}}}rPr")
            if rPr is None:
                raise RuntimeError(
                    "Expected w:rPr in 'Title' style not found in styles.xml — "
                    "pandoc output structure may have changed"
                )
            color = rPr.find(f"{{{W_NS}}}color")
            if color is not None:
                for attr in list(color.attrib.keys()):
                    del color.attrib[attr]
                color.set(f"{{{W_NS}}}val", "1F2328")
            rFonts = rPr.find(f"{{{W_NS}}}rFonts")
            if rFonts is None:
                raise RuntimeError(
                    "Expected w:rFonts in 'Title' style not found in styles.xml — "
                    "pandoc output structure may have changed"
                )
            for attr in list(rFonts.attrib.keys()):
                if "Theme" in attr or "theme" in attr:
                    del rFonts.attrib[attr]
            rFonts.set(f"{{{W_NS}}}ascii", "HarmonyOS Sans")
            rFonts.set(f"{{{W_NS}}}hAnsi", "HarmonyOS Sans")
            for tag in ['sz', 'szCs']:
                sz = rPr.find(f"{{{W_NS}}}{tag}")
                if sz is not None:
                    sz.set(f"{{{W_NS}}}val", "48" if _is_technical else "72")
            # Title spacing for cover page.
            # Technical (PDF technical.cls): before=28pt (~1cm gap above),
            # after=56pt (~2cm gap below).
            # Other templates (PDF guide.cls): before=62pt, after=128pt.
            pPr = s.find(f"{{{W_NS}}}pPr")
            if pPr is None:
                pPr = etree.SubElement(s, f"{{{W_NS}}}pPr")
            spacing = pPr.find(f"{{{W_NS}}}spacing")
            if spacing is None:
                spacing = etree.SubElement(pPr, f"{{{W_NS}}}spacing")
            if _is_technical:
                spacing.set(f"{{{W_NS}}}before", "560")   # 28pt
                spacing.set(f"{{{W_NS}}}after", "1132")    # 56pt
            else:
                spacing.set(f"{{{W_NS}}}before", "1248")  # 62pt
                spacing.set(f"{{{W_NS}}}after", "2560")    # 128pt
            break
    if not title_found:
        raise RuntimeError(
            "Expected style 'Title' not found in styles.xml — "
            "pandoc output structure may have changed"
        )


def _fix_verbatim_style(root, W_NS):
    """Fix VerbatimChar style: Consolas → Cascadia Code, 11pt → 10pt (matches PDF)."""
    verbatim_found = False
    for s in root.findall(f"{{{W_NS}}}style"):
        if s.get(f"{{{W_NS}}}styleId") == "VerbatimChar":
            verbatim_found = True
            rPr = s.find(f"{{{W_NS}}}rPr")
            if rPr is None:
                raise RuntimeError(
                    "Expected w:rPr in 'VerbatimChar' style not found in styles.xml — "
                    "pandoc output structure may have changed"
                )
            rFonts = rPr.find(f"{{{W_NS}}}rFonts")
            if rFonts is None:
                raise RuntimeError(
                    "Expected w:rFonts in 'VerbatimChar' style not found in styles.xml — "
                    "pandoc output structure may have changed"
                )
            rFonts.set(f"{{{W_NS}}}ascii", "Cascadia Code")
            rFonts.set(f"{{{W_NS}}}hAnsi", "Cascadia Code")
            for tag in ['sz', 'szCs']:
                sz = rPr.find(f"{{{W_NS}}}{tag}")
                if sz is not None:
                    sz.set(f"{{{W_NS}}}val", "20")
                else:
                    sz = etree.SubElement(rPr, f"{{{W_NS}}}{tag}")
                    sz.set(f"{{{W_NS}}}val", "20")
            break
    if not verbatim_found:
        raise RuntimeError(
            "Expected style 'VerbatimChar' not found in styles.xml — "
            "pandoc output structure may have changed"
        )


def _fix_source_code_style(root, W_NS):
    """Fix SourceCode style: add left/right indentation + szCs (matches PDF code block)."""
    for s in root.findall(f"{{{W_NS}}}style"):
        if s.get(f"{{{W_NS}}}styleId") == "SourceCode":
            pPr = s.find(f"{{{W_NS}}}pPr")
            if pPr is None:
                pPr = etree.Element(f"{{{W_NS}}}pPr")
                rPr = s.find(f"{{{W_NS}}}rPr")
                if rPr is not None:
                    rPr.addprevious(pPr)
                else:
                    s.append(pPr)
            ind = pPr.find(f"{{{W_NS}}}ind")
            if ind is None:
                ind = etree.SubElement(pPr, f"{{{W_NS}}}ind")
            ind.set(f"{{{W_NS}}}left", "397")   # 0.7cm
            ind.set(f"{{{W_NS}}}right", "284")   # 0.5cm
            # Add szCs for complex script consistency
            rPr = s.find(f"{{{W_NS}}}rPr")
            if rPr is None:
                raise RuntimeError(
                    "Expected w:rPr in 'SourceCode' style not found in styles.xml — "
                    "pandoc output structure may have changed"
                )
            szCs = rPr.find(f"{{{W_NS}}}szCs")
            if szCs is None:
                szCs = etree.SubElement(rPr, f"{{{W_NS}}}szCs")
            szCs.set(f"{{{W_NS}}}val", "20")
            break


def _fix_callout_spacing(root, W_NS):
    """Fix callout/code spacing, justification, and BodyText/FirstParagraph spacing."""
    # Fix callout and code style spacing: 6pt before, 6pt after (matches PDF)
    for sid in ['warning', 'tip', 'infobox', 'SourceCode']:
        for s in root.findall(f"{{{W_NS}}}style"):
            if s.get(f"{{{W_NS}}}styleId") == sid:
                pPr = s.find(f"{{{W_NS}}}pPr")
                if pPr is None:
                    pPr = etree.SubElement(s, f"{{{W_NS}}}pPr")
                spacing = pPr.find(f"{{{W_NS}}}spacing")
                if spacing is None:
                    spacing = etree.SubElement(pPr, f"{{{W_NS}}}spacing")
                spacing.set(f"{{{W_NS}}}before", "120")  # 6pt
                spacing.set(f"{{{W_NS}}}after", "120")   # 6pt
                break

    # Fix justification for custom styles (python-docx doesn't persist .alignment
    # on custom styles, so we set <w:jc> directly)
    style_jc = {
        'CoverLogo': 'center',
        'CoverText': 'center',
        'CoverMeta': 'center',
        'TOCHeading': 'right',
        'ImageBlock': 'center',
    }
    for sid, jc_val in style_jc.items():
        for s in root.findall(f"{{{W_NS}}}style"):
            if s.get(f"{{{W_NS}}}styleId") == sid:
                pPr = s.find(f"{{{W_NS}}}pPr")
                if pPr is None:
                    pPr = etree.SubElement(s, f"{{{W_NS}}}pPr")
                jc = pPr.find(f"{{{W_NS}}}jc")
                if jc is None:
                    jc = etree.SubElement(pPr, f"{{{W_NS}}}jc")
                jc.set(f"{{{W_NS}}}val", jc_val)
                break

    # Fix BodyText/FirstParagraph spacing: 4pt after, 0pt before (matches PDF parskip)
    for sid in ['BodyText', 'FirstParagraph']:
        for s in root.findall(f"{{{W_NS}}}style"):
            if s.get(f"{{{W_NS}}}styleId") == sid:
                pPr = s.find(f"{{{W_NS}}}pPr")
                if pPr is None:
                    pPr = etree.SubElement(s, f"{{{W_NS}}}pPr")
                spacing = pPr.find(f"{{{W_NS}}}spacing")
                if spacing is None:
                    spacing = etree.SubElement(pPr, f"{{{W_NS}}}spacing")
                spacing.set(f"{{{W_NS}}}after", "80")
                spacing.set(f"{{{W_NS}}}before", "0")
                break


def _fix_font_fallbacks(root, W_NS):
    """Add explicit font names alongside theme references for all styles.

    Prevents Word from falling back to Cambria when HarmonyOS Sans
    is not installed (theme refs alone don't provide a fallback name).
    """
    for style in root.findall(f"{{{W_NS}}}style"):
        style_id = style.get(f"{{{W_NS}}}styleId", "<unnamed>")
        rPr = style.find(f"{{{W_NS}}}rPr")
        if rPr is None:
            # Optional: styles with only pPr (e.g. table styles) have no rPr
            continue
        rFonts = rPr.find(f"{{{W_NS}}}rFonts")
        if rFonts is None:
            # Optional: some styles have rPr but no rFonts (e.g. only sz/color)
            continue
        if rFonts.get(f"{{{W_NS}}}asciiTheme") and not rFonts.get(f"{{{W_NS}}}ascii"):
            rFonts.set(f"{{{W_NS}}}ascii", "HarmonyOS Sans")
        if rFonts.get(f"{{{W_NS}}}hAnsiTheme") and not rFonts.get(f"{{{W_NS}}}hAnsi"):
            rFonts.set(f"{{{W_NS}}}hAnsi", "HarmonyOS Sans")


def _fix_normal_style(root, W_NS):
    """Fix Normal style: 10.5pt (sz=21) to match PDF body text (10.5pt/14pt leading)."""
    normal_found = False
    for s in root.findall(f"{{{W_NS}}}style"):
        if s.get(f"{{{W_NS}}}styleId") == "Normal":
            normal_found = True
            rPr = s.find(f"{{{W_NS}}}rPr")
            if rPr is None:
                rPr = etree.SubElement(s, f"{{{W_NS}}}rPr")
            for tag in ['sz', 'szCs']:
                sz = rPr.find(f"{{{W_NS}}}{tag}")
                if sz is not None:
                    sz.set(f"{{{W_NS}}}val", "21")
                else:
                    sz = etree.SubElement(rPr, f"{{{W_NS}}}{tag}")
                    sz.set(f"{{{W_NS}}}val", "21")
            pPr = s.find(f"{{{W_NS}}}pPr")
            if pPr is None:
                pPr = etree.SubElement(s, f"{{{W_NS}}}pPr")
            spacing = pPr.find(f"{{{W_NS}}}spacing")
            if spacing is None:
                spacing = etree.SubElement(pPr, f"{{{W_NS}}}spacing")
            spacing.set(f"{{{W_NS}}}after", "80")
            spacing.set(f"{{{W_NS}}}line", "280")
            spacing.set(f"{{{W_NS}}}lineRule", "atLeast")
            break
    if not normal_found:
        raise RuntimeError(
            "Expected style 'Normal' not found in styles.xml — "
            "pandoc output structure may have changed"
        )


def _fix_doc_defaults(root, W_NS):
    """Fix docDefaults: 10.5pt (sz=21), spacing after=80 (4pt parskip)."""
    docDefaults = root.find(f"{{{W_NS}}}docDefaults")
    if docDefaults is None:
        raise RuntimeError(
            "Expected w:docDefaults not found in styles.xml — "
            "pandoc output structure may have changed"
        )
    rPrDefault = docDefaults.find(f"{{{W_NS}}}rPrDefault")
    if rPrDefault is None:
        raise RuntimeError(
            "Expected w:rPrDefault not found in docDefaults — "
            "pandoc output structure may have changed"
        )
    rPr = rPrDefault.find(f"{{{W_NS}}}rPr")
    if rPr is None:
        raise RuntimeError(
            "Expected w:rPr not found in rPrDefault — "
            "pandoc output structure may have changed"
        )
    for tag in ['sz', 'szCs']:
        sz = rPr.find(f"{{{W_NS}}}{tag}")
        if sz is not None:
            sz.set(f"{{{W_NS}}}val", "21")
        else:
            sz = etree.SubElement(rPr, f"{{{W_NS}}}{tag}")
            sz.set(f"{{{W_NS}}}val", "21")
    pPrDefault = docDefaults.find(f"{{{W_NS}}}pPrDefault")
    if pPrDefault is None:
        raise RuntimeError(
            "Expected w:pPrDefault not found in docDefaults — "
            "pandoc output structure may have changed"
        )
    pPr = pPrDefault.find(f"{{{W_NS}}}pPr")
    if pPr is None:
        raise RuntimeError(
            "Expected w:pPr not found in pPrDefault — "
            "pandoc output structure may have changed"
        )
    spacing = pPr.find(f"{{{W_NS}}}spacing")
    if spacing is None:
        raise RuntimeError(
            "Expected w:spacing not found in pPrDefault pPr — "
            "pandoc output structure may have changed"
        )
    spacing.set(f"{{{W_NS}}}after", "80")
    spacing.set(f"{{{W_NS}}}line", "280")
    spacing.set(f"{{{W_NS}}}lineRule", "atLeast")


def _add_badge_style(root, W_NS):
    """Add/fix badge character style (red pill, white bold text).

    PDF: bg=huaweired, white bold footnotesize (8pt).
    """
    badge_style = None
    for s in root.findall(f"{{{W_NS}}}style"):
        if s.get(f"{{{W_NS}}}styleId") == "badge":
            badge_style = s
            break
    if badge_style is None:
        badge_style = etree.SubElement(root, f"{{{W_NS}}}style")
        badge_style.set(f"{{{W_NS}}}type", "character")
        badge_style.set(f"{{{W_NS}}}styleId", "badge")
        etree.SubElement(badge_style, f"{{{W_NS}}}name").set(f"{{{W_NS}}}val", "Badge")
        etree.SubElement(badge_style, f"{{{W_NS}}}uiPriority").set(f"{{{W_NS}}}val", "99")
    # Ensure rPr with bold + white text + red bg + 8pt + HarmonyOS Sans
    rPr = badge_style.find(f"{{{W_NS}}}rPr")
    if rPr is None:
        rPr = etree.SubElement(badge_style, f"{{{W_NS}}}rPr")
    rf = rPr.find(f"{{{W_NS}}}rFonts")
    if rf is None:
        rf = etree.SubElement(rPr, f"{{{W_NS}}}rFonts")
    rf.set(f"{{{W_NS}}}ascii", "HarmonyOS Sans")
    rf.set(f"{{{W_NS}}}hAnsi", "HarmonyOS Sans")
    if rPr.find(f"{{{W_NS}}}b") is None:
        etree.SubElement(rPr, f"{{{W_NS}}}b")
    color = rPr.find(f"{{{W_NS}}}color")
    if color is None:
        color = etree.SubElement(rPr, f"{{{W_NS}}}color")
    color.set(f"{{{W_NS}}}val", "FFFFFF")
    shd = rPr.find(f"{{{W_NS}}}shd")
    if shd is None:
        shd = etree.SubElement(rPr, f"{{{W_NS}}}shd")
    shd.set(f"{{{W_NS}}}val", "clear")
    shd.set(f"{{{W_NS}}}color", "auto")
    shd.set(f"{{{W_NS}}}fill", "C7000B")
    for tag in ['sz', 'szCs']:
        elem = rPr.find(f"{{{W_NS}}}{tag}")
        if elem is None:
            elem = etree.SubElement(rPr, f"{{{W_NS}}}{tag}")
        elem.set(f"{{{W_NS}}}val", "16")  # 8pt


# Badge style definitions: (style_id, bg_color, fg_color)
# Fallback character styles (used when the PNG asset is missing).  BG
# matches the pill background; text is BLACK (PDF \huaweibadge sets no
# text color).  These mirror the generate-badges.py SPECS.
RESULT_BADGE_STYLES = [
    ("BadgePass",     "E8F5E9", "000000"),   # green bg, black text
    ("BadgePartial",  "FFF3E0", "000000"),   # orange bg, black text
    ("BadgeFail",     "E7D9DA", "000000"),   # red!15 bg, black text (was C7000B/FFFFFF)
    ("BadgeSkip",     "F6F8FA", "000000"),   # gray bg, black text
    ("BadgeBlocked",  "FFF3E0", "000000"),   # orange bg, black text
    ("BadgeUntested", "F6F8FA", "000000"),   # gray bg, black text
]

# Map marker text → style_id.  Keys are title-case (PDF label case) plus
# the Portuguese POC labels (\pocresult, lang=pt).
BADGE_MARKERS = {
    "[Pass]": "BadgePass",
    "[Partial]": "BadgePartial",
    "[Fail]": "BadgeFail",
    "[Skip]": "BadgeSkip",
    "[Blocked]": "BadgeBlocked",
    "[Untested]": "BadgeUntested",
    # Portuguese POC labels (\pocresult, lang=pt)
    "[Atendido]": "BadgePass",
    "[Parcial]": "BadgePartial",
    "[Falha]": "BadgeFail",
    "[Ignorado]": "BadgeSkip",
}

# Badge text sentinel from the pre-processor: **[BADGE:text]** arrives as
# a bold run "[BADGE:text]".  docx_fix restores the text and applies the
# flat red "badge" character style (PDF \badge replica: red bg, white
# bold 8pt, auto width).
BADGE_SENTINEL_RE = re.compile(r'^\[BADGE:(.*)\]$')


def _add_result_badge_styles(root, W_NS):
    """Add individual result badge character styles (green/red/orange/gray)."""
    for style_id, bg, fg in RESULT_BADGE_STYLES:
        s = None
        for existing in root.findall(f"{{{W_NS}}}style"):
            if existing.get(f"{{{W_NS}}}styleId") == style_id:
                s = existing
                break
        if s is None:
            s = etree.SubElement(root, f"{{{W_NS}}}style")
            s.set(f"{{{W_NS}}}type", "character")
            s.set(f"{{{W_NS}}}styleId", style_id)
            etree.SubElement(s, f"{{{W_NS}}}name").set(
                f"{{{W_NS}}}val", style_id)
            etree.SubElement(s, f"{{{W_NS}}}uiPriority").set(
                f"{{{W_NS}}}val", "99")
        rPr = s.find(f"{{{W_NS}}}rPr")
        if rPr is None:
            rPr = etree.SubElement(s, f"{{{W_NS}}}rPr")
        rf = rPr.find(f"{{{W_NS}}}rFonts")
        if rf is None:
            rf = etree.SubElement(rPr, f"{{{W_NS}}}rFonts")
        rf.set(f"{{{W_NS}}}ascii", "HarmonyOS Sans")
        rf.set(f"{{{W_NS}}}hAnsi", "HarmonyOS Sans")
        if rPr.find(f"{{{W_NS}}}b") is None:
            etree.SubElement(rPr, f"{{{W_NS}}}b")
        color = rPr.find(f"{{{W_NS}}}color")
        if color is None:
            color = etree.SubElement(rPr, f"{{{W_NS}}}color")
        color.set(f"{{{W_NS}}}val", fg)
        shd = rPr.find(f"{{{W_NS}}}shd")
        if shd is None:
            shd = etree.SubElement(rPr, f"{{{W_NS}}}shd")
        shd.set(f"{{{W_NS}}}val", "clear")
        shd.set(f"{{{W_NS}}}color", "auto")
        shd.set(f"{{{W_NS}}}fill", bg)
        for tag in ['sz', 'szCs']:
            elem = rPr.find(f"{{{W_NS}}}{tag}")
            if elem is None:
                elem = etree.SubElement(rPr, f"{{{W_NS}}}{tag}")
            elem.set(f"{{{W_NS}}}val", "16")  # 8pt


# Testcase field labels (en/pt) — these paragraphs get the red header
# bar look (PDF testbook.cls: \colorbox{huaweired} with white bold label)
FIELD_LABELS = {
    'Objective', 'Test Scope', 'Prerequisites', 'Procedure',
    'Expected Result', 'Test Result', 'Remarks',
    'Objetivo', 'Escopo do Teste', 'Pré-requisitos', 'Procedimento',
    'Resultado Esperado', 'Resultado do Teste', 'Observações',
}


def _resize_drawing(paragraph, qn, width_cm):
    """Scale the first drawing in *paragraph* to *width_cm*, keeping aspect."""
    emu_per_cm = 360000
    target_cx = int(width_cm * emu_per_cm)
    drawing = paragraph._p.find('.//' + qn('w:drawing'))
    if drawing is None:
        return
    # wp:extent lives inside wp:inline/wp:anchor, not directly under w:drawing
    extent = drawing.find('.//' + qn('wp:extent'))
    if extent is None:
        return
    try:
        cx = int(extent.get('cx', '0'))
        cy = int(extent.get('cy', '0'))
    except (TypeError, ValueError):
        return
    if cx <= 0 or cy <= 0:
        return
    new_cy = int(cy * target_cx / cx)
    extent.set('cx', str(target_cx))
    extent.set('cy', str(new_cy))
    # Keep the inner shape transform (a:ext) in sync with the outer extent
    for ext in drawing.findall('.//' + qn('a:ext')):
        try:
            if int(ext.get('cx', '0')) == cx:
                ext.set('cx', str(target_cx))
                ext.set('cy', str(new_cy))
        except (TypeError, ValueError):
            continue


def _assemble_cover(doc, qn, docx_path):
    """Reorder + style the cover region to match the PDF.

    Non-technical (guide/poc/testbook — huawei-cover.sty):
        Pandoc order: Title, Author(s), Date, [logo, cover text, meta]...
        PDF order:    Title, logo (3.6cm), cover text, Author(s), meta.
        The date paragraph is deleted — the meta line carries the date.

    Technical (technical.cls):
        Pandoc order: Title, [logo, type label, version table, meta]...
        PDF order:    Title, logo (3.6cm), type label (16pt red bold),
                      version table (red label column), meta.
        Author paragraphs are deleted — authors live inside the version
        table (the preprocessor adds the Author row when :authors: is set).
    """
    _tmpl = _TEMPLATE or ('technical' if 'technical' in docx_path else '')
    _is_technical = (_tmpl == 'technical')

    paras = list(doc.paragraphs)
    title_p = next((p for p in paras if p.style.style_id == 'Title'), None)
    if title_p is None:
        return

    def is_boundary(p):
        sid = p.style.style_id or ''
        return sid.startswith('Heading') or sid.startswith('TOC')

    # Logo = first paragraph with a drawing in the cover region
    logo_p = None
    for p in paras:
        if p is title_p:
            continue
        if is_boundary(p):
            break
        if p._p.find('.//' + qn('w:drawing')) is not None:
            logo_p = p
            break
    if logo_p is None:
        return  # pre-processor did not inject a cover block

    idx = paras.index(logo_p)
    cover_text_p = paras[idx + 1] if idx + 1 < len(paras) else None

    # Date paragraphs: scan the full cover region (pandoc emits Date
    # before the logo, in the metadata block).
    # Meta line ("vX — date time"): scan only paragraphs AFTER the logo
    # (author names before the logo could false-match ^v\S+; the meta is
    # injected after the logo).  Pattern ^v\S+ matches both v1.0.0 and
    # vHCS 8.5.1.
    meta_p = None
    date_ps = []
    for p in paras:
        if p is title_p:
            continue
        if is_boundary(p):
            break
        if re.match(r'^\d{4}-\d{2}-\d{2}$', p.text.strip()):
            date_ps.append(p)
    for p in paras[idx:]:
        if is_boundary(p):
            break
        if re.match(r'^v\S+', p.text.strip()):
            meta_p = p

    # Subtitle (docbook splits 'Title: Subtitle') — merge back into the
    # title, matching the PDF which uses the full doctitle as one line.
    subtitle_p = None
    for p in paras:
        if p is title_p:
            continue
        if p is logo_p or is_boundary(p):
            break
        if (p.style.style_id or '') == 'Subtitle':
            subtitle_p = p
            break
    if subtitle_p is not None:
        sub_text = subtitle_p.text
        if sub_text:
            title_p.add_run(': ' + sub_text)
        subtitle_p._p.getparent().remove(subtitle_p._p)

    # Author paragraphs: between title and logo in pandoc order
    author_ps = []
    for p in paras:
        if p is title_p:
            continue
        if p is logo_p or is_boundary(p):
            break
        if p in date_ps or p is subtitle_p:
            continue
        if p.text.strip():
            author_ps.append(p)

    # Delete the redundant date paragraph(s)
    for p in date_ps:
        p._p.getparent().remove(p._p)

    # Cover table (technical only): first w:tbl between logo and the
    # first boundary paragraph in document order.
    cover_table = None
    if _is_technical:
        body_children = list(doc.element.body)
        logo_el_idx = body_children.index(logo_p._p)
        for tbl in doc.tables:
            tbl_idx = body_children.index(tbl._tbl)
            if tbl_idx <= logo_el_idx:
                continue
            # Only accept a table before the first boundary paragraph
            # (Heading/TOC) — a body table must never be hijacked into
            # the cover.
            intervening = False
            for el in body_children[logo_el_idx + 1:tbl_idx]:
                if el.tag == qn('w:p'):
                    pPr = el.find(qn('w:pPr'))
                    if pPr is not None:
                        pStyle = pPr.find(qn('w:pStyle'))
                        if pStyle is not None:
                            sid = pStyle.get(qn('w:val'), '')
                            if sid.startswith('Heading') or sid.startswith('TOC'):
                                intervening = True
                                break
            if not intervening:
                cover_table = tbl
                break

    # Chain-reorder: title -> logo -> [type label] -> [table] -> [authors] -> meta.
    # Pandoc places the TOC before body content, so without this the
    # meta line (and authors/table) would land on the wrong page.
    anchor = title_p._element
    chain = [logo_p]
    if cover_text_p is not None:
        chain.append(cover_text_p)
    if _is_technical and cover_table is not None:
        chain.append(cover_table)
    if not _is_technical:
        chain.extend(author_ps)
    if meta_p is not None:
        chain.append(meta_p)
    for el in chain:
        anchor.addnext(el._element)
        anchor = el._element

    # Technical: delete pandoc author paragraphs (authors live in the
    # version table, added by the preprocessor).
    if _is_technical:
        for p in author_ps:
            p._p.getparent().remove(p._p)

    # Styling (PDF huawei-cover.sty: 3.6cm logo, 16pt cover text,
    # 12pt authors, 12pt meta with bold version run)
    logo_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    _resize_drawing(logo_p, qn, width_cm=3.6)
    if cover_text_p is not None:
        cover_text_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for run in cover_text_p.runs:
            if _is_technical:
                # Type label: 16pt bold red (PDF technical.cls)
                run.font.size = Pt(16)
                run.font.bold = True
                run.font.color.rgb = RGBColor(0xC7, 0x00, 0x0B)
            else:
                run.font.size = Pt(16)
    for p in author_ps:
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for run in p.runs:
            run.font.size = Pt(12)
    if meta_p is not None:
        meta_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        for run in meta_p.runs:
            run.font.size = Pt(12)

    # Technical cover table: center + red label column + black grid.
    if _is_technical and cover_table is not None:
        from docx.shared import RGBColor as _RGB
        from docx.enum.table import WD_TABLE_ALIGNMENT
        cover_table.alignment = WD_TABLE_ALIGNMENT.CENTER
        # Black full-grid borders (mirror _style_table's plain-grid path)
        tbl = cover_table._element
        tblPr = tbl.find(qn('w:tblPr'))
        if tblPr is None:
            tblPr = etree.SubElement(tbl, qn('w:tblPr'))
            tbl.insert(0, tblPr)
        tblBorders = tblPr.find(qn('w:tblBorders'))
        if tblBorders is None:
            tblBorders = etree.SubElement(tblPr, qn('w:tblBorders'))
        for border_name in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
            border = tblBorders.find(qn(f'w:{border_name}'))
            if border is None:
                border = etree.SubElement(tblBorders, qn(f'w:{border_name}'))
            border.set(qn('w:val'), 'single')
            border.set(qn('w:sz'), '4')
            border.set(qn('w:space'), '0')
            border.set(qn('w:color'), '000000')
        # First-column cells: red bg + white bold text (PDF label column)
        for row in cover_table.rows:
            cell = row.cells[0]
            tcPr = cell._tc.get_or_add_tcPr()
            shd = tcPr.find(qn('w:shd'))
            if shd is None:
                shd = etree.SubElement(tcPr, qn('w:shd'))
            shd.set(qn('w:val'), 'clear')
            shd.set(qn('w:color'), 'auto')
            shd.set(qn('w:fill'), 'C7000B')
            for paragraph in cell.paragraphs:
                for run in paragraph.runs:
                    run.font.bold = True
                    run.font.color.rgb = _RGB(0xFF, 0xFF, 0xFF)


def _style_testcase_blocks(doc, qn):
    """Draw the PDF testcase tcolorbox: red left rule around each block.

    The pre-processor emits TESTCASE-START/TESTCASE-END marker
    paragraphs.  Markers are deleted; every paragraph between them gets
    a 3pt red left border (PDF testbook.cls: tcolorbox leftrule=3pt,
    colframe=huaweired).  Field label paragraphs get the red header bar
    look (white bold on C7000B), and step-number runs turn red
    (PDF: \\textcolor{huaweired}{\\bfseries N.}).
    """
    paras = list(doc.paragraphs)

    # Pair START/END markers
    ranges = []
    start_p = None
    for p in paras:
        t = p.text.strip()
        if t == 'TESTCASE-START':
            start_p = p
        elif t == 'TESTCASE-END' and start_p is not None:
            ranges.append((start_p, p))
            start_p = None
    if not ranges:
        return

    # pPr children that must follow pBdr (OOXML schema order)
    after_pbdr = (
        'w:shd', 'w:tabs', 'w:suppressAutoHyphens', 'w:kinsoku',
        'w:wordWrap', 'w:overflowPunct', 'w:topLinePunct',
        'w:autoSpaceDE', 'w:autoSpaceDN', 'w:bidi', 'w:adjustRightInd',
        'w:snapToGrid', 'w:spacing', 'w:ind', 'w:contextualSpacing',
        'w:mirrorIndents', 'w:suppressOverlap', 'w:jc',
        'w:textDirection', 'w:textAlignment', 'w:textboxTightWrap',
        'w:outlineLvl', 'w:divId', 'w:cnfStyle', 'w:rPr', 'w:sectPr',
        'w:pPrChange',
    )

    def add_left_border(p):
        pPr = p._p.get_or_add_pPr()
        pBdr = pPr.find(qn('w:pBdr'))
        if pBdr is None:
            pBdr = OxmlElement('w:pBdr')
            anchor = None
            for tag in after_pbdr:
                el = pPr.find(qn(tag))
                if el is not None:
                    anchor = el
                    break
            if anchor is not None:
                anchor.addprevious(pBdr)
            else:
                pPr.append(pBdr)
        left = pBdr.find(qn('w:left'))
        if left is None:
            left = etree.SubElement(pBdr, qn('w:left'))
        left.set(qn('w:val'), 'single')
        left.set(qn('w:sz'), '24')      # 3pt — PDF leftrule=3pt
        left.set(qn('w:space'), '4')
        left.set(qn('w:color'), 'C7000B')

    def add_shading(p, fill):
        pPr = p._p.get_or_add_pPr()
        shd = pPr.find(qn('w:shd'))
        if shd is None:
            shd = OxmlElement('w:shd')
            pBdr = pPr.find(qn('w:pBdr'))
            if pBdr is not None:
                pBdr.addnext(shd)
            else:
                pPr.append(shd)
        shd.set(qn('w:val'), 'clear')
        shd.set(qn('w:color'), 'auto')
        shd.set(qn('w:fill'), fill)

    red = RGBColor(0xC7, 0x00, 0x0B)
    white = RGBColor(0xFF, 0xFF, 0xFF)
    for start_p, end_p in ranges:
        s = paras.index(start_p)
        e = paras.index(end_p)
        for p in paras[s + 1:e]:
            add_left_border(p)
            t = p.text.strip()
            if t in FIELD_LABELS:
                add_shading(p, 'C7000B')
                for run in p.runs:
                    run.font.bold = True
                    run.font.color.rgb = white
                # PDF: \par\medskip before the header bar, \smallskip after
                p.paragraph_format.space_before = Pt(8)
                p.paragraph_format.space_after = Pt(4)
            elif p.runs and re.match(r'^\d+\.$', p.runs[0].text.strip()):
                # Red bold step number (PDF: red bold "N.")
                p.runs[0].font.color.rgb = red
                # PDF: \par\smallskip between steps
                p.paragraph_format.space_before = Pt(6)
            elif (p.style.style_id or '') == 'SourceCode':
                # Code block inside a testcase (PDF: codebg box with
                # codeborder inside the tcolorbox).  The SourceCode style
                # indents left=397 twips — that jogs the red left rule,
                # so reset indents to keep the rule continuous; add the
                # code box top/bottom/right borders (codeborder #E1E4E8),
                # keeping the red left border.  Shading (codebg #F6F8FA)
                # comes from the style.
                p.paragraph_format.left_indent = Pt(0)
                p.paragraph_format.right_indent = Pt(0)
                pPr = p._p.get_or_add_pPr()
                pBdr = pPr.find(qn('w:pBdr'))
                if pBdr is not None:
                    left_b = pBdr.find(qn('w:left'))
                    top_b = pBdr.find(qn('w:top'))
                    if top_b is None:
                        top_b = OxmlElement('w:top')
                        pBdr.insert(0, top_b)
                    bottom_b = pBdr.find(qn('w:bottom'))
                    if bottom_b is None:
                        bottom_b = OxmlElement('w:bottom')
                        if left_b is not None:
                            left_b.addnext(bottom_b)
                        else:
                            pBdr.append(bottom_b)
                    right_b = pBdr.find(qn('w:right'))
                    if right_b is None:
                        right_b = OxmlElement('w:right')
                        bottom_b.addnext(right_b)
                    # Schema order inside pBdr: top, left, bottom, right
                    for el in (top_b, bottom_b, right_b):
                        el.set(qn('w:val'), 'single')
                        el.set(qn('w:sz'), '4')       # 0.5pt — codeborder
                        el.set(qn('w:space'), '4')
                        el.set(qn('w:color'), 'E1E4E8')
            elif t:
                # Content paragraphs (objective/scope/result/remarks text)
                p.paragraph_format.space_after = Pt(6)
        # Remove the markers
        start_p._p.getparent().remove(start_p._p)
        end_p._p.getparent().remove(end_p._p)


def _strip_testcase_markers(docx_path):
    """Delete TESTCASE-START/END marker paragraphs (idempotent).

    Safety net for the fail-loud content-styling path: even when
    _apply_content_styling raises, markers can never ship in a DOCX.
    Mirrors _style_testcase_blocks (body paragraphs — markers are never
    emitted inside table cells).  No-op when no markers are present, so
    the happy path (markers already deleted by styling) rewrites nothing.
    """
    doc = Document(docx_path)
    doomed = [p for p in doc.paragraphs
              if p.text.strip() in ('TESTCASE-START', 'TESTCASE-END')]
    if not doomed:
        return
    for p in doomed:
        p._element.getparent().remove(p._element)
    doc.save(docx_path)


def _apply_content_styling(docx_path):
    """Apply content styling that mirrors the PDF.

    - Badge character styles for [Pass]/[Fail]/... markers
    - Hutable table styling (red header row, alternating rows, red grid)
    - Page break before each Heading 1 (PDF: \\clearpage before \\section)
    - Centered testcase captions (PDF renders them as centered captions)
    - Cover version line under the title (PDF cover shows version + date)

    Called after styles.xml is written.  Uses python-docx high-level APIs
    for run/paragraph properties so elements are inserted in schema order —
    raw lxml appends can violate the OOXML sequence and make strict
    consumers (LibreOffice) silently drop the formatting.
    """
    import re as _re
    from docx import Document
    from docx.shared import Pt, RGBColor
    from docx.oxml.ns import qn

    doc = Document(docx_path)

    # --- Update fields on open (Word populates the TOC field automatically) ---
    settings = doc.settings.element
    if settings.find(qn('w:updateFields')) is None:
        update_fields = etree.SubElement(settings, qn('w:updateFields'))
        update_fields.set(qn('w:val'), 'true')

    # --- Heading 1: PDF style — big number left, title right, red rule ---
    # PDF (huawei-titles.sty): 56pt section number left-aligned, \hfill
    # pushes the 20pt bold title to the right edge, red titlerule below
    # (the style's bottom border provides the rule).  Pandoc emits the
    # number as a SectionNumber run + tab + title run — a right tab stop
    # at the text width makes the tab act as the \hfill.
    section = doc.sections[0]
    text_width = section.page_width - section.left_margin - section.right_margin
    for style in doc.styles:
        if style.style_id == 'Heading1':
            style.paragraph_format.page_break_before = True
            style.paragraph_format.tab_stops.add_tab_stop(
                text_width, WD_TAB_ALIGNMENT.RIGHT)
            break
    for style in doc.styles:
        if style.style_id == 'SectionNumber':
            style.font.size = Pt(56)
            break

    # --- Badge styling: [Pass]/[Fail]/... → inline PNG images ---
    # Replaces the flat character-styled text with rounded pill PNGs that
    # replicate the PDF \huaweibadge look (arc=2pt, colored bg + 0.8pt
    # frame, BLACK bold text — the PDF sets no text color).  PNGs are
    # pre-rendered at native width per template (testbook 1.5cm, POC 2cm)
    # so no downscaling is needed.  Falls back to character styles if a
    # PNG asset is missing.
    import os
    _badge_dir = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), 'badge-assets')
    # POC result badges use the 2cm \huaweibadge default; testbook's
    # \testresultbadge uses 1.5cm.  Template comes from --template
    # (wrappers inject it); direct calls fall back to sniffing the path.
    _tmpl = _TEMPLATE or ('poc' if 'poc' in docx_path else '')
    _badge_cm = '2' if _tmpl == 'poc' else '1.5'
    _badge_w = Cm(2.0) if _tmpl == 'poc' else Cm(1.5)

    def _replace_badge_runs(paragraphs):
        for paragraph in paragraphs:
            for run in paragraph.runs:
                text = run.text.strip()
                # **[BADGE:text]** sentinel → restore text, flat red badge
                m = BADGE_SENTINEL_RE.match(text)
                if m:
                    run.text = m.group(1)
                    for st in doc.styles:
                        if st.style_id == 'badge':
                            run.style = st
                            break
                    continue
                if text not in BADGE_MARKERS:
                    continue
                style_id = BADGE_MARKERS[text]
                label = text[1:-1]   # the badge text, e.g. Pass/Atendido
                png = os.path.join(_badge_dir, 'badge-{}-{}cm.png'.format(label, _badge_cm))
                if os.path.isfile(png):
                    run.text = ''
                    run.add_picture(png, width=_badge_w)
                else:
                    try:
                        run.style = doc.styles[style_id]
                    except KeyError:
                        pass

    _replace_badge_runs(doc.paragraphs)
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                _replace_badge_runs(cell.paragraphs)

    # --- Table styling (hutable vs plain grid) ---
    for table in doc.tables:
        _style_table(table, qn)

    # --- Captions: match the PDF caption systems ---
    # All captions are centered in the PDF (\caption, \imagecap,
    # \diagramcap, and the testcase caption all render centered).
    # Table/Figure use \small (9pt) via captionsetup; Diagram/Testcase
    # use body size.  The bold symbol run comes from **Table N:** markup.
    # Vertical rhythm: \par\medskip + parskip above, caption-package
    # spacing below (huawei-fonts.sty sets \parskip=4pt).
    cap_pat = _re.compile(
        r'^(Table|Tabela|Figure|Figura|Diagram|Diagrama'
        r'|Testcase|Caso de Teste) \d+:')
    for paragraph in doc.paragraphs:
        m = cap_pat.match(paragraph.text.strip())
        if not m:
            continue
        kind = m.group(1)
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        if kind in ('Table', 'Tabela', 'Figure', 'Figura'):
            for run in paragraph.runs:
                run.font.size = Pt(9)
        paragraph.paragraph_format.space_before = Pt(12)
        paragraph.paragraph_format.space_after = Pt(8)

    # --- Testcase blocks: red left rule + red field bars (PDF tcolorbox) ---
    _style_testcase_blocks(doc, qn)

    # --- Cover: logo + cover text + meta line (PDF huawei-cover.sty) ---
    _assemble_cover(doc, qn, docx_path)

    doc.save(docx_path)


def _style_table(table, qn):
    """Style a table to match its PDF counterpart.

    Header tables (pandoc marks them with w:tblHeader on row 0) get the
    hutable look: red full-grid borders, red header row with white bold
    text, alternating #F6F8FA body rows.  Plain grids without a header
    row (e.g. signatures) get neutral black rules only — matching the
    PDF's plain tabular with \\hline.
    """
    from docx.shared import RGBColor

    tbl = table._element
    tblPr = tbl.find(qn('w:tblPr'))
    if tblPr is None:
        tblPr = etree.SubElement(tbl, qn('w:tblPr'))
        tbl.insert(0, tblPr)

    # Detect header row (pandoc emits w:tblHeader in the thead row's trPr)
    has_header = False
    if len(table.rows) > 0:
        trPr = table.rows[0]._tr.find(qn('w:trPr'))
        if trPr is not None and trPr.find(qn('w:tblHeader')) is not None:
            has_header = True

    border_color = 'C7000B' if has_header else '000000'

    # Full-grid borders.  Schema order: tblBorders must precede
    # tblLook/tblCaption, so reposition after creation when needed.
    tblBorders = tblPr.find(qn('w:tblBorders'))
    if tblBorders is None:
        tblBorders = etree.SubElement(tblPr, qn('w:tblBorders'))
        anchor = None
        for tag in ('w:tblLook', 'w:tblCaption', 'w:tblDescription'):
            el = tblPr.find(qn(tag))
            if el is not None:
                anchor = el
                break
        if anchor is not None:
            anchor.addprevious(tblBorders)
    for border_name in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
        border = tblBorders.find(qn(f'w:{border_name}'))
        if border is None:
            border = etree.SubElement(tblBorders, qn(f'w:{border_name}'))
        border.set(qn('w:val'), 'single')
        border.set(qn('w:sz'), '4')  # 0.5pt
        border.set(qn('w:space'), '0')
        border.set(qn('w:color'), border_color)

    def shade_cell(cell, fill):
        tcPr = cell._tc.get_or_add_tcPr()
        shd = tcPr.find(qn('w:shd'))
        if shd is None:
            shd = etree.SubElement(tcPr, qn('w:shd'))
        shd.set(qn('w:val'), 'clear')
        shd.set(qn('w:color'), 'auto')
        shd.set(qn('w:fill'), fill)

    if has_header:
        # Header row: red background, white bold text
        for cell in table.rows[0].cells:
            shade_cell(cell, 'C7000B')
            for paragraph in cell.paragraphs:
                for run in paragraph.runs:
                    run.font.bold = True
                    run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
        # Alternating body rows (2nd, 4th, ... data rows get #F6F8FA)
        for i, row in enumerate(table.rows):
            if i == 0 or i % 2 != 0:
                continue
            for cell in row.cells:
                shade_cell(cell, 'F6F8FA')


def _fix_toc_styles(root, W_NS):
    """Fix TOC1/TOC2/TOC3 + TOCHeading styles (Word built-in TOC entry styles)."""
    toc_configs = [
        ("TOC1", "0",   "9"),
        ("TOC2", "420", "9"),
        ("TOC3", "840", "9"),
    ]
    for toc_id, indent, ui_pri in toc_configs:
        has_toc = any(s.get(f"{{{W_NS}}}styleId") == toc_id for s in root.findall(f"{{{W_NS}}}style"))
        if not has_toc:
            ts = etree.SubElement(root, f"{{{W_NS}}}style")
            ts.set(f"{{{W_NS}}}type", "paragraph")
            ts.set(f"{{{W_NS}}}styleId", toc_id)
            etree.SubElement(ts, f"{{{W_NS}}}name").set(f"{{{W_NS}}}val", toc_id.lower())
            etree.SubElement(ts, f"{{{W_NS}}}basedOn").set(f"{{{W_NS}}}val", "Normal")
            etree.SubElement(ts, f"{{{W_NS}}}next").set(f"{{{W_NS}}}val", "Normal")
            etree.SubElement(ts, f"{{{W_NS}}}uiPriority").set(f"{{{W_NS}}}val", ui_pri)
            etree.SubElement(ts, f"{{{W_NS}}}qFormat")
            pPr = etree.SubElement(ts, f"{{{W_NS}}}pPr")
            tabs = etree.SubElement(pPr, f"{{{W_NS}}}tabs")
            tab = etree.SubElement(tabs, f"{{{W_NS}}}tab")
            tab.set(f"{{{W_NS}}}val", "right")
            tab.set(f"{{{W_NS}}}leader", "dot")
            tab.set(f"{{{W_NS}}}pos", "9638")  # content text width in twips (matches H1 tab stop)
            etree.SubElement(pPr, f"{{{W_NS}}}ind").set(f"{{{W_NS}}}left", indent)
            sp = etree.SubElement(pPr, f"{{{W_NS}}}spacing")
            sp.set(f"{{{W_NS}}}after", "40")  # 2pt

    # Style TOC heading: 22pt bold + bottom rule (matches PDF)
    toc_heading = None
    for s in root.findall(f"{{{W_NS}}}style"):
        if s.get(f"{{{W_NS}}}styleId") == "TOCHeading":
            toc_heading = s
            break
    if toc_heading is None:
        toc_heading = etree.SubElement(root, f"{{{W_NS}}}style")
        toc_heading.set(f"{{{W_NS}}}type", "paragraph")
        toc_heading.set(f"{{{W_NS}}}styleId", "TOCHeading")
        etree.SubElement(toc_heading, f"{{{W_NS}}}name").set(f"{{{W_NS}}}val", "toc heading")
    rPr = toc_heading.find(f"{{{W_NS}}}rPr")
    if rPr is None:
        rPr = etree.SubElement(toc_heading, f"{{{W_NS}}}rPr")
    # Remove existing bold/bCs (pandoc sets w:b w:val="0" which overrides)
    for tag in ['b', 'bCs']:
        for elem in rPr.findall(f"{{{W_NS}}}{tag}"):
            rPr.remove(elem)
    etree.SubElement(rPr, f"{{{W_NS}}}b")  # bold = true
    # Fix color: remove theme refs, set black
    color = rPr.find(f"{{{W_NS}}}color")
    if color is not None:
        rPr.remove(color)
    color = etree.SubElement(rPr, f"{{{W_NS}}}color")
    color.set(f"{{{W_NS}}}val", "1F2328")
    # Fix font: remove theme refs, set explicit
    rFonts = rPr.find(f"{{{W_NS}}}rFonts")
    if rFonts is not None:
        for attr in list(rFonts.attrib.keys()):
            if "Theme" in attr or "theme" in attr:
                del rFonts.attrib[attr]
        rFonts.set(f"{{{W_NS}}}ascii", "HarmonyOS Sans")
        rFonts.set(f"{{{W_NS}}}hAnsi", "HarmonyOS Sans")
    # 22pt (sz=44)
    sz = rPr.find(f"{{{W_NS}}}sz")
    if sz is None:
        sz = etree.SubElement(rPr, f"{{{W_NS}}}sz")
    sz.set(f"{{{W_NS}}}val", "44")
    szCs = rPr.find(f"{{{W_NS}}}szCs")
    if szCs is None:
        szCs = etree.SubElement(rPr, f"{{{W_NS}}}szCs")
    szCs.set(f"{{{W_NS}}}val", "44")
    # Bottom border (0.5pt black rule) + right alignment (PDF huawei-toc.sty)
    pPr = toc_heading.find(f"{{{W_NS}}}pPr")
    if pPr is None:
        pPr = etree.SubElement(toc_heading, f"{{{W_NS}}}pPr")
    jc = pPr.find(f"{{{W_NS}}}jc")
    if jc is None:
        jc = etree.SubElement(pPr, f"{{{W_NS}}}jc")
    jc.set(f"{{{W_NS}}}val", "right")
    pBdr = pPr.find(f"{{{W_NS}}}pBdr")
    if pBdr is None:
        pBdr = etree.SubElement(pPr, f"{{{W_NS}}}pBdr")
    bottom = pBdr.find(f"{{{W_NS}}}bottom")
    if bottom is None:
        bottom = etree.SubElement(pBdr, f"{{{W_NS}}}bottom")
    bottom.set(f"{{{W_NS}}}val", "single")
    bottom.set(f"{{{W_NS}}}sz", "4")  # 0.5pt
    bottom.set(f"{{{W_NS}}}space", "1")
    bottom.set(f"{{{W_NS}}}color", "000000")


def _fix_list_indentation(docx_path, W_NS):
    """Fix list indentation in numbering.xml (match PDF 1.6em/1.8em).

    Returns modified numbering.xml bytes, or None if numbering.xml is absent.
    """
    import zipfile
    modified_numbering = None
    with zipfile.ZipFile(docx_path, 'r') as z:
        if 'word/numbering.xml' in z.namelist():
            numbering_xml = z.read('word/numbering.xml')
            num_root = etree.fromstring(numbering_xml)
            # PDF: itemize leftmargin=1.6em ≈ 336tw, enumerate=1.8em ≈ 378tw
            # Word: left=text position, hanging=distance to bullet
            # Use left=480/hanging=240 for level 0 (text at 0.85cm, bullet at 0.42cm)
            indent_configs = [
                (0, "480", "240"),   # level 0: text=480tw, bullet=240tw
                (1, "960", "240"),   # level 1: text=960tw, bullet=720tw
                (2, "1440", "240"),  # level 2: text=1440tw, bullet=1200tw
            ]
            for lvl_num, left_val, hang_val in indent_configs:
                for lvl in num_root.iter(f"{{{W_NS}}}lvl"):
                    if lvl.get(f"{{{W_NS}}}ilvl") == str(lvl_num):
                        # w:ind is inside w:pPr inside w:lvl
                        ind = lvl.find(f"{{{W_NS}}}pPr/{{{W_NS}}}ind")
                        if ind is None:
                            raise RuntimeError(
                                f"Expected w:ind in numbering.xml level {lvl_num} "
                                f"not found — pandoc output structure may have changed"
                            )
                        ind.set(f"{{{W_NS}}}left", left_val)
                        ind.set(f"{{{W_NS}}}hanging", hang_val)
            modified_numbering = etree.tostring(
                num_root, xml_declaration=True, encoding="UTF-8", standalone=True
            )
        else:
            # numbering.xml is genuinely optional — only present if document has lists
            log_warn(
                "word/numbering.xml not found in DOCX — "
                "list indentation fix skipped (document may have no lists)"
            )
    return modified_numbering


# ── Main fix function ─────────────────────────────────────────────────────

def fix_generated_docx(docx_path):
    """Post-process a pandoc-generated DOCX to fix heading styles.

    Pandoc overrides the reference doc's Heading styles with its own defaults
    (blue accent1 color, no border). This fixes them to match the PDF:
    near-black text, red bottom border on H1.

    Bypasses python-docx entirely — modifies styles.xml in the zip directly,
    because python-docx's save() overwrites any part blob modifications.

    Raises RuntimeError if expected XML elements are missing (pandoc output
    structure has changed).  An out-of-range pandoc version only warns.
    """
    check_pandoc_version()
    import zipfile, shutil
    W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

    # TESTCASE markers are stripped on every exit path of the ENTIRE fix
    # run — styles phase, zip rewrite, and content styling alike — so a
    # failure at any stage can no longer leave them in the DOCX.  The
    # strip is idempotent, and on a styles-phase failure the file on
    # disk is pristine pandoc output, so Document() opens fine.
    try:
        with zipfile.ZipFile(docx_path, 'r') as z:
            styles_xml = z.read('word/styles.xml')

        root = etree.fromstring(styles_xml)

        # Remove duplicate styleIds (keep first occurrence, remove subsequent)
        # python-docx's BabelFish lookup can create duplicates; this ensures a clean styles.xml
        seen_ids = set()
        for s in root.findall(f"{{{W_NS}}}style"):
            sid = s.get(f"{{{W_NS}}}styleId")
            if sid:
                if sid in seen_ids:
                    root.remove(s)
                else:
                    seen_ids.add(sid)

        _fix_heading_styles(root, W_NS)
        _fix_title_style(root, W_NS, docx_path)
        _fix_verbatim_style(root, W_NS)
        _fix_source_code_style(root, W_NS)
        _fix_callout_spacing(root, W_NS)
        _fix_font_fallbacks(root, W_NS)
        _fix_normal_style(root, W_NS)
        _fix_doc_defaults(root, W_NS)
        _add_badge_style(root, W_NS)
        _add_result_badge_styles(root, W_NS)
        _fix_toc_styles(root, W_NS)

        modified_xml = etree.tostring(
            root, xml_declaration=True, encoding="UTF-8", standalone=True
        )

        # Fix list indentation in numbering.xml
        modified_numbering = _fix_list_indentation(docx_path, W_NS)

        # Footer with page number (pandoc doesn't carry over reference
        # footer).  Page label follows the PDF (\lg@pagelabel): "Página"
        # for pt, "Page" otherwise.
        _page_label = 'Página ' if _LANG == 'pt' else 'Page '
        footer_xml = (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r\n'
            '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
            '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>'
            '<w:r><w:rPr><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
            '<w:t xml:space="preserve">' + _page_label + '</w:t></w:r>'
            '<w:r><w:rPr><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
            '<w:fldChar w:fldCharType="begin"/></w:r>'
            '<w:r><w:rPr><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
            '<w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
            '<w:r><w:rPr><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>'
            '<w:fldChar w:fldCharType="end"/></w:r>'
            '</w:p></w:ftr>'
        )

        tmp_path = docx_path + '.tmp'
        with zipfile.ZipFile(docx_path, 'r') as zin:
            with zipfile.ZipFile(tmp_path, 'w', zipfile.ZIP_DEFLATED) as zout:
                for item in zin.infolist():
                    if item.filename == 'word/styles.xml':
                        zout.writestr(item, modified_xml)
                    elif item.filename == 'word/numbering.xml' and modified_numbering is not None:
                        zout.writestr(item, modified_numbering)
                    elif item.filename.startswith('word/footer') and item.filename.endswith('.xml'):
                        zout.writestr(item, footer_xml)
                    else:
                        zout.writestr(item, zin.read(item.filename))
        shutil.move(tmp_path, docx_path)

        # Apply badge character styles and hutable table styling to
        # document content.  Failures are loud (non-zero exit).
        _apply_content_styling(docx_path)
    finally:
        _strip_testcase_markers(docx_path)

    print(f"✓ Fixed heading styles in {docx_path}")


def regenerate_reference(docx_path):
    """Add custom Huawei styles to a pandoc reference DOCX.

    This is the "Step 2" operation: take a base reference DOCX generated
    by `pandoc --print-default-data-file reference.docx` and add all the
    custom Huawei styles (callouts, code, cover, TOC, etc.).
    """
    doc = Document(docx_path)

    # ── Warning callout ──────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "warning")
    set_left_border(style, "ED6D00", size_pt=3)
    set_cell_shading(style, "FFF3E0")
    set_left_indent(style, 0.5)

    # ── Tip callout ──────────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "tip")
    set_left_border(style, "62B230", size_pt=3)
    set_cell_shading(style, "E8F5E9")
    set_left_indent(style, 0.5)

    # ── Info callout ─────────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "infobox")
    set_left_border(style, "30B5C5", size_pt=3)
    set_cell_shading(style, "E0F7FA")
    set_left_indent(style, 0.5)

    # ── Objectives block ─────────────────────────────────────────────
    add_or_get_paragraph_style(doc, "objectives")

    # ── Changelog section ────────────────────────────────────────────
    add_or_get_paragraph_style(doc, "changelog")

    # ── Huawei table ─────────────────────────────────────────────────
    add_or_get_paragraph_style(doc, "hutable")

    # ── Source Code ──────────────────────────────────────────────────
    style = add_or_get_paragraph_style(doc, "Source Code")
    set_cell_shading(style, "F6F8FA")
    set_run_font(style, "Cascadia Code", 10, color_hex="1F2328")

    # ── Badge (character style) ──────────────────────────────────────
    style = add_or_get_character_style(doc, "badge")
    set_character_shading(style, "C7000B")
    set_run_font(style, "HarmonyOS Sans", 9, color_hex="FFFFFF", bold=True)

    # ── CoverLogo (paragraph style) ───────────────────────────────────
    style = add_or_get_paragraph_style(doc, "CoverLogo")
    style.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pf = style.paragraph_format
    pf.space_before = Pt(10)
    pf.space_after = Pt(10)

    # ── CoverText (paragraph style) ──────────────────────────────────
    style = add_or_get_paragraph_style(doc, "CoverText")
    style.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pf = style.paragraph_format
    pf.space_before = Pt(30)
    pf.space_after = Pt(10)
    set_run_font(style, "HarmonyOS Sans", 16, color_hex="1F2328")

    # ── CoverMeta (paragraph style) ──────────────────────────────────
    style = add_or_get_paragraph_style(doc, "CoverMeta")
    style.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pf = style.paragraph_format
    pf.space_before = Pt(5)
    pf.space_after = Pt(10)
    set_run_font(style, "HarmonyOS Sans", 12, color_hex="595959")

    # ── ImageBlock (paragraph style) ─────────────────────────────────
    style = add_or_get_paragraph_style(doc, "ImageBlock")
    style.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pf = style.paragraph_format
    pf.space_before = Pt(6)
    pf.space_after = Pt(6)

    # ── ObjectivesRule (paragraph style) ─────────────────────────────
    style = add_or_get_paragraph_style(doc, "ObjectivesRule")
    pf = style.paragraph_format
    pf.space_before = Pt(4)
    pf.space_after = Pt(10)
    set_paragraph_border(style, "bottom", "1.5pt", "000000")

    # NOTE: Heading 1-4 styles are NOT modified here. python-docx's BabelFish
    # lookup fails on pandoc's reference DOCX (case sensitivity), creating
    # duplicate styleIds. All heading style fixes are handled by
    # fix_generated_docx() which modifies styles.xml directly.

    # ── Title (cover page) — 36pt, near-black, bold, centered (matches PDF) ──
    try:
        title_style = doc.styles["Title"]
    except KeyError:
        title_style = doc.styles.add_style("Title", WD_STYLE_TYPE.PARAGRAPH)
    set_run_font(title_style, "HarmonyOS Sans", 36, color_hex="1F2328", bold=True)

    # ── Verbatim Char — Cascadia Code (matches PDF code font) ──────────────
    try:
        vc_style = doc.styles["Verbatim Char"]
    except KeyError:
        vc_style = doc.styles.add_style("Verbatim Char", WD_STYLE_TYPE.CHARACTER)
    set_run_font(vc_style, "Cascadia Code", 11, color_hex="1F2328")

    # ── Hyperlink ────────────────────────────────────────────────────
    try:
        hl = doc.styles["Hyperlink"]
    except KeyError:
        hl = doc.styles.add_style("Hyperlink", WD_STYLE_TYPE.CHARACTER)
    set_run_font(hl, "HarmonyOS Sans", 10.5, color_hex="0000FF")
    # Remove underline via OXML
    rPr = hl.element.get_or_add_rPr()
    for existing in rPr.findall(qn("w:u")):
        rPr.remove(existing)
    u_elem = parse_xml(f'<w:u {nsdecls("w")} w:val="none"/>')
    rPr.append(u_elem)

    # ── Theme + default fonts: HarmonyOS Sans for all body/heading text ──
    set_theme_fonts(doc, "HarmonyOS Sans")

    # ── Page layout: A4, margins 3/3/2/2 cm (matches PDF \geometry) ──────
    section = doc.sections[0]
    section.page_width = Mm(210)
    section.page_height = Mm(297)
    section.top_margin = Cm(3)
    section.bottom_margin = Cm(3)
    section.left_margin = Cm(2)
    section.right_margin = Cm(2)

    # Different first page: cover page has no header/footer
    section.different_first_page_header_footer = True

    # ── Header: document title via STYLEREF field (10pt, centered) ────────
    # STYLEREF "Title" automatically shows the text of the first paragraph
    # with the Title style — no need to know the title at build time.
    header = section.header
    header.is_linked_to_previous = False
    hp = header.paragraphs[0]
    hp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in list(hp.runs):
        run._element.getparent().remove(run._element)
    for run in [hp.add_run(), hp.add_run(), hp.add_run(), hp.add_run("Document Title"), hp.add_run()]:
        run.font.size = Pt(10)
        run.font.name = "HarmonyOS Sans"
    # Field: STYLEREF "Title"
    fld_begin = OxmlElement('w:fldChar')
    fld_begin.set(qn('w:fldCharType'), 'begin')
    hp.runs[0]._r.append(fld_begin)
    instr = OxmlElement('w:instrText')
    instr.set(qn('xml:space'), 'preserve')
    instr.text = ' STYLEREF "Title" \\* MERGEFORMAT '
    hp.runs[1]._r.append(instr)
    fld_sep = OxmlElement('w:fldChar')
    fld_sep.set(qn('w:fldCharType'), 'separate')
    hp.runs[2]._r.append(fld_sep)
    fld_end = OxmlElement('w:fldChar')
    fld_end.set(qn('w:fldCharType'), 'end')
    hp.runs[4]._r.append(fld_end)

    # ── Footer: page number (10pt, centered) ──────────────────────────────
    footer = section.footer
    footer.is_linked_to_previous = False
    fp = footer.paragraphs[0]
    fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in list(fp.runs):
        run._element.getparent().remove(run._element)
    for run in [fp.add_run(), fp.add_run(), fp.add_run()]:
        run.font.size = Pt(10)
        run.font.name = "HarmonyOS Sans"
    # Field: PAGE
    fld_begin = OxmlElement('w:fldChar')
    fld_begin.set(qn('w:fldCharType'), 'begin')
    fp.runs[0]._r.append(fld_begin)
    instr = OxmlElement('w:instrText')
    instr.set(qn('xml:space'), 'preserve')
    instr.text = ' PAGE '
    fp.runs[1]._r.append(instr)
    fld_end = OxmlElement('w:fldChar')
    fld_end.set(qn('w:fldCharType'), 'end')
    fp.runs[2]._r.append(fld_end)

    # ── Save ─────────────────────────────────────────────────────────
    doc.save(docx_path)
    print(f"✓ Huawei styles added to {docx_path}")


def main(argv=None, reference_name=None):
    """Entry point for the DOCX fix script.

    Args:
        argv: Command-line arguments (list of strings). Defaults to sys.argv[1:].
        reference_name: Default reference DOCX filename (e.g. 'guide-reference.docx').
            Used when no filename argument is provided.
    """
    global _TEMPLATE
    global _LANG
    _TEMPLATE = None  # reset between in-process main() calls
    _LANG = 'en'      # reset between in-process main() calls
    if argv is None:
        argv = sys.argv[1:]

    # --template <name> — explicit template (the wrappers inject it so
    # badge sizing no longer sniffs the output path).  Direct calls
    # without --template fall back to path sniffing (backward compat).
    # --lang en|pt — document language for footer label localization
    # (build.sh injects it from the :lang: header attribute).
    args = []
    i = 0
    while i < len(argv):
        # Accept --template=VALUE and --lang=VALUE (equals form)
        if argv[i].startswith('--template='):
            tmpl = argv[i].split('=', 1)[1]
            if tmpl not in ('poc', 'testbook', 'guide', 'technical'):
                print(f"error: unknown template: {tmpl} "
                      "(expected poc|testbook|guide|technical)")
                sys.exit(1)
            _TEMPLATE = tmpl
            i += 1
            continue
        if argv[i].startswith('--lang='):
            lang_val = argv[i].split('=', 1)[1]
            if lang_val not in ('en', 'pt'):
                print(f"error: unknown lang: {lang_val} (expected en|pt)")
                sys.exit(1)
            _LANG = lang_val
            i += 1
            continue
        if argv[i] == '--template':
            if i + 1 >= len(argv):
                print("error: --template requires a value "
                      "(poc|testbook|guide|technical)")
                sys.exit(1)
            tmpl = argv[i + 1]
            if tmpl not in ('poc', 'testbook', 'guide', 'technical'):
                print(f"error: unknown template: {tmpl} "
                      "(expected poc|testbook|guide|technical)")
                sys.exit(1)
            _TEMPLATE = tmpl
            i += 2
            continue
        if argv[i] == '--lang':
            if i + 1 >= len(argv):
                print("error: --lang requires a value (en|pt)")
                sys.exit(1)
            lang_val = argv[i + 1]
            if lang_val not in ('en', 'pt'):
                print(f"error: unknown lang: {lang_val} (expected en|pt)")
                sys.exit(1)
            _LANG = lang_val
            i += 2
            continue
        args.append(argv[i])
        i += 1
    argv = args

    if len(argv) >= 1 and argv[0] == "--fix":
        if len(argv) < 2:
            print(f"Usage: {sys.argv[0]} --fix <generated.docx>")
            sys.exit(1)
        fix_generated_docx(argv[1])
        return
    if len(argv) < 1:
        if reference_name:
            print(f"Usage: {sys.argv[0]} --fix <generated.docx>")
            print(f"       {sys.argv[0]} {reference_name}")
        else:
            print(f"Usage: {sys.argv[0]} --fix <generated.docx>")
            print(f"       {sys.argv[0]} <reference.docx>")
        sys.exit(1)

    docx_path = argv[0]
    regenerate_reference(docx_path)


if __name__ == "__main__":
    main()
