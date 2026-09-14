# Huawei Cloud Brand Guidelines — Reference & Adoption Plan

Source: *HUAWEI CLOUD BRAND GUIDELINES* V1.0 (49 pages, Adobe PDF).
This file extracts the key specifications relevant to this LaTeX template
project and compares them against the current implementation.

---

## 1. Brand Overview

### 1.1 Mission

> Ubiquitous Cloud and Pervasive Intelligence with Everything as a Service

### 1.2 Brand Interpretation

Huawei Cloud champions "Everything as a Service" — Infrastructure as a
Service, Technology as a Service, and Expertise as a Service — with AI at
the core and "AI for Industries" as the mission.

### 1.3 Key Message Houses

| House | Mission | Strategic Proposition |
|-------|---------|----------------------|
| Everything as a Service | Building the Cloud Foundation for an Intelligent World | IaaS + TaaS + EaaS |
| The AI Pioneer in Industries | Pioneering AI innovation, empowering customers | Accelerate Intelligence + Solid Foundation + Continuous Innovation + Thriving Ecosystem |

### 1.4 Slogan

> The AI Pioneer in Industries

---

## 2. Color Palette

### 2.1 Corporate Colors (Section 2.11)

| Name | Pantone | CMYK | RGB | HEX | Usage |
|------|---------|------|-----|-----|-------|
| **Huawei Red** | 185C | 0/100/100/20 | 199/0/11 | **#C7000B** | Primary brand color, all touchpoints |
| CBG Only | 186C | 27/100/86/0 | 200/16/46 | #CE0E2D | Reserved for CBG (Consumer BG) only |
| Monochrome Black | 426C | 0/0/0/100 | 0/0/0 | #000000 | Alternative icon color |

**Usage rule:** Use Huawei Red as a focal point — a single brushstroke of
vibrancy. Avoid extensive use. Emphasize key elements like titles or Huawei
lines.

### 2.2 Auxiliary Colors (Section 2.12 — Extended Palette)

This is the key section for chart, callout, and interaction design. The
corporate colors extend into a versatile spectrum with varying brightness
and saturation levels (80%, 50%, 30%).

| Name | Pantone | CMYK | RGB | HEX | Role |
|------|---------|------|-----|-----|------|
| **Rose Red** | 7636 | 15/100/43/9 | 196/0/84 | **#C40054** | Auxiliary accent |
| **Dark Red** | 483 C | 20/100/100/50 | 127/0/1 | **#7F0001** | Auxiliary accent (deep) |
| **Orange** | 165 C | 0/70/100/0 | 237/109/0 | **#ED6D00** | Warning / highlight |
| **Yellow** | 7406 C | 0/25/100/0 | 252/200/0 | **#FCC800** | Caution / attention |
| **Green** | 3501 C | 64/4/100/0 | 98/178/48 | **#62B230** | Success / tip |
| **Blue** | 2227 C | 68/0/22/5 | 48/181/197 | **#30B5C5** | Info / link |

**Rules:**
- Auxiliary colors must be used **together with** their main colors.
- Extended tints (30%, 50%, 80% brightness/saturation) are allowed and
  adjustable.
- Applicable to distinguish different functions and classification
  attributes — e.g., charts, digital interaction models, callout boxes.

### 2.3 Extended Tints (derived)

The brand guidelines show 30%, 50%, and 80% brightness/saturation variants.
For LaTeX callout backgrounds, we need light tints (~10-15% opacity) that
keep the border color readable. These are not explicitly listed in the PDF
but are derived from the main auxiliary colors:

| Auxiliary | Border (full) | Background (light tint) |
|-----------|---------------|------------------------|
| Orange | #ED6D00 | #FFF3E0 (~10% opacity) |
| Yellow | #FCC800 | #FFFDE7 (~10% opacity) |
| Green | #62B230 | #E8F5E9 (~15% opacity) |
| Blue | #30B5C5 | #E0F7FA (~12% opacity) |
| Rose Red | #C40054 | #FCE4EC (~10% opacity) |
| Dark Red | #7F0001 | #FFEBEE (~8% opacity) |

---

## 3. Typography

### 3.1 Designated Fonts (Section 2.19)

