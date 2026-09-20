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
        'test_case': 'Testcase',
        'table': 'Table',
        'diagram': 'Diagram',
        'figure': 'Figure',
        'changelog': 'Changelog',
        'sincerely': 'Sincerely,',
        'th_name': 'Name', 'th_email': 'Email', 'th_phone': 'Phone', 'th_role': 'Role',
        'th_item': 'Item', 'th_record': 'Record',
        'th_id': 'ID', 'th_title': 'Title', 'th_status': 'Status',
        'th_version': 'Version', 'th_date': 'Date', 'th_changes': 'Changes',
    },
    'pt': {
        'homologated': 'Homologada',
        'with_reservations': 'Homologada com ressalvas',
        'not_homologated': 'Não homologada',
        'objective': 'Objetivo',
        'scope': 'Escopo do Teste',
        'prerequisites': 'Pré-requisitos',
        'procedure': 'Procedimento',
        'expected': 'Resultado Esperado',
        'result': 'Resultado do Teste',
        'remarks': 'Observações',
        'test_case': 'Caso de Teste',
        'table': 'Tabela',
        'diagram': 'Diagrama',
        'figure': 'Figura',
        'changelog': 'Histórico de versões',
        'sincerely': 'At.te,',
        'th_name': 'Nome', 'th_email': 'E-mail', 'th_phone': 'Telefone', 'th_role': 'Papel',
        'th_item': 'Item', 'th_record': 'Registro',
        'th_id': 'ID', 'th_title': 'Título', 'th_status': 'Status',
        'th_version': 'Versão', 'th_date': 'Data', 'th_changes': 'Alterações',
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


def _esc_cell(text):
    r"""Escape unescaped pipes for AsciiDoc table cells.

    A literal '|' in cell content would split the cell; an already
    escaped '\|' is left intact.
    """
    return re.sub(r'(?<!\\)\|', r'\\|', text)


# ---------------------------------------------------------------------------
# Inline LaTeX → AsciiDoc
# ---------------------------------------------------------------------------

def _badge_text(text):
    r"""Format badge text per target (PDF: \badge{text} keeps the text)."""
    text = text.strip()
    if _TARGET == 'docx':
        # Sentinel consumed by docx_fix -> flat red badge with the text
        return '**[BADGE:' + text + ']**'
    return '**[' + text + ']**'


def convert_inline_latex(text, lang='en'):
    """Convert inline LaTeX commands to AsciiDoc inline formatting."""
    labels = LABELS.get(lang, LABELS['en'])

    # Order matters: escape sequences first, then commands
    text = text.replace(r'\textbackslash', '\\')
    text = text.replace(r'\textasciitilde', '~')
    text = text.replace(r'\_', '_')
    text = text.replace(r'\&', '&')
    text = text.replace(r'\%', '%')
    text = text.replace(r'\#', '#')
    text = text.replace(r'\$', '$')

    # Math symbols
    text = text.replace(r'$\rightarrow$', '\u2192')   # →
    text = text.replace(r'$\to$', '\u2192')             # → (short form)
    text = text.replace(r'$\geq$', '\u2265')           # ≥
    text = text.replace(r'$\leq$', '\u2264')           # ≤
    text = text.replace(r'$>$', '>')
    text = text.replace(r'$<$', '<')
    text = text.replace(r'$\neq$', '\u2260')           # ≠
    text = text.replace(r'$\times$', '\u00d7')         # ×
    # LaTeX typographic quotes → Unicode (paired only — '' inside code
    # args, e.g. SQL empty strings, must stay literal)
    text = re.sub(r"``([^`']+?)''", '\u201c\\1\u201d', text)

    # POC classification labels
    text = text.replace(r'\pochomologated', labels['homologated'])
    text = text.replace(r'\pocwithreservations', labels['with_reservations'])
    text = text.replace(r'\pocnothomologated', labels['not_homologated'])

    # \testresultbadge{X} → **[X]**  (case preserved — PDF renders the
    # text as written, e.g. Blocked/Untested, not BLOCKED/UNTESTED)
    text = re.sub(
        r'\\testresultbadge\{([^}]*)\}',
        lambda m: '**[' + m.group(1) + ']**',
        text,
    )

    # \badge{text} → target-aware badge (same contract as [.badge]#text#)
    text = _replace_cmd(text, 'badge', _badge_text)

    # \textbf{text} → **text**  (handle nested braces)
    text = _replace_cmd(text, 'textbf', lambda arg: '**' + arg + '**')
    # \inlinecode{text} → `text`
    # Asterisk runs (e.g. *********) are wrapped in pass:[...] — asciidoctor's
    # docbook backend otherwise parses ** inside literals as bold, collapsing
    # the run (PDF keeps all asterisks; DOCX must match).
    def _inlinecode_replacer(arg):
        if '**' in arg and '[' not in arg and ']' not in arg:
            return '`pass:[' + arg + ']`'
        return '`' + arg + '`'
    text = _replace_cmd(text, 'inlinecode', _inlinecode_replacer)
    # \texttt{text} → `text` (same protection as \inlinecode)
    text = _replace_cmd(text, 'texttt', _inlinecode_replacer)
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
    labels = LABELS.get(lang, LABELS['en'])
    # No header row in the PDF (stakeholders is a tcolorbox list); this
    # header is a secondary-format (DOCX/MD/HTML) table construct.
    header = '| ' + labels['th_name'] + ' | ' + labels['th_email'] + ' | ' + labels['th_phone'] + ' | ' + labels['th_role']
    lines = ['[.hutable]', '|===', header, '']
    for line in content.split('\n'):
        line = line.strip()
        if not line:
            continue
        m = re.match(r'\\stakeholderorg\{([^}]*)\}', line)
        if m:
            org = _esc_cell(convert_inline_latex(m.group(1), lang))
            lines.append('4+| *' + org + '*')
            continue
        m = re.match(
            r'\\stakeholderrow\{([^}]*)\}\{([^}]*)\}\{([^}]*)\}\{([^}]*)\}',
            line,
        )
        if m:
            vals = [_esc_cell(convert_inline_latex(m.group(i), lang))
                    for i in range(1, 5)]
            lines.append('| ' + ' | '.join(vals))
            continue
    lines.append('|===')
    return '\n'.join(lines)


def convert_closingrecord(content, lang):
    r"""Convert \begin{closingrecord}...\end{closingrecord} to AsciiDoc table."""
    labels = LABELS.get(lang, LABELS['en'])
    # Header mirrors the cls labels (poc.cls: Item | Record / Item | Registro).
    header = '| ' + labels['th_item'] + ' | ' + labels['th_record']
    lines = ['[.hutable]', '|===', header, '']
    for line in content.split('\n'):
        line = line.strip()
        if not line:
            continue
        r = find_cmd_2args(line, 'closingrow')
        if r is not None:
            label, value, _, _ = r
            label = _esc_cell(convert_inline_latex(label, lang))
            value = _esc_cell(convert_inline_latex(value, lang))
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
        # Split on unescaped & only (\& is a literal ampersand)
        parts = re.split(r'(?<!\\)&', line)
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
                name = _esc_cell(convert_inline_latex(args[0], lang))
                title = _esc_cell(convert_inline_latex(args[1], lang))
                email = _esc_cell(convert_inline_latex(args[2], lang))
                address = _esc_cell(convert_inline_latex(args[3], lang))
                cell = (
                    labels['sincerely'] + ' +\n'
                    + name + ' +\n' + title + ' +\n'
                    + 'E-mail: `' + email + '` +\n' + address
                )
                cells.append(cell)
        if cells:
            for cell in cells:
                lines.append('| ' + cell)
            if len(cells) == 1:
                # Keep the 2-column grid (PDF: empty signature cell)
                lines.append('|')
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
    # Caption paragraph (not a heading): keeps test cases out of the
    # DOCX TOC and section numbering, matching the PDF where testcase
    # titles are centered captions, not TOC entries.
    # PDF (testbook.cls): \textbf{\lg@testcase N:} title — only the
    # symbol part is bold.
    out.append('**' + labels['test_case'] + ' ' + str(tc_num) + ':** ' + title)
    out.append('')

    # Markers delimit the tcolorbox body (PDF: red left rule).  docx_fix
    # deletes them and draws a 3pt red left border on everything between.
    # Only emitted for DOCX — MD/HTML have no post-processor to remove them.
    if _TARGET == 'docx':
        out.append('TESTCASE-START')
        out.append('')

    # Process inner content
    _process_testcase_inner(inner, lang, labels, out)

    if _TARGET == 'docx':
        out.append('TESTCASE-END')
        out.append('')

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
                out.append('**' + labels['objective'] + '**')
                out.append('')
                out.append(convert_inline_latex(arg.strip(), lang))
                out.append('')
                pos = after
                continue

        # \testscope{text}
        if inner.startswith(r'\testscope{', pos):
            r = find_cmd(inner, 'testscope', pos)
            if r:
                arg, _, after = r
                out.append('**' + labels['scope'] + '**')
                out.append('')
                out.append(convert_inline_latex(arg.strip(), lang))
                out.append('')
                pos = after
                continue

        # \testresult{...} — hidden by :noanswers: (PDF: testbook.cls
        # noanswers option hides Test Result and Remarks entirely)
        if inner.startswith(r'\testresult{', pos):
            r = find_cmd(inner, 'testresult', pos)
            if r:
                arg, _, after = r
                if not _NOANSWERS:
                    out.append('**' + labels['result'] + '**')
                    out.append('')
                    out.append(convert_inline_latex(arg.strip(), lang))
                    out.append('')
                pos = after
                continue

        # \testremarks{text} — hidden by :noanswers: (see \testresult)
        if inner.startswith(r'\testremarks{', pos):
            r = find_cmd(inner, 'testremarks', pos)
            if r:
                arg, _, after = r
                if not _NOANSWERS:
                    out.append('**' + labels['remarks'] + '**')
                    out.append('')
                    out.append(convert_inline_latex(arg.strip(), lang))
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
                out.append('**' + labels[label_key] + '**')
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
    r"""Process \teststep items and interspersed code blocks."""
    pos = 0
    step_num = 0
    while pos < len(env_content):
        # Skip whitespace
        while pos < len(env_content) and env_content[pos] in ' \t\n':
            pos += 1
        if pos >= len(env_content):
            break

        # \teststep{text} — explicit bold number (PDF: red bold "N.").
        # A plain paragraph keeps full styling control in docx_fix;
        # AsciiDoc list markers would render via numbering.xml instead.
        # Blank line before every step after the first — consecutive
        # lines would merge into a single AsciiDoc paragraph.
        if env_content.startswith(r'\teststep{', pos):
            r = find_cmd(env_content, 'teststep', pos)
            if r:
                arg, _, after = r
                step_num += 1
                if step_num > 1:
                    out.append('')
                out.append('**' + str(step_num) + '.** '
                           + convert_inline_latex(arg.strip(), lang))
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
    labels = LABELS.get(lang, LABELS['en'])
    # Header mirrors the cls labels (testbook.cls: ID | Title | Status).
    header = '| ' + labels['th_id'] + ' | ' + labels['th_title'] + ' | ' + labels['th_status']
    lines = ['[.hutable]', '|===', header, '']
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
            tc_id = _esc_cell(convert_inline_latex(args[0].strip(), lang))
            title = _esc_cell(convert_inline_latex(args[1].strip(), lang))
            badge = _esc_cell(convert_inline_latex(args[2].strip(), lang))
            lines.append('| ' + tc_id + ' | ' + title + ' | ' + badge)
    lines.append('|===')
    return '\n'.join(lines)


def convert_changelog(content, lang):
    r"""Convert \begin{changelog}...\end{changelog} to an AsciiDoc section.

    PDF (L12): the changelog environment emits its own language-aware
    section heading ("Changelog" / "Histórico de versões"), so the DOCX
    conversion emits a level-1 heading before the table.
    """
    labels = LABELS.get(lang, LABELS['en'])
    # No header row in the PDF (changelog is version+date+itemize, no
    # table); this header is a secondary-format (DOCX/MD/HTML) table
    # construct.
    header = '| ' + labels['th_version'] + ' | ' + labels['th_date'] + ' | ' + labels['th_changes']
    lines = ['== ' + labels['changelog'], '',
             '[.hutable]', '|===', header, '']
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
        version = _esc_cell(convert_inline_latex(args[0].strip(), lang))
        date = _esc_cell(convert_inline_latex(args[1].strip(), lang))
        items_raw = args[2]
        # Split on \item
        items = re.split(r'\\item\s*', items_raw)
        items = [_esc_cell(convert_inline_latex(it.strip(), lang))
                 for it in items if it.strip()]
        # a| cell: AsciiDoc cell with block content — each \item becomes
        # a bullet, matching the PDF (itemize inside the table cell).
        lines.append('| ' + version + ' | ' + date + ' a|')
        for it in items:
            lines.append('* ' + it)
        pos = p
    lines.append('|===')
    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# Custom role converters
# ---------------------------------------------------------------------------

def _result_badge_texts(template, lang):
    r"""Badge text per result role — mirrors the converter's \pocresult
    (POC labels are language-aware) and \testresultbadge (English)."""
    if template == 'poc' and lang == 'pt':
        return {
            'result-pass': 'Atendido', 'result-partial': 'Parcial',
            'result-fail': 'Falha', 'result-skip': 'Ignorado',
        }
    return {
        'result-pass': 'Pass', 'result-partial': 'Partial',
        'result-fail': 'Fail', 'result-skip': 'Skip',
    }


def convert_roles(line, lang, template):
    """Convert custom AsciiDoc roles to docbook-compatible markup."""
    labels = LABELS.get(lang, LABELS['en'])

    # [.result-pass]#Pass# → **[Pass]** (POC+pt: **[Atendido]**, etc.)
    for role, badge in _result_badge_texts(template, lang).items():
        line = re.sub(
            r'\[\.' + role + r'\]#([^#]*)#',
            '**[' + badge + ']**',
            line,
        )

    # [.badge]#text# → target-aware badge (text preserved — PDF \badge{text})
    line = re.sub(
        r'\[\.badge\]#([^#]*)#', lambda m: _badge_text(m.group(1)), line)

    # [.general-objective]#text# — handled at content level (multi-line)

    # [.note]#text# → *text*
    line = re.sub(r'\[\.note\]#([^#]*)#', r'*\1*', line)

    return line


def convert_block_roles(content, lang):
    """Convert block-level custom roles."""
    # [.evidence] → plain bullet list (checkbox markers removed in
    # v6.5.0 — the PDF now renders standard bullets too).
    content = re.sub(r'\[\.evidence\]\n', '', content)

    # [.activities] → native lower-roman numbering.  AsciiDoc's
    # [lowerroman] list style makes asciidoctor emit docbook
    # numeration="lowerroman" → pandoc → Word native lower-roman
    # numbering (no manual text markers needed).
    content = re.sub(r'\[\.activities\]\n', '[lowerroman]\n', content)

    # [.objective] → keep content (tcolorbox approximated as plain text in DOCX)
    content = re.sub(r'\[\.objective\]\n', '', content)

    return content


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

# Target format: 'docx' emits TESTCASE-START/END markers (consumed and
# deleted by docx_fix to draw the PDF's red left rule); 'md'/'html' have
# no post-processor, so markers are skipped there.
_TARGET = 'docx'

# :noanswers: header attribute — hides Test Result and Remarks fields
# (PDF: testbook.cls noanswers class option).
_NOANSWERS = False

# Technical report cover values, captured from the \setreport* passthrough
# block (technical.cls cover).  None → fall back to :version:/today.
_REPORT_VERSION = None
_REPORT_DATE = None
_REPORT_SCENARIO = None
_REPORT_TYPE = None

# Map LaTeX environment names to handler functions
POC_HANDLERS = {
    'stakeholders': convert_stakeholders,
    'closingrecord': convert_closingrecord,
    'signatures': convert_signatures,
    'changelog': convert_changelog,
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
        # guide/technical: the changelog passthrough is the only block
        # environment used in practice (any other passthrough, e.g.
        # \setreportversion, is cover metadata — dropped, not content).
        handlers = {'changelog': convert_changelog}

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
                    # L12: :nochangelog: suppresses the changelog entirely
                    # (PDF renders nothing) — drop the block, don't convert.
                    if (env_name == 'changelog'
                            and re.search(r'^:nochangelog:',
                                          content, re.MULTILINE)):
                        i = j + 1
                        continue
                    converted = handler(block_content, lang)
                    result.append(converted)
                    i = j + 1
                    continue
            # Unrecognized — scan for \setreport* cover metadata (technical
            # cls) before dropping the passthrough (raw LaTeX is useless
            # downstream, but the values are needed by inject_cover_block).
            global _REPORT_VERSION, _REPORT_DATE, _REPORT_SCENARIO, _REPORT_TYPE
            for cmd, attr in [
                ('setreportversion', '_REPORT_VERSION'),
                ('setreportdate', '_REPORT_DATE'),
                ('setreportscenario', '_REPORT_SCENARIO'),
                ('setreporttype', '_REPORT_TYPE'),
            ]:
                r = find_cmd(block_content, cmd)
                if r and r[0].strip():
                    globals()[attr] = r[0].strip()
            i = j + 1
            continue
        result.append(lines[i])
        i += 1
    return '\n'.join(result)


def detect_lang(content):
    """Detect language from :lang: header attribute."""
    m = re.search(r'^:lang:\s*(\w+)', content, re.MULTILINE)
    return m.group(1) if m else 'en'


PT_MONTHS = [
    'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
    'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
]


def _cover_datetime(lang):
    """Build the cover date/time like the PDF (LaTeX \\today + \\time).

    Date: formatted per language (babel \\today).  Time: HH:MM build
    time.  TZ defaults to America/Sao_Paulo (L4); an existing TZ env
    var wins, matching latexmk's behavior.
    """
    import datetime
    import os
    import time as _time
    if 'TZ' not in os.environ:
        os.environ['TZ'] = 'America/Sao_Paulo'
    _time.tzset()
    now = datetime.datetime.now()
    if lang == 'pt':
        date = '{0} de {1} de {2}'.format(
            now.day, PT_MONTHS[now.month - 1], now.year)
    else:
        # PDF \today has no leading zero on the day (e.g. "September 5",
        # not "September 05").
        date = now.strftime('%B ') + str(now.day) + now.strftime(', %Y')
    return date, now.strftime('%H:%M')


def inject_cover_block(content, lang, template):
    r"""Inject cover elements as the first body content.

    Approximates the PDF cover (huawei-cover.sty / technical.cls):
    - Non-technical (guide/poc/testbook): logo, generic cover text, meta
      line 'vX — date time' (bold version, L5; :notime: hides the time).
    - Technical: logo, report-type label (e.g. "Technical Report"), a
      Version/Date/Scenario table (red label column in DOCX via
      docx_fix), and a meta line using the REPORT version/date (not the
      document :version:).  Authors appear as a table row when set.

    Pandoc already renders title, authors, and date; docx_fix reorders
    (title → logo → cover text/label [+ table] → authors → meta) and
    deletes the redundant date paragraph.  The meta line and version
    table are skipped when :nochangelog: is set (L12 hides version/date/
    time).
    """
    lines = content.split('\n')
    # Find the last header attribute line (":key: value")
    last_attr = -1
    for i, l in enumerate(lines[:60]):
        if l.startswith(':'):
            last_attr = i
    if last_attr == -1:
        return content

    m_logo = re.search(r'^:cover-logo:\s*(\S+)', content, re.MULTILINE)
    m_covertext = re.search(r'^:cover-text:\s*(.+?)\s*$', content, re.MULTILINE)
    m_version = re.search(r'^:version:\s*(\S+)', content, re.MULTILINE)
    m_date = re.search(r'^:date:\s*(.+?)\s*$', content, re.MULTILINE)
    m_authors = re.search(r'^:authors:\s*(.+?)\s*$', content, re.MULTILINE)
    nochangelog = re.search(r'^:nochangelog:', content, re.MULTILINE)
    notime = re.search(r'^:notime:', content, re.MULTILINE)
    noauthors = re.search(r'^:noauthors:', content, re.MULTILINE)

    logo = m_logo.group(1) if m_logo else 'common-assets/huawei-logo-cover.png'

    block = ['image::' + logo + '[]', '']

    if template == 'technical':
        # Report-type label (PDF: 16pt bold huaweired, centered).
        type_label = _REPORT_TYPE or 'Technical Report'
        block.append(type_label)
        block.append('')

        # Version/Date/Scenario table (PDF: red label column).  Gated by
        # :nochangelog: (L12 — the PDF's \if@changelog hides covermeta
        # and the version table alike).
        if not nochangelog:
            table_lines = ['[cols="1,1"]', '|===']
            if _REPORT_VERSION:
                table_lines.append('| *Version* | ' + _REPORT_VERSION)
            if _REPORT_DATE:
                table_lines.append('| *Date* | ' + _REPORT_DATE)
            if _REPORT_SCENARIO:
                table_lines.append('| *Scenario* | ' + _REPORT_SCENARIO)
            if m_authors and not noauthors:
                table_lines.append('| *Author* | ' + m_authors.group(1))
            table_lines.append('|===')
            block.extend(table_lines)
            block.append('')

        # Meta line uses the REPORT version/date (not :version:).
        if not nochangelog:
            meta_ver = _REPORT_VERSION or (m_version.group(1) if m_version else None)
            if meta_ver:
                if _REPORT_DATE:
                    date_str = _REPORT_DATE
                    _, time_str = _cover_datetime(lang)
                elif m_date:
                    date_str = m_date.group(1)
                    _, time_str = _cover_datetime(lang)
                else:
                    date_str, time_str = _cover_datetime(lang)
                meta = '**v' + meta_ver + '** — ' + date_str
                if not notime:
                    meta += ' ' + time_str
                block.append(meta)
                block.append('')
    else:
        # Non-technical: generic cover text + :version: meta (unchanged).
        cover_text = (m_covertext.group(1) if m_covertext
                      else 'Huawei Technologies CO., LTD')
        block.append(cover_text)
        block.append('')
        if m_version and not nochangelog:
            if m_date:
                date_str = m_date.group(1)
                _, time_str = _cover_datetime(lang)
            else:
                date_str, time_str = _cover_datetime(lang)
            meta = '**v' + m_version.group(1) + '** — ' + date_str
            if not notime:
                meta += ' ' + time_str
            block.append(meta)
            block.append('')

    # Insert as the first body content (after the blank line following attrs)
    insert_at = last_attr + 1
    while insert_at < len(lines) and lines[insert_at].strip() == '':
        insert_at += 1
    lines[insert_at:insert_at] = block
    return '\n'.join(lines)


def number_block_titles(content, lang):
    """Number block titles to match the PDF caption systems.

    PDF caption systems (converter + huawei-images.sty):
      - .Title above [.hutable] table -> "Table N: Title"   (\\caption)
      - .Title above a diagram block  -> "Diagram N: Title" (\\diagramcap)
      - .Title above image::          -> "Figure N: Title"  (\\imagecap)
    The symbol part is emitted bold (PDF: \\textbf{label N:} or
    captionsetup labelfont=bf); the description stays plain.
    Counters are per category, document-wide.
    """
    labels = LABELS.get(lang, LABELS['en'])
    counters = {'table': 0, 'diagram': 0, 'figure': 0}

    lines = content.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]
        # Block title: ".Title text".  Skip literal-block delimiters (....)
        # and lines starting with ".." (not block titles).
        if line.startswith('.') and not line.startswith('..'):
            if re.match(r'^\.+$', line.strip()):
                i += 1
                continue
            m = re.match(r'^\.(\S.*)$', line)
            if m:
                # Classify by the next non-blank line
                j = i + 1
                while j < len(lines) and not lines[j].strip():
                    j += 1
                if j < len(lines):
                    nxt = lines[j].strip()
                    kind = None
                    if nxt.startswith('[.hutable]') or nxt.startswith('|==='):
                        kind = 'table'
                    elif re.match(r'^\[(plantuml|graphviz|mermaid)\b', nxt):
                        kind = 'diagram'
                    elif nxt.startswith('image::'):
                        kind = 'figure'
                    if kind:
                        counters[kind] += 1
                        symbol = ('**' + labels[kind] + ' '
                                  + str(counters[kind]) + ':**')
                        lines[i] = '.' + symbol + ' ' + m.group(1)
                        i = j + 1
                        continue
        i += 1
    return '\n'.join(lines)


def process_adoc(content, template, target='docx'):
    """Main entry: transform .adoc content for DOCX/MD/HTML generation."""
    global _testcase_counter
    global _TARGET
    global _NOANSWERS
    global _REPORT_VERSION, _REPORT_DATE, _REPORT_SCENARIO, _REPORT_TYPE
    _testcase_counter = 0
    _TARGET = target
    _NOANSWERS = bool(re.search(r'^:noanswers:', content, re.MULTILINE))
    _REPORT_VERSION = None
    _REPORT_DATE = None
    _REPORT_SCENARIO = None
    _REPORT_TYPE = None

    lang = detect_lang(content)

    # 1. Convert inline passthroughs (pass:[...]) — must run BEFORE block
    #    conversion: the block handlers emit pass:[...] wraps (asterisk-run
    #    protection for inlinecode) that this pass must not unwrap.
    content = convert_inline_passthroughs(content, lang)

    # 2. Convert passthrough blocks
    content = process_passthrough_blocks(content, template, lang)

    # 3. Convert block-level roles
    content = convert_block_roles(content, lang)

    # 4. Number block titles (Table/Diagram/Figure N: — PDF caption systems)
    content = number_block_titles(content, lang)

    # 5. Convert multi-line inline roles (general-objective spans multiple lines)
    content = re.sub(
        r'\[\.general-objective\]#([^#]*)#',
        r'**General Objective:** \1',
        content,
        flags=re.DOTALL,
    )

    # 6. Convert inline roles (line by line)
    lines = content.split('\n')
    lines = [convert_roles(line, lang, template) for line in lines]
    content = '\n'.join(lines)

    # 7. Inject cover block (logo, cover text, meta line — PDF cover)
    content = inject_cover_block(content, lang, template)

    return content


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description='Pre-process .adoc for DOCX/MD/HTML generation',
    )
    parser.add_argument(
        '--template', required=True,
        choices=['poc', 'testbook', 'guide', 'technical'],
        help='Template name',
    )
    parser.add_argument(
        '--target', default='docx',
        choices=['docx', 'md', 'html'],
        help='Target format (docx emits testcase markers for docx_fix; '
             'md/html skip them — no post-processor removes them there)',
    )
    parser.add_argument('input', help='Input .adoc file')
    parser.add_argument('-o', '--output', required=True, help='Output .adoc file')
    args = parser.parse_args()

    with open(args.input, 'r', encoding='utf-8') as f:
        content = f.read()

    processed = process_adoc(content, args.template, args.target)

    with open(args.output, 'w', encoding='utf-8') as f:
        f.write(processed)


if __name__ == '__main__':
    main()
