#!/usr/bin/env python3
"""Pre-processor for DOCX generation.

Transforms .adoc passthrough blocks (raw LaTeX) and custom roles to
AsciiDoc-native syntax before `asciidoctor -b docbook` conversion,
so content survives into DOCX output.

Usage:
    python3 adoc_docx_preprocessor.py --template poc input.adoc -o output.adoc
    python3 adoc_docx_preprocessor.py --template testbook input.adoc -o output.adoc
"""

import re
import sys
import argparse

# ---------------------------------------------------------------------------
# Language-aware labels
# ---------------------------------------------------------------------------

LABELS = {
    'en': {
        'homologated': 'Homologated',
        'with_reservations': 'With reservations',
        'not_homologated': 'Not homologated',
        'objective': 'Objective',
        'scope': 'Test Scope',
        'prerequisites': 'Prerequisites',
        'procedure': 'Procedure',
        'expected': 'Expected Result',
        'result': 'Test Result',
        'remarks': 'Remarks',
        'test_case': 'Test Case',
        'sincerely': 'Sincerely,',
    },
    'pt': {
        'homologated': 'Homologada',
        'with_reservations': 'Com ressalvas',
        'not_homologated': 'Não homologada',
        'objective': 'Objetivo',
        'scope': 'Escopo do Teste',
        'prerequisites': 'Pré-requisitos',
        'procedure': 'Procedimento',
        'expected': 'Resultado Esperado',
        'result': 'Resultado do Teste',
        'remarks': 'Observações',
        'test_case': 'Caso de Teste',
        'sincerely': 'Atenciosamente,',
    },
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def extract_brace_arg(text, start):
    """Extract a {...} argument starting just after the opening '{'.

    Handles nested braces.  Returns (arg, end_pos) where *end_pos* is
    the index just past the closing '}'.
    """
    depth = 1
    i = start
    while i < len(text) and depth > 0:
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
        i += 1
    return text[start:i - 1], i


def find_cmd(text, command, start=0):
    """Find \\command{arg} in *text* (nested braces supported).

    Returns (arg, cmd_start, after_arg) or *None*.
    """
    pattern = '\\' + command + '{'
    pos = text.find(pattern, start)
    if pos == -1:
        return None
    arg_start = pos + len(pattern)
    arg, end_pos = extract_brace_arg(text, arg_start)
    return arg, pos, end_pos


def find_cmd_2args(text, command, start=0):
    """Find \\command{arg1}{arg2} (nested braces supported)."""
    r = find_cmd(text, command, start)
    if r is None:
        return None
    arg1, cmd_start, after_first = r
    if after_first >= len(text) or text[after_first] != '{':
        return None
    arg2, end_pos = extract_brace_arg(text, after_first + 1)
    return arg1, arg2, cmd_start, end_pos


def clean_ws(text):
    """Collapse whitespace runs and strip."""
    return re.sub(r'\s+', ' ', text).strip()


# ---------------------------------------------------------------------------
# Inline LaTeX → AsciiDoc
# ---------------------------------------------------------------------------

def convert_inline_latex(text, lang='en'):
    """Convert inline LaTeX commands to AsciiDoc inline formatting."""
    labels = LABELS.get(lang, LABELS['en'])

    # Order matters: escape sequences first, then commands
    text = text.replace(r'\textbackslash', '\\')
    text = text.replace(r'\_', '_')
    text = text.replace(r'\&', '&')
    text = text.replace(r'\%', '%')
    text = text.replace(r'\#', '#')
    text = text.replace(r'\$', '$')

    # Math symbols
    text = text.replace(r'$\rightarrow$', '\u2192')   # →
    text = text.replace(r'$\geq$', '\u2265')           # ≥
    text = text.replace(r'$\leq$', '\u2264')           # ≤
    text = text.replace(r'$>$', '>')
    text = text.replace(r'$<$', '<')
    text = text.replace(r'$\neq$', '\u2260')           # ≠

    # POC classification labels
    text = text.replace(r'\pochomologated', labels['homologated'])
    text = text.replace(r'\pocwithreservations', labels['with_reservations'])
    text = text.replace(r'\pocnothomologated', labels['not_homologated'])

    # \testresultbadge{X} → **[X]**
    text = re.sub(
        r'\\testresultbadge\{([^}]*)\}',
        lambda m: '**[' + m.group(1).upper() + ']**',
        text,
    )

    # \textbf{text} → **text**  (handle nested braces)
    text = _replace_cmd(text, 'textbf', lambda arg: '**' + arg + '**')
    # \inlinecode{text} → `text`
    text = _replace_cmd(text, 'inlinecode', lambda arg: '`' + arg + '`')
    # \param{text} → *text*
    text = _replace_cmd(text, 'param', lambda arg: '*' + arg + '*')
    # \note{text} → *text*
    text = _replace_cmd(text, 'note', lambda arg: '*' + arg + '*')
    # \checkbox{label} → ☐ label
    text = _replace_cmd(text, 'checkbox', lambda arg: '\u2610 ' + arg)
    # \seqsplit{text} → text
    text = _replace_cmd(text, 'seqsplit', lambda arg: arg)
    # \textcolor{color}{text} → text
    text = _replace_cmd_2args(text, 'textcolor', lambda _c, arg: arg)
    # \weblink{url}{text} → link:url[text]
    text = _replace_cmd_2args(text, 'weblink', lambda url, txt: 'link:' + url + '[' + txt + ']')

    # \menu{A, B, C} → **A** → **B** → **C**
    def menu_replacer(m):
        items = [item.strip() for item in m.group(1).split(',')]
        return ' \u2192 '.join('**' + item + '**' for item in items)
    text = re.sub(r'\\menu\{([^}]*)\}', menu_replacer, text)

    # \rule{2cm}{4pt} → ■ (color swatch placeholder)
    text = re.sub(r'\\rule\{[^}]*\}\{[^}]*\}', '\u25a0', text)

    return text


def _replace_cmd(text, command, replacer):
    """Replace \\command{arg} using *replacer(arg)*, handling nested braces."""
    result = []
    pos = 0
    while True:
        r = find_cmd(text, command, pos)
        if r is None:
            result.append(text[pos:])
            break
        arg, cmd_start, after_arg = r
        result.append(text[pos:cmd_start])
        result.append(replacer(arg))
        pos = after_arg
    return ''.join(result)


def _replace_cmd_2args(text, command, replacer):
    """Replace \\command{arg1}{arg2} using *replacer(arg1, arg2)*."""
    result = []
    pos = 0
    while True:
        r = find_cmd_2args(text, command, pos)
        if r is None:
            result.append(text[pos:])
            break
        arg1, arg2, cmd_start, after_arg = r
        result.append(text[pos:cmd_start])
        result.append(replacer(arg1, arg2))
        pos = after_arg
    return ''.join(result)


# ---------------------------------------------------------------------------
# POC passthrough handlers
# ---------------------------------------------------------------------------

def convert_stakeholders(content, lang):
    r"""Convert \begin{stakeholders}...\end{stakeholders} to AsciiDoc table."""
    lines = ['[.hutable]', '|===', '| Name | Email | Phone | Role', '']
    for line in content.split('\n'):
        line = line.strip()
        if not line:
            continue
        m = re.match(r'\\stakeholderorg\{([^}]*)\}', line)
        if m:
            org = convert_inline_latex(m.group(1), lang)
            lines.append('4+| *' + org + '*')
            continue
        m = re.match(
            r'\\stakeholderrow\{([^}]*)\}\{([^}]*)\}\{([^}]*)\}\{([^}]*)\}',
            line,
        )
        if m:
            vals = [convert_inline_latex(m.group(i), lang) for i in range(1, 5)]
            lines.append('| ' + ' | '.join(vals))
            continue
    lines.append('|===')
    return '\n'.join(lines)


def convert_closingrecord(content, lang):
    r"""Convert \begin{closingrecord}...\end{closingrecord} to AsciiDoc table."""
    lines = ['[.hutable]', '|===', '| Item | Record', '']
    for line in content.split('\n'):
        line = line.strip()
        if not line:
            continue
        r = find_cmd_2args(line, 'closingrow')
        if r is not None:
            label, value, _, _ = r
            label = convert_inline_latex(label, lang)
            value = convert_inline_latex(value, lang)
            lines.append('| ' + label + ' | ' + value)
    lines.append('|===')
    return '\n'.join(lines)


def convert_signatures(content, lang):
    r"""Convert \begin{signatures}...\end{signatures} to AsciiDoc table."""
    labels = LABELS.get(lang, LABELS['en'])
    lines = ['[cols="1,1"]', '|===']
    for line in content.split('\n'):
        line = line.strip()
        if not line or line.startswith(r'\begin') or line.startswith(r'\end'):
            continue
        # Split on & to get signature cells
        parts = line.split('&')
        cells = []
        for part in parts:
            part = part.strip()
            # Strip trailing \\ \hline
            part = re.sub(r'\\\\\s*\\hline\s*$', '', part).strip()
            sig_pos = part.find(r'\signaturecell')
            if sig_pos != -1:
                # Parse four {...} args after \signaturecell
                args = []
                p = sig_pos + len(r'\signaturecell')
                for _ in range(4):
                    if p < len(part) and part[p] == '{':
                        arg, p = extract_brace_arg(part, p + 1)
                        args.append(arg)
                    else:
                        args.append('')
                        break
                if len(args) < 4:
                    continue
                name = convert_inline_latex(args[0], lang)
                title = convert_inline_latex(args[1], lang)
                email = convert_inline_latex(args[2], lang)
                address = convert_inline_latex(args[3], lang)
                cell = (
                    labels['sincerely'] + '\n+\n'
                    + name + '\n+\n' + title + '\n+\n'
                    + 'E-mail: `' + email + '`\n+\n' + address
                )
                cells.append(cell)
        if cells:
            lines.append('| ' + cells[0] + '\n| ' + cells[1])
    lines.append('|===')
    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# Testbook passthrough handlers
# ---------------------------------------------------------------------------

_testcase_counter = 0


def convert_testcase(content, lang):
    r"""Convert \begin{testcase}{Title}...\end{testcase} to AsciiDoc section."""
    global _testcase_counter
    _testcase_counter += 1
    tc_num = _testcase_counter
    labels = LABELS.get(lang, LABELS['en'])

    # Extract title
    m = re.match(r'\\begin\{testcase\}\{([^}]*)\}', content.strip())
    title = m.group(1) if m else 'Untitled'
    title = convert_inline_latex(title, lang)

    # Get inner content (between \begin{testcase}{...} and \end{testcase})
    inner = content
    inner = re.sub(r'^\s*\\begin\{testcase\}\{[^}]*\}\s*', '', inner)
    inner = re.sub(r'\s*\\end\{testcase\}\s*$', '', inner)

    out = []
    out.append('=== ' + labels['test_case'] + ' ' + str(tc_num) + ': ' + title)
    out.append('')

    # Process inner content
    _process_testcase_inner(inner, lang, labels, out)

    return '\n'.join(out)


def _process_testcase_inner(inner, lang, labels, out):
    """Process the content inside a testcase environment."""
    pos = 0
    while pos < len(inner):
        # Skip whitespace
        while pos < len(inner) and inner[pos] in ' \t\n':
            pos += 1
        if pos >= len(inner):
            break

        # \testobjective{text}
        if inner.startswith(r'\testobjective{', pos):
            r = find_cmd(inner, 'testobjective', pos)
            if r:
                arg, _, after = r
                out.append('**' + labels['objective'] + ':** '
                           + convert_inline_latex(arg.strip(), lang))
                out.append('')
                pos = after
                continue

        # \testscope{text}
        if inner.startswith(r'\testscope{', pos):
            r = find_cmd(inner, 'testscope', pos)
            if r:
                arg, _, after = r
                out.append('**' + labels['scope'] + ':** '
                           + convert_inline_latex(arg.strip(), lang))
                out.append('')
                pos = after
                continue

        # \testresult{...}
        if inner.startswith(r'\testresult{', pos):
            r = find_cmd(inner, 'testresult', pos)
            if r:
                arg, _, after = r
                badge = convert_inline_latex(arg.strip(), lang)
                out.append('**' + labels['result'] + ':** ' + badge)
                out.append('')
                pos = after
                continue

        # \testremarks{text}
        if inner.startswith(r'\testremarks{', pos):
            r = find_cmd(inner, 'testremarks', pos)
            if r:
                arg, _, after = r
                out.append('**' + labels['remarks'] + ':** '
                           + convert_inline_latex(arg.strip(), lang))
                out.append('')
                pos = after
                continue

        # \note{text}
        if inner.startswith(r'\note{', pos):
            r = find_cmd(inner, 'note', pos)
            if r:
                arg, _, after = r
                out.append('NOTE: ' + convert_inline_latex(arg.strip(), lang))
                out.append('')
                pos = after
                continue

        # \begin{testprerequisites} / testprocedure / testexpected
        for env_name, label_key in [
            ('testprerequisites', 'prerequisites'),
            ('testprocedure', 'procedure'),
            ('testexpected', 'expected'),
        ]:
            begin_pat = '\\begin{' + env_name + '}'
            end_pat = '\\end{' + env_name + '}'
            if inner[pos:pos + len(begin_pat)] == begin_pat:
                end_idx = inner.find(end_pat, pos)
                if end_idx == -1:
                    pos += len(begin_pat)
                    break
                env_content = inner[pos + len(begin_pat):end_idx]
                out.append('**' + labels[label_key] + ':**')
                out.append('')
                _process_step_list(env_content, lang, out)
                out.append('')
                pos = end_idx + len(end_pat)
                break
        else:
            # \begin{warning} / tip / infobox
            for env_name, admonition in [
                ('warning', 'WARNING'),
                ('tip', 'TIP'),
                ('infobox', 'NOTE'),
            ]:
                begin_pat = '\\begin{' + env_name + '}'
                end_pat = '\\end{' + env_name + '}'
                if inner[pos:pos + len(begin_pat)] == begin_pat:
                    end_idx = inner.find(end_pat, pos)
                    if end_idx == -1:
                        pos += len(begin_pat)
                        break
                    env_content = inner[pos + len(begin_pat):end_idx].strip()
                    env_content = convert_inline_latex(env_content, lang)
                    out.append(admonition + ': ' + env_content)
                    out.append('')
                    pos = end_idx + len(end_pat)
                    break
            else:
                # \begin{code}[lang] ... \end{code}
                code_m = re.match(
                    r'\\begin\{code\}(?:\[([^\]]*)\])?',
                    inner[pos:],
                )
                if code_m:
                    begin_len = code_m.end()
                    end_idx = inner.find('\\end{code}', pos + begin_len)
                    if end_idx == -1:
                        pos += begin_len
                        continue
                    code_lang = code_m.group(1) or 'text'
                    code_content = inner[pos + begin_len:end_idx].strip()
                    # Strip common indentation
                    code_lines = code_content.split('\n')
                    min_indent = float('inf')
                    for cl in code_lines:
                        if cl.strip():
                            indent = len(cl) - len(cl.lstrip())
                            min_indent = min(min_indent, indent)
                    if min_indent == float('inf'):
                        min_indent = 0
                    code_lines = [
                        cl[min_indent:] for cl in code_lines
                    ]
                    code_content = '\n'.join(code_lines)
                    out.append('[source,' + code_lang + ']')
                    out.append('----')
                    out.append(code_content)
                    out.append('----')
                    out.append('')
                    pos = end_idx + len('\\end{code}')
                    continue

                # \image[width=...]{path}
                img_m = re.match(
                    r'\\image(?:\[width=([0-9.]+)\\linewidth\])?\{([^}]*)\}',
                    inner[pos:],
                )
                if img_m:
                    width = img_m.group(1)
                    path = img_m.group(2)
                    if width:
                        pct = int(float(width) * 100)
                        out.append('image::' + path + '[width=' + str(pct) + '%]')
                    else:
                        out.append('image::' + path + '[]')
                    out.append('')
                    pos += img_m.end()
                    continue

                # Unknown content — skip one character
                pos += 1
                continue
            continue
        continue


def _process_step_list(env_content, lang, out):
    """Process \\teststep items and interspersed code blocks."""
    pos = 0
    first = True
    while pos < len(env_content):
        # Skip whitespace
        while pos < len(env_content) and env_content[pos] in ' \t\n':
            pos += 1
        if pos >= len(env_content):
            break

        # \teststep{text}
        if env_content.startswith(r'\teststep{', pos):
            r = find_cmd(env_content, 'teststep', pos)
            if r:
                arg, _, after = r
                prefix = '.' if first else '.'
                out.append(prefix + ' ' + convert_inline_latex(arg.strip(), lang))
                first = False
                pos = after
                continue

        # \begin{code}[lang] ... \end{code}
        code_m = re.match(
            r'\\begin\{code\}(?:\[([^\]]*)\])?',
            env_content[pos:],
        )
        if code_m:
            begin_len = code_m.end()
            end_idx = env_content.find('\\end{code}', pos + begin_len)
            if end_idx == -1:
                pos += begin_len
                continue
            code_lang = code_m.group(1) or 'text'
            code_content = env_content[pos + begin_len:end_idx].strip()
            code_lines = code_content.split('\n')
            min_indent = float('inf')
            for cl in code_lines:
                if cl.strip():
                    indent = len(cl) - len(cl.lstrip())
                    min_indent = min(min_indent, indent)
            if min_indent == float('inf'):
                min_indent = 0
            code_lines = [cl[min_indent:] for cl in code_lines]
            code_content = '\n'.join(code_lines)
            # Attach to previous step with +
            out.append('+')
            out.append('[source,' + code_lang + ']')
            out.append('----')
            out.append(code_content)
            out.append('----')
            pos = end_idx + len('\\end{code}')
            continue

        # Unknown — skip
        pos += 1


def convert_testsummary(content, lang):
    r"""Convert \begin{testsummary}...\end{testsummary} to AsciiDoc table."""
    lines = ['[.hutable]', '|===', '| ID | Title | Status', '']
    for line in content.split('\n'):
        line = line.strip()
        if not line:
            continue
        # Parse three {...} args after \testsummaryrow
        ts_pos = line.find(r'\testsummaryrow')
        if ts_pos != -1:
            args = []
            p = ts_pos + len(r'\testsummaryrow')
            for _ in range(3):
                if p < len(line) and line[p] == '{':
                    arg, p = extract_brace_arg(line, p + 1)
                    args.append(arg)
                else:
                    args.append('')
                    break
            if len(args) < 3:
                continue
            tc_id = convert_inline_latex(args[0].strip(), lang)
            title = convert_inline_latex(args[1].strip(), lang)
            badge = convert_inline_latex(args[2].strip(), lang)
            lines.append('| ' + tc_id + ' | ' + title + ' | ' + badge)
    lines.append('|===')
    return '\n'.join(lines)


def convert_changelog(content, lang):
    r"""Convert \begin{changelog}...\end{changelog} to AsciiDoc table."""
    lines = ['[.hutable]', '|===', '| Version | Date | Changes', '']
    pos = 0
    while True:
        ce_pos = content.find(r'\changelogentry', pos)
        if ce_pos == -1:
            break
        # Parse three {...} args after \changelogentry
        args = []
        p = ce_pos + len(r'\changelogentry')
        for _ in range(3):
            if p < len(content) and content[p] == '{':
                arg, p = extract_brace_arg(content, p + 1)
                args.append(arg)
            else:
                args.append('')
                break
        if len(args) < 3:
            pos = ce_pos + 1
            continue
        version = convert_inline_latex(args[0].strip(), lang)
        date = convert_inline_latex(args[1].strip(), lang)
        items_raw = args[2]
        # Split on \item
        items = re.split(r'\\item\s*', items_raw)
        items = [convert_inline_latex(it.strip(), lang) for it in items if it.strip()]
        changes = ' + '.join(items)
        lines.append('| ' + version + ' | ' + date + ' | ' + changes)
        pos = p
    lines.append('|===')
    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# Custom role converters
# ---------------------------------------------------------------------------

ROLE_MAP = {
    'result-pass': 'PASS',
    'result-partial': 'PARTIAL',
    'result-fail': 'FAIL',
    'result-skip': 'SKIP',
}


def convert_roles(line, lang):
    """Convert custom AsciiDoc roles to docbook-compatible markup."""
    labels = LABELS.get(lang, LABELS['en'])

    # [.result-pass]#Pass# → **[PASS]**
    for role, badge in ROLE_MAP.items():
        line = re.sub(
            r'\[\.' + role + r'\]#([^#]*)#',
            '**[' + badge + ']**',
            line,
        )

    # [.badge]#New# → **[NEW]**
    line = re.sub(r'\[\.badge\]#([^#]*)#', '**[NEW]**', line)

    # [.general-objective]#text# — handled at content level (multi-line)

    # [.note]#text# → *text*
    line = re.sub(r'\[\.note\]#([^#]*)#', r'*\1*', line)

    return line


def convert_block_roles(content, lang):
    """Convert block-level custom roles."""
    # [.evidence] → checkbox bullets
    content = re.sub(
        r'\[\.evidence\]\n((?:\* .+\n?)+)',
        lambda m: _convert_evidence_list(m.group(1), lang),
        content,
    )

    # [.activities] → keep as numbered list (roman numerals not supported in docbook)
    # Just remove the role — the numbered list renders fine
    content = re.sub(r'\[\.activities\]\n', '', content)

    # [.objective] → keep content (tcolorbox approximated as plain text in DOCX)
    content = re.sub(r'\[\.objective\]\n', '', content)

    return content


def _convert_evidence_list(list_text, lang):
    """Add checkbox markers to evidence list items."""
    lines = []
    for line in list_text.strip().split('\n'):
        line = re.sub(r'^\* ', '* \u2610 ', line)
        lines.append(line)
    return '\n'.join(lines) + '\n'


# ---------------------------------------------------------------------------
# Inline passthrough converter (pass:[...])
# ---------------------------------------------------------------------------

def convert_inline_passthroughs(text, lang):
    """Convert pass:[latex] inline passthroughs to AsciiDoc."""
    def replacer(m):
        latex = m.group(1)
        # \imageplaceholder{path}{desc}
        r = find_cmd_2args(latex, 'imageplaceholder')
        if r is not None:
            path, desc, _, _ = r
            return 'NOTE: Image placeholder: ' + desc.strip() + ' (' + path.strip() + ')'
        # \textcolor{color}{text} — just return the text
        result = convert_inline_latex(latex, lang)
        return result

    # Match pass:[...] — need to handle nested brackets
    result = []
    pos = 0
    while True:
        idx = text.find('pass:[', pos)
        if idx == -1:
            result.append(text[pos:])
            break
        result.append(text[pos:idx])
        bracket_start = idx + 6  # len('pass:[')
        depth = 1
        i = bracket_start
        while i < len(text) and depth > 0:
            if text[i] == '[':
                depth += 1
            elif text[i] == ']':
                depth -= 1
            i += 1
        latex_content = text[bracket_start:i - 1]
        result.append(replacer(type('', (), {'group': lambda self, x: latex_content})()))
        pos = i
    return ''.join(result)


# ---------------------------------------------------------------------------
# Main processing
# ---------------------------------------------------------------------------

# Map LaTeX environment names to handler functions
POC_HANDLERS = {
    'stakeholders': convert_stakeholders,
    'closingrecord': convert_closingrecord,
    'signatures': convert_signatures,
}

TESTBOOK_HANDLERS = {
    'testcase': convert_testcase,
    'testsummary': convert_testsummary,
    'changelog': convert_changelog,
    'signatures': convert_signatures,  # shared with POC
}


def process_passthrough_blocks(content, template, lang):
    """Find ++++...++++ blocks and convert recognized LaTeX environments."""
    if template == 'poc':
        handlers = POC_HANDLERS
    elif template == 'testbook':
        handlers = TESTBOOK_HANDLERS
    else:
        return content

    result = []
    lines = content.split('\n')
    i = 0
    while i < len(lines):
        if lines[i].strip() == '++++':
            # Find closing ++++
            block_start = i + 1
            j = block_start
            while j < len(lines) and lines[j].strip() != '++++':
                j += 1
            if j >= len(lines):
                # No closing ++++ — leave as-is
                result.append(lines[i])
                i += 1
                continue
            block_content = '\n'.join(lines[block_start:j])
            # Identify the environment
            env_match = re.search(r'\\begin\{(\w+)\}', block_content)
            if env_match:
                env_name = env_match.group(1)
                handler = handlers.get(env_name)
                if handler:
                    converted = handler(block_content, lang)
                    result.append(converted)
                    i = j + 1
                    continue
            # Unrecognized — drop the passthrough (raw LaTeX is useless in DOCX)
            i = j + 1
            continue
        result.append(lines[i])
        i += 1
    return '\n'.join(result)


def detect_lang(content):
    """Detect language from :lang: header attribute."""
    m = re.search(r'^:lang:\s*(\w+)', content, re.MULTILINE)
    return m.group(1) if m else 'en'


def process_adoc(content, template):
    """Main entry: transform .adoc content for DOCX generation."""
    global _testcase_counter
    _testcase_counter = 0

    lang = detect_lang(content)

    # 1. Convert passthrough blocks
    content = process_passthrough_blocks(content, template, lang)

    # 2. Convert inline passthroughs (pass:[...])
    content = convert_inline_passthroughs(content, lang)

    # 3. Convert block-level roles
    content = convert_block_roles(content, lang)

    # 4. Convert multi-line inline roles (general-objective spans multiple lines)
    content = re.sub(
        r'\[\.general-objective\]#([^#]*)#',
        r'**General Objective:** \1',
        content,
        flags=re.DOTALL,
    )

    # 5. Convert inline roles (line by line)
    lines = content.split('\n')
    lines = [convert_roles(line, lang) for line in lines]
    content = '\n'.join(lines)

    return content


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='Pre-process .adoc for DOCX generation',
    )
    parser.add_argument(
        '--template', required=True,
        choices=['poc', 'testbook', 'guide', 'technical'],
        help='Template name',
    )
    parser.add_argument('input', help='Input .adoc file')
    parser.add_argument('-o', '--output', required=True, help='Output .adoc file')
    args = parser.parse_args()

    with open(args.input, 'r', encoding='utf-8') as f:
        content = f.read()

    processed = process_adoc(content, args.template)

    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(processed)


if __name__ == '__main__':
    main()