| Language | Font Family | Weights | Role |
|----------|-------------|---------|------|
| Chinese | FounderType LanTing Hei (方正兰亭黑简体) | Light, Regular, Bold | Primary corporate font |
| English | **Huawei Sans** | Light, Regular, Bold | Primary corporate font |

### 3.2 General / Fallback Fonts (Section 2.20)

Use general fonts when Huawei Sans is unavailable, illegible, or converted
(e.g., web pages, PowerPoint):

| Language | Font Family | Weights |
|----------|-------------|---------|
| Chinese | Microsoft YaHei (微软雅黑) | Light, Regular, Bold |
| English | **Arial** | Regular, Bold, Black |

### 3.3 Font Size Specifications (Section 2.21)

| Application | Size Range |
|-------------|-----------|
| Data sheets and pamphlets | 7.5–9 pt |
| Posters | 17–23 pt |
| Roll-up banners | 24–28 pt |
| General variation | ±1–2 pt allowed |

**Named sizes (Chinese → pt):**

| Name | pt | mm | px |
|------|-----|-----|-----|
| 1 inch | 72 | 25.30 | 96.6 |
| 特大号 | 63 | 22.14 | 83.7 |
| 特号 | 54 | 18.97 | 71.7 |
| 初号 | 42 | 14.82 | 56 |
| 小初 | 36 | 12.70 | 48 |
| 一号 | 26 | 9.17 | 34.7 |
| 小一 | 24 | 8.47 | 32 |
| 二号 | 22 | 7.76 | 29.3 |
| 小二 | 18 | 6.35 | 24 |
| 三号 | 16 | 5.64 | 21.3 |
| 小三 | 15 | 5.29 | 20 |
| 四号 | 14 | 4.94 | 18.7 |
| 小四 | 12 | 4.23 | 16 |
| 五号 | 10.5 | 3.70 | 14 |
| 小五 | 9 | 3.18 | 12 |
| 六号 | 7.5 | 2.56 | 10 |

---

## 4. Icon & Logo Specifications

### 4.1 Icon Proportions (Section 2.3–2.5)

- **Golden ratio** construction (1.618:1, Fibonacci-derived)
- Vertical icon: 7.6X wide × 4.7X high
- Horizontal icon: 4.8X wide × 3X high
- Angles: 56.5°, 65.5°, 113.5°

### 4.2 Minimum Sizes (Section 2.6–2.7)

| Orientation | Print (min) | Digital (min) |
|-------------|-------------|---------------|
| Vertical | 10 mm | 100 px |
| Horizontal (CN) | 12 mm | 150 px |
| Horizontal (EN) | 18 mm | 25 mm |

### 4.3 Clear Space

- 0.5X clear space around the icon (X = icon height)

### 4.4 Logo + Icon Proportions (Section 2.18)

| Version | Ratio (logo:icon:slogan) |
|---------|------------------------|
| Chinese | 1 : 1.34 : 5 |
| English | 1 : 1.5 : 6 |

### 4.5 Incorrect Use (Section 2.17)

Never: change color, change font, change kerning, compress/stretch, reorder
elements, add content, overuse as decoration, use for non-Huawei services,
place at same level as Huawei logo.

---

## 5. Application System

### 5.1 Layout Icon Sizes (Section 3.1)

| Layout | Icon Height (mm) |
|--------|-----------------|
| A5 (148×210) | 11.6 (min) |
| A4 (210×297) | 15 (CN) / 17 (EN) |
| A3 (297×420) | 21 (CN) / 24 (EN) |
| A2 (420×594) | 30 (CN) / 34 (EN) |
| A1 (594×841) | 43 (CN) / 48 (EN) |
| A0 (841×1189) | 60 (CN) / 68 (EN) |

**Formula:** Icon height = (page height + page width) / 36 × multiplier
(CN: 1.34, EN: 1.5), with ±20% adjustment allowed.

### 5.2 Framework Positions (Section 3.1.5–3.1.6)

- Huawei logo: upper left
- Huawei slogan: upper right
- Huawei Cloud icon: lower right
- Clear space: 0.5–1X above and below logo

### 5.3 Email Signature (Section 3.4.1)

| Element | Font | Size | Color |
|---------|------|------|-------|
| Name | Huawei Sans | 10.5 pt | — |
| Department | Huawei Sans | 9 pt | — |
| Contact | Huawei Sans | 9 pt | — |
| Company name | — | — | RGB 199/0/11 (Huawei Red) |
| Monochrome text | — | — | RGB 127/127/127 |

---

## 6. Comparison with Current Project

### 6.1 Colors

| Element | Current | Brand Guideline | Status |
|---------|---------|----------------|--------|
| `huaweired` | #C7000B | #C7000B (PMS 185C) | **Match** |
| `ruleblack` | #000000 | #000000 (PMS 426C) | **Match** |
| `warningfg` | #F57C00 | Orange #ED6D00 | **Close, not exact** |
| `warningbg` | #FFF8E1 | (derived tint) | **Close, not aligned** |
| `tipfg` | #2E7D32 | Green #62B230 | **Different** |
| `tipbg` | #E8F5E9 | (derived tint) | **Close** |
| `infofg` | #1565C0 | Blue #30B5C5 | **Different** |
| `infobg` | #E3F2FD | (derived tint) | **Close** |
| `codebg` | #F6F8FA | (not in guidelines) | N/A — GitHub style |
| `codetext` | #1F2328 | (not in guidelines) | N/A — GitHub style |
| `linkblue` | #0000FF | (not in guidelines) | N/A — web standard |

**Missing from project:** Rose Red #C40054, Dark Red #7F0001, Yellow #FCC800,
CBG Red #CE0E2D.

### 6.2 Fonts

| Element | Current | Brand Guideline | Status |
|---------|---------|----------------|--------|
| Main font | HarmonyOS Sans | Huawei Sans | **Name differs** — likely same font family rebranded |
| Fallback | Liberation Sans | Arial | **Compatible** — Liberation Sans is Arial-metric-compatible |
| Mono font | Cascadia Code | (not specified) | N/A |
| Body size | 10.5 pt | 10.5 pt (五号) | **Match** |

---

## 7. Adoption Plan

### Phase 1: Align Callout Colors to Brand Palette (breaking change — requires version bump)

Update `huawei-colors.sty` to use brand guideline auxiliary colors:

| Callout | Current border | New border | Current bg | New bg |
|---------|---------------|------------|------------|--------|
| Warning | #F57C00 | **#ED6D00** (Orange) | #FFF8E1 | **#FFF3E0** |
| Tip | #2E7D32 | **#62B230** (Green) | #E8F5E9 | **#E8F5E9** (keep) |
| Info | #1565C0 | **#30B5C5** (Blue) | #E3F2FD | **#E0F7FA** |

### Phase 2: Add Auxiliary Brand Colors

Add all 6 auxiliary colors + CBG red to `huawei-colors.sty` for use in
charts, diagrams, and custom styling:

```latex
\definecolor{cbgred}{HTML}{CE0E2D}      % CBG only (PMS 186C)
\definecolor{rosered}{HTML}{C40054}     % Rose Red (PMS 7636)
\definecolor{darkred}{HTML}{7F0001}     % Dark Red (PMS 483C)
\definecolor{orange}{HTML}{ED6D00}      % Orange (PMS 165C)
\definecolor{huaweiyellow}{HTML}{FCC800}% Yellow (PMS 7406C)
\definecolor{huaweigreen}{HTML}{62B230} % Green (PMS 3501C)
\definecolor{huaweiblue}{HTML}{30B5C5}  % Blue (PMS 2227C)
```

### Phase 3: Document Font Specifications

Add font size table and usage guidelines to SKILL.md and README.md.
Document that HarmonyOS Sans = Huawei Sans (consumer rebrand).

### Phase 4: Update AGENTS.md

- Update L9 to reference the brand guidelines auxiliary colors
- Add a new locked decision L20 for the auxiliary color palette
- Document the font size specifications

### Phase 5: Recompile All Outputs

- `make samples && make all-formats && make test`
- Verify all callout boxes render with new colors
- Verify DOCX/MD/HTML output matches PDF

---

## 8. Source Document Structure

| Chapter | Sections | Content |
|---------|----------|---------|
| 1.0 Brand Overview | 1.1–1.4 | Mission, interpretation, message houses |
| 2.0 Basic System | 2.1–2.21 | Icon, colors, fonts, proportions, background control |
| 3.0 Application System | 3.1–3.4 | Ads, digital media, exhibition, office |
| 4.0 Specifications | 4.1 | Contact |

**Document version:** V1.0
**Pages:** 49
