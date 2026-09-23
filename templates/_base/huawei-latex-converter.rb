# frozen_string_literal: true

# huawei-latex-converter.rb
# Custom Asciidoctor backend that converts AsciiDoc (.adoc) to
# LaTeX (.tex) using Huawei template class commands.
#
# Usage:
#   asciidoctor -b huawei-latex \
#     -r templates/_base/huawei-latex-converter.rb \
#     doc.adoc -o doc.tex
#
# Reads AsciiDoc document attributes for preamble generation and
# maps AsciiDoc AST nodes to Huawei LaTeX commands.

require 'asciidoctor'
require 'asciidoctor/converter'

# LaTeX special characters that must be escaped in text content.
# Applied everywhere EXCEPT code blocks, passthrough, and URLs.
LATEX_ESCAPES = {
  '\\' => '\textbackslash{}',
  '%'  => '\%',
  '$'  => '\$',
  '#'  => '\#',
  '&'  => '\&',
  '_'  => '\_',
  '{'  => '\{',
  '}'  => '\}',
  '~'  => '\textasciitilde{}',
  '^'  => '\textasciicircum{}',
}.freeze

# Build a regex that matches any escapable character.
LATEX_ESCAPE_RE = /[\\%$#&_{\}~^]/

# Regex for escaping text specials (% $ # & ~ ^ _) NOT preceded by a backslash.
# The lookbehind avoids double-escaping already-escaped output (\_, \%, \&)
# that inline handlers emit before escape_inline_content re-processes it.
LATEX_TEXT_ESCAPE_NO_BACKSLASH_RE = /(?<!\\)([%$#&~^_])/

# --- Helper: escape LaTeX special characters in text ---
def latex_escape(text)
  return '' if text.nil? || text.empty?
  text.gsub(LATEX_ESCAPE_RE) { |ch| LATEX_ESCAPES[ch] }
end

# --- Helper: unescape HTML entities that asciidoctor adds ---
def unescape_html_entities(text)
  return text if text.nil? || text.empty?
  text.gsub(/(?<!\\)&lt;/, '<').gsub(/(?<!\\)&gt;/, '>').gsub(/(?<!\\)&quot;/, '"').gsub(/(?<!\\)&amp;/, '&')
      .gsub(/(?<!\\)&#(\d+);/) { |m| begin $1.to_i.chr(Encoding::UTF_8) rescue m end }
      # Strip invisible chars: Asciidoctor appends U+200B (zero-width space) to
      # --/... expansions (&#8212;&#8203; / &#8230;&#8203;); HarmonyOS Sans lacks
      # the glyph and XeLaTeX emits "Missing character" warnings.
      .gsub(/[\u200B\u2060\uFEFF]/, '')
end

# --- Helper: unescape HTML entities then escape LaTeX text specials ---
# Escapes % $ # & ~ ^ _ (not braces/backslash) unless already backslash-escaped,
# so already-escaped output (\_, \%, \&) from inline handlers is not double-escaped.
def escape_text_string(text)
  text = unescape_html_entities(text.to_s)
  text.gsub(LATEX_TEXT_ESCAPE_NO_BACKSLASH_RE) { |ch| LATEX_ESCAPES[ch] }
end

# --- Helper: unescape entities then escape LaTeX special chars ---
def process_text(text)
  return '' if text.nil? || text.empty?
  escape_text_string(text)
end

# --- Helper: escape LaTeX special characters in URLs ---
# Escapes % and _ which are TeX-special in URLs. Hyperref handles # and &, / : . - ? = ~ internally.
def latex_escape_url(url)
  return '' if url.nil? || url.empty?
  url.gsub(/[%_]/) { |ch| LATEX_ESCAPES[ch] }
end

# --- Helper: sanitize a cross-reference label for hyperref ---
# Replaces '_' with '-' so labels are hyperref-safe. Both \label/\hypertarget
# (anchor side) and \hyperlink (xref side) use this function so they always match.
def sanitize_label(target)
  target.to_s.gsub('_', '-')
end

# --- Helper: escape table cell content (may be Array or String) ---
def escape_table_cell(content)
  content = content.is_a?(Array) ? content.join : content.to_s
  escape_text_string(content)
end

# Escape LaTeX special chars EXCEPT backslash (for inline text that may
# contain passthroughs or generated commands).  Used in inline handlers
# where node.text returns raw AsciiDoc text.
LATEX_TEXT_ESCAPE_RE = /[%$#&_{}~^]/
def latex_escape_text(text)
  return '' if text.nil? || text.empty?
  text.gsub(LATEX_TEXT_ESCAPE_RE) { |ch| LATEX_ESCAPES[ch] }
end

# --- Helper: convert pixel width to linewidth fraction ---
# Heuristic: 600px ≈ 0.8\linewidth, 400px ≈ 0.5\linewidth
def pixel_width_to_linewidth(px)
  fraction = (px.to_i / 750.0).clamp(0.1, 1.0)
  # Round to one decimal place
  rounded = (fraction * 10).round / 10.0
  "#{rounded}\\linewidth"
end

# --- Helper: admonition type → LaTeX environment ---
ADMONITION_MAP = {
  'note'      => 'infobox',
  'tip'       => 'tip',
  'warning'   => 'warning',
  'caution'   => 'warning',
  'important' => 'warning',
}.freeze

# --- Register the 'huawei-latex' converter backend ---
class HuaweiLatexConverter < Asciidoctor::Converter::Base
  register_for 'huawei-latex'

  # --- Main dispatch: route node transforms to specific converters ---
  def convert node, transform = node.node_name, opts = {}
    # Check for custom role-based block converters first
    if node.respond_to?(:role) && node.role
      role_method = node.role.tr('-', '_')
      if respond_to?("convert_role_#{role_method}", true)
        return send("convert_role_#{role_method}", node)
      end
    end

    case transform
    # Structural
    when 'document'        then convert_document(node)
    when 'section'         then convert_section(node)
    when 'embedded'        then convert_embedded(node)

    # Block-level content
    when 'paragraph'       then convert_paragraph(node)
    when 'admonition'      then convert_admonition(node)
    when 'listing'         then convert_listing(node)
    when 'literal'         then convert_literal(node)
    when 'table'           then convert_table(node)
    when 'image'           then convert_image(node)
    when 'ulist'           then convert_ulist(node)
    when 'olist'           then convert_olist(node)
    when 'dlist'           then convert_dlist(node)
    when 'colist'          then convert_colist(node)
    when 'example'         then convert_example(node)
    when 'quote'           then convert_quote(node)
    when 'open'            then convert_open(node)
    when 'pass'            then convert_pass(node)
    when 'floating_title'  then convert_floating_title(node)
    when 'thematic_break'  then convert_thematic_break(node)
    when 'page_break'      then convert_page_break(node)

    # Inline content
    when 'inline_quoted'   then convert_inline_quoted(node)
    when 'inline_anchor'   then convert_inline_anchor(node)
    when 'inline_image'    then convert_inline_image(node)
    when 'inline_break'    then convert_inline_break(node)
    when 'inline_button'   then convert_inline_button(node)
    when 'inline_callout'  then convert_inline_callout(node)
    when 'inline_footnote' then convert_inline_footnote(node)
    when 'inline_indexterm' then convert_inline_indexterm(node)
    when 'inline_kbd'      then convert_inline_kbd(node)
    when 'inline_menu'     then convert_inline_menu(node)
    when 'icon'            then convert_icon(node)

    # List items — just return their text content
    when 'list_item'       then node.text

    # Fallback: emit content recursively
    else
      node.content
    end
  rescue StandardError => e
    # Report an actionable error instead of aborting with a raw Ruby object
    # dump. NoMethodError/NameError messages embed the receiver's full
    # inspect ("undefined method 'text' for #<Asciidoctor::Block:0x...>"),
    # which starts ~35 chars in — well inside the truncation window — so
    # the inspect must be stripped, not just truncated. Source location
    # requires :sourcemap; fall back to the docfile document attribute
    # when node file/lineno are nil.
    file = node.file if node.respond_to?(:file)
    lineno = node.lineno if node.respond_to?(:lineno)
    if file
      source = lineno ? "#{file}:#{lineno}" : file.to_s
    else
      source = node.document.attr('docfile')
    end
    # Keep only the part before the embedded object dump, then mask any
    # other inspect so stderr never leaks a raw node dump.
    message = e.message.to_s.split(' for #<', 2).first
    message = message.gsub(/#<[^>]*>/, '#<node>')
    message = "#{message.slice(0, 300)}..." if message.length > 300
    location = source ? " (#{source})" : ''
    warn "huawei-latex-converter: failed to convert #{transform} node#{location}: #{e.class}: #{message}"
    exit 1
  end

  # --- DOCUMENT — generate full LaTeX file with preamble ---
  def convert_document(node)
    # --- Determine template and class options ---
    template   = node.attr('template', 'guide')
    lang       = node.attr('lang', 'en')
    noauthors  = node.attr?('noauthors')
    notime     = node.attr?('notime')
    nochangelog= node.attr?('nochangelog')

    class_options = []
    class_options << 'portuguese' if lang == 'pt'
    class_options << 'notime'      if notime
    class_options << 'nochangelog' if nochangelog
    class_options << 'noauthors'   if noauthors
    class_options << 'noanswers'   if node.attr?('noanswers')
    class_options << 'indentbody'  if node.attr?('indentbody')

    class_opt_str = class_options.empty? ? '' : "[#{class_options.join(',')}]"

    # --- Document metadata ---
    doctitle   = node.doctitle
    # 'authors' holds ALL authors, comma-separated ("John Doe, Jane Smith");
    # 'author' holds only the first. \setdocauthors renders the string
    # verbatim on the cover, so the comma-separated form matches.
    authors    = node.attr('authors') || node.attr('author')
    version    = node.attr('version')
    revdate    = node.attr('date') || node.attr('revdate')
    header_title = node.attr('header-title')
    cover_text   = node.attr('cover-text')

    # --- Body content ---
    # Convert the body FIRST: convert_pass hoists technical-report cover
    # setters (\setreportversion/date/scenario/type) out of passthrough
    # blocks into @report_setters. They are emitted in the preamble below
    # so they run before \makecover — the cover reads \lg@report*, and
    # setters left in the body (after \startbody) would render the cover's
    # Version/Date/Scenario fields empty.
    @report_setters = []
    body = node.content

    # --- Build preamble ---
    lines = []
    lines << "\\documentclass#{class_opt_str}{#{template}}"
    lines << ''
    lines << "\\setdoctitle{#{escape_text_string(doctitle)}}" if doctitle
    lines << "\\setdocauthors{#{escape_text_string(authors)}}" if authors && !noauthors
    lines << "\\setdocversion{#{escape_text_string(version)}}" if version
    if revdate
      lines << "\\setdocdate{#{escape_text_string(revdate)}}"
    end
    lines << "\\setheadertitle{#{escape_text_string(header_title)}}" if header_title
    lines << "\\setcovertext{#{escape_text_string(cover_text)}}" if cover_text
    header_logo = node.attr('header-logo')
    if header_logo
      lines << "\\setheaderlogo{#{header_logo}}"
    end
    cover_logo = node.attr('cover-logo')
    if cover_logo
      lines << "\\setcoverlogo{#{cover_logo}}"
    end
    # Cover setters hoisted from body passthroughs (see above). Reset the
    # stash so later conversions with the same instance never hoist into
    # a stale list (embedded mode has no preamble to emit them in).
    lines.concat(@report_setters)
    @report_setters = nil
    lines << ''
    lines << '\\begin{document}'
    lines << '\\makecover'
    lines << '\\maketoc'
    lines << '\\startbody'
    lines << ''

    # --- Body content ---
    lines << body

    # --- Document end ---
    lines << ''
    lines << '\\end{document}'

    lines.join("\n")
  end

  # --- EMBEDDED — content without preamble (for includes) ---
  def convert_embedded(node)
    node.content
  end

  # --- Helper: hyperref anchor for a node with an explicit block id ---
  # Emits \label + \hypertarget under the sanitized id so \hyperlink
  # cross-references (<<id>>) resolve. Do NOT promise \ref numbering:
  # for captioned tables the anchor is emitted before \begin{table}[H],
  # so \label captures the current section counter — a hand-written
  # \ref{my-table} yields the section number, not "Table 3".
  # Returns '' when node.id is unset.
  def anchor_for(node)
    return '' unless node.id && !node.id.empty?
    label = sanitize_label(node.id)
    "\\label{#{label}}\\hypertarget{#{label}}{}"
  end

  # --- Helper: prepend a block's anchor (if any) to its converted output ---
  # Block anchors ([[id]] before a table/image/listing) must be emitted or
  # \hyperlink xrefs point at a target that never exists (dead reference).
  def with_anchor(node, output)
    anchor = anchor_for(node)
    anchor.empty? ? output : "#{anchor}\n#{output}"
  end

  # --- SECTION — \section, \subsection, \subsubsection, \paragraph ---
  def convert_section(node)
    # Level 0 is the document title (already in preamble)
    return '' if node.level == 0

    title = escape_text_string(node.title)
    body = node.content
    # Emit a hyperref anchor so <<section-id>> cross-references resolve.
    # Asciidoctor auto-generates ids for all sections; sanitize them so the
    # same name is used here and by \hyperlink in convert_inline_anchor.
    # The anchor goes AFTER the sectioning command: \section is redefined to
    # \clearpage\lg@origsection (huawei-titles.sty), so an anchor before it
    # would land on the previous page and \label would capture the wrong counter.
    anchor = anchor_for(node)
    case node.level
    when 1 then "\\section{#{title}}#{anchor}\n#{body}"
    when 2 then "\\subsection{#{title}}#{anchor}\n#{body}"
    when 3 then "\\subsubsection{#{title}}#{anchor}\n#{body}"
    when 4 then "\\paragraph{#{title}}#{anchor}\n#{body}"
    else "\\paragraph{#{title}}#{anchor}\n#{body}"  # deeper levels map to \paragraph
    end
  end

  # --- Helper: escape inline content from an AsciiDoc node ---
  #
  # Gets node.content, unescapes HTML entities that asciidoctor adds,
  # then escapes LaTeX special characters that are NOT preceded by a
  # backslash (to avoid double-escaping already-generated LaTeX
  # commands like \textbf).
  def escape_inline_content(node)
    content = node.content
    return '' if content.nil? || content.empty?
    # Unescape HTML entities that asciidoctor adds, then escape LaTeX special
    # chars not preceded by a backslash (avoids double-escaping generated
    # commands like \textbf). Don't escape { } — they appear in generated LaTeX.
    escape_text_string(content)
  end

  # --- PARAGRAPH — plain text paragraph ---
  def convert_paragraph(node)
    content = escape_inline_content(node)
    return '' if content.nil? || content.strip.empty?
    content
  end

  # --- ADMONITION — NOTE/TIP/WARNING/CAUTION/IMPORTANT → callout boxes ---
  # Two shapes, two paths:
  # - Single-paragraph form (NOTE: text): the admonition node itself is a
  #   :simple block with no children — node.content returns the raw subbed
  #   string WITHOUT converter dispatch, so it must be escaped here.
  # - Delimited form ([NOTE] + ===): :compound with block children —
  #   node.content dispatches them through their converters (which escape
  #   properly, like convert_example/convert_quote). Re-escaping that
  #   already-converted LaTeX would corrupt nested tables (raw & cell
  #   delimiters → \&, merging cells) and code blocks (# → \#).
  def convert_admonition(node)
    admon_type = node.attr('name') || 'note'
    env = ADMONITION_MAP[admon_type] || 'infobox'
    content = node.blocks.any? ? node.content : escape_inline_content(node)
    "\\begin{#{env}}\n#{content}\n\\end{#{env}}"
  end

  # --- LISTING — source code blocks → \begin{code}[lang]...\end{code} ---
  def convert_listing(node)
    # Check for codefile class → \codefile[lang]{path}
    if node.role == 'codefile' || (node.attributes && node.attributes['1'] == 'codefile')
      file = node.attr('file')
      lang = node.attr('lang')
      if file
        return with_anchor(node, lang ? "\\codefile[#{lang}]{#{file}}" : "\\codefile{#{file}}")
      end
    end

    # Only the explicit [.codefile] role triggers \codefile conversion.
    # (Do NOT scan for include:: in source — it's literal text inside
    # code blocks, not an AsciiDoc directive.)

    language = node.attr('language')
    # Code content is verbatim — use raw source, no escaping
    source = node.source || ''
    code_text = source

    if language
      with_anchor(node, "\\begin{code}[#{language}]\n#{code_text}\n\\end{code}")
    else
      with_anchor(node, "\\begin{code}\n#{code_text}\n\\end{code}")
    end
  end

  # --- LITERAL — literal/layout blocks → verbatim ---
  def convert_literal(node)
    content = node.source || ''
    "\\begin{code}\n#{content}\n\\end{code}"
  end

  # --- TABLE — with .hutable or .longhutable role → Huawei table env ---

  # Column spec for a \multicolumn cell spanning `span` columns starting at
  # 1-based `col` in a table with `num_cols` equal-width m{} columns (the
  # per-column spec built in convert_table). The spanned width folds in the
  # (span - 1) skipped column boundaries — one \arrayrulewidth + two
  # \tabcolsep each — so the cell fills the covered columns exactly. A span
  # reaching the last column must keep the closing vertical rule, because
  # \multicolumn replaces the preamble entries of all covered columns.
  def table_multicolumn_spec(span, col, num_cols)
    width_expr = "\\dimexpr((\\linewidth-#{num_cols + 1}\\arrayrulewidth-#{2 * num_cols}\\tabcolsep)*#{span}/#{num_cols}+#{2 * (span - 1)}\\tabcolsep+#{span - 1}\\arrayrulewidth)\\relax"
    spec = "|>{\\RaggedRight\\arraybackslash}m{#{width_expr}}"
    spec += '|' if col + span - 1 >= num_cols
    spec
  end

  # Convert one table row to its LaTeX cells joined by ' & '.
  # Colspan cells (2+| in AsciiDoc) are emitted as \multicolumn so the row
  # keeps the right shape — a 1:1 mapping used to shift content left and
  # birth phantom cells. Rowspan (.2+) is NOT supported (the multirow
  # package is not loaded): warn — the cell renders without the span and
  # every following row shifts left (the next row's first cell lands
  # under the rowspan cell).
  def convert_table_row(row, num_cols, header)
    col = 1
    cells = row.map do |cell|
      content = escape_table_cell(cell.content)
      content = "\\thd{#{content}}" if header
      if cell.rowspan && cell.rowspan > 1
        warn 'huawei-latex-converter: rowspan is not supported (the multirow package is not loaded); the cell renders without the span and subsequent rows shift left (the next row starts under the rowspan cell)'
      end
      span = cell.colspan || 1
      out = if span > 1
              "\\multicolumn{#{span}}{#{table_multicolumn_spec(span, col, num_cols)}}{#{content}}"
            else
              content
            end
      col += span
      out
    end
    cells.join(' & ')
  end

  def convert_table(node)
    role = node.role
    num_cols = node.columns ? node.columns.size : 1
    # Use p{...} columns with auto-wrap instead of l (natural width)
    # Equal-width columns computed from \linewidth
    width_expr = "\\dimexpr(\\linewidth-#{num_cols+1}\\arrayrulewidth-#{2*num_cols}\\tabcolsep)/#{num_cols}\\relax"
    col_spec = "|>{\\RaggedRight\\arraybackslash}m{#{width_expr}}" * num_cols + "|"

    env_name = role == 'longhutable' ? 'longhutable' : 'hutable'

    lines = []
    lines << "\\begin{#{env_name}}{#{col_spec}}"

    # Process rows: head row with \thd, body rows with \tbody
    rows_head = node.rows.head
    rows_body = node.rows.body
    rows_foot = node.rows.foot

    # Header rows
    unless rows_head.empty?
      rows_head.each do |header_row|
        lines << "\\rowcolor{huaweired} #{convert_table_row(header_row, num_cols, true)} \\\\"
      end
      if env_name == 'longhutable'
        lines << '\\endhead'
      end
    end

    # Body rows
    unless rows_body.empty?
      lines << '\\tbody'
      rows_body.each do |row|
        lines << "#{convert_table_row(row, num_cols, false)} \\\\"
      end
    end

    # Footer rows (rare, but handle them)
    rows_foot.each do |row|
      lines << "#{convert_table_row(row, num_cols, false)} \\\\"
    end

    lines << "\\end{#{env_name}}"

    # Wrap in \begin{table}[H] if there's a title (caption)
    if node.title?
      caption = escape_text_string(node.title)
      wrapped = []
      wrapped << '\\begin{table}[H]'
      wrapped += lines
      wrapped << "\\caption{#{caption}}"
      wrapped << '\\end{table}'
      return with_anchor(node, "\n#{wrapped.join("\n")}\n")
    end

    with_anchor(node, "\n#{lines.join("\n")}\n")
  end

  # --- IMAGE — block image → \image or \imagecap ---
  def convert_image(node)
    target = node.attr('target') || ''
    width  = node.attr('width')
    title  = node.title

    # Build optional width parameter
    width_opt = ''
    if width
      if width =~ /^(\d+)%$/  # percentage like "50%"
        frac = $1.to_i / 100.0
        width_opt = "[width=#{frac}\\linewidth]"
      elsif width =~ /^\d+$/  # pure number = pixels
        width_opt = "[width=#{pixel_width_to_linewidth(width)}]"
      else
        width_opt = "[width=#{width}]"
      end
    end

    if title && !title.empty?
      # Use \diagramcap for diagram-generated images, \imagecap for regular images
      if node.role && node.role.include?('diagram')
        result = "\\diagramcap#{width_opt}{#{target}}{#{escape_text_string(title)}}"
      else
        result = "\\imagecap#{width_opt}{#{target}}{#{escape_text_string(title)}}"
      end
    else
      result = "\\image#{width_opt}{#{target}}"
    end
    with_anchor(node, result)
  end

  # --- UNORDERED LIST → \begin{itemize} ---
  # [.evidence] renders as a standard bullet list (checkbox markers
  # removed in v6.5.0 — plain bullets for compatibility, matching the
  # DOCX output).
  def convert_ulist(node)
    items = node.items.map do |item|
      text = process_text(item.text)
      nested = item.blocks.any? ? "\n#{item.content}" : ''
      "\\item #{text}#{nested}"
    end
    "\\begin{itemize}\n#{items.join("\n")}\n\\end{itemize}"
  end

  # --- ORDERED LIST → \begin{enumerate} ---
  # Special role: [.activities] → roman numeral enumerate
  def convert_olist(node)
    items = node.items.map do |item|
      text = process_text(item.text)
      nested = item.blocks.any? ? "\n#{item.content}" : ''
      "\\item #{text}#{nested}"
    end
    if node.role == 'activities'
      "\\begin{enumerate}[label=\\roman*., leftmargin=2.5em, itemsep=0.5em]\n#{items.join("\n")}\n\\end{enumerate}"
    else
      "\\begin{enumerate}\n#{items.join("\n")}\n\\end{enumerate}"
    end
  end

  # --- DEFINITION LIST → \begin{description} ---
  def convert_dlist(node)
    # Each item is [terms, desc]: terms is an Array of ListItem, desc a
    # ListItem (or nil). ListItem#content is always "" — the text lives in
    # ListItem#text (the trap documented at convert_content_under_label).
    # ListItem#text resolves inline markup through the converter
    # (*bold* → \textbf{bold}), so the term and the plain-text definition
    # must go through the plain-text escape helpers (escape_text_string /
    # process_text), which never escape backslash or braces; the old
    # latex_escape(term) mangled converted commands into literal garbage.
    # A desc may carry text, nested blocks, or both (continuation blocks):
    # emit the text plus the converted blocks, like convert_ulist does —
    # desc.content alone would drop the text when blocks are attached.
    items = node.items.map do |terms, desc|
      term_text = escape_text_string(terms.map(&:text).join(', '))
      desc_text = desc ? process_text(desc.text) : ''
      desc_text += "\n#{desc.content}" if desc && desc.blocks.any?
      "\\item[#{term_text}] #{desc_text}"
    end
    "\\begin{description}\n#{items.join("\n")}\n\\end{description}"
  end

  # --- CALLOUT LIST → numbered list with callout numbers ---
  def convert_colist(node)
    items = node.items.map do |item|
      "\\item #{process_text(item.text)}"
    end
    "\\begin{enumerate}\n#{items.join("\n")}\n\\end{enumerate}"
  end

  # --- EXAMPLE BLOCK → tcolorbox-like ---
  def convert_example(node)
    content = node.content
    if node.title?
      "\\begin{infobox}\n#{escape_text_string(node.title)}\n\n#{content}\n\\end{infobox}"
    else
      content
    end
  end

  # --- Technical template section roles — all emit \begin{role}\n...\n\end{role} ---
  TECHNICAL_ROLES = %w[problem rootcauseanalysis rootcause triggercondition
    workaround impact backupdata workaroundsteps verification rollback cleanup].freeze

  TECHNICAL_ROLES.each do |role|
    define_method("convert_role_#{role}") do |node|
      "\\begin{#{role}}\n#{node.content}\n\\end{#{role}}"
    end
  end

  # --- POC objective role → \begin{objectiveblock} (block) / \objective (inline) ---
  # Block form (POC highlighted goal box): [.objective] on its own line.
  # Inline span form: [.objective]#text# → bold "Objective:" label + text
  # (\objective works standalone, see huawei-shared.sty).
  def convert_role_objective(node)
    if node.node_name == 'inline_quoted'
      return "\\objective{#{process_text(node.text)}}"
    end
    "\\begin{objectiveblock}\n#{node.content}\n\\end{objectiveblock}"
  end

  # --- QUOTE BLOCK ---
  def convert_quote(node)
    content = node.content
    attribution = node.attr('attribution') || node.attr('cite')
    if attribution
      "#{content}\n\\par\\raggedleft --- #{latex_escape(attribution)}"
    else
      content
    end
  end

  # --- OPEN BLOCK — default: pass through content ---
  def convert_open(node)
    # Default: just pass through content
    node.content
  end

  # --- PASSTHROUGH BLOCK — raw LaTeX ---
  # A passthrough block whose lines are technical-report cover setters
  # (\setreportversion/date/scenario/type{...}) has its setter lines
  # hoisted into @report_setters — emitted by convert_document in the
  # preamble, before \makecover — and removed from the body. Any other
  # content in the block stays in place, so mixed blocks keep their
  # non-setter lines and the changelog passthrough (\begin{changelog}...)
  # passes through untouched. Hoisting only happens while convert_document
  # is collecting the body (@report_setters non-nil); in embedded mode
  # there is no preamble, so passthroughs pass through unchanged.
  # A passthrough that mentions \setreport* but has no hoistable line
  # (trailing text after the closing brace, nested braces, ...) would
  # silently leave the cover field empty — warn so the author can fix
  # the line.
  REPORT_SETTER_LINE_RE = /\A\\setreport(?:version|date|scenario|type)\{[^{}]*\}\z/

  def convert_pass(node)
    content = node.content
    return content unless @report_setters
    lines = content.to_s.lines
    hoisted = lines.select { |line| REPORT_SETTER_LINE_RE.match?(line.strip) }
    if hoisted.empty?
      if content.to_s.include?('\\setreport')
        warn 'huawei-latex-converter: passthrough contains \setreport* but the line could not be hoisted (unsupported form); the cover field will render empty'
      end
      return content
    end
    @report_setters.concat(hoisted.map(&:strip))
    lines.reject { |line| REPORT_SETTER_LINE_RE.match?(line.strip) }.join
  end

  # --- FLOATING TITLE — unnumbered heading ---
  def convert_floating_title(node)
    title = escape_text_string(node.title)
    case node.level
    when 1 then "\\section*{#{title}}"
    when 2 then "\\subsection*{#{title}}"
    when 3 then "\\subsubsection*{#{title}}"
    else "\\paragraph*{#{title}}"
    end
  end

  # --- THEMATIC BREAK — horizontal rule ---
  def convert_thematic_break(_node)
    "\n\\noindent\\rule{\\linewidth}{0.5pt}\n"
  end

  # --- PAGE BREAK ---
  def convert_page_break(_node)
    '\\clearpage'
  end

  # --- INLINE QUOTED — bold, italic, code, highlight, etc. ---
  def convert_inline_quoted(node)
    text = latex_escape_text(node.text)
    case node.type
    when :strong
      "\\textbf{#{text}}"
    when :emphasis
      "\\emph{#{text}}"
    when :monospaced
      "\\inlinecode{#{latex_escape(node.text)}}"
    when :double
      "``#{text}''"
    when :single
      "`#{text}'"
    when :mark
      "\\textcolor{huaweired}{#{text}}"
    when :superscript
      "\\textsuperscript{#{text}}"
    when :subscript
      "\\textsubscript{#{text}}"
    else
      text
    end
  end

  # --- INLINE ANCHOR — links and cross-references ---
  def convert_inline_anchor(node)
    case node.type
    when :link
      target = node.target
      # Get link text; fall back to URL itself
      link_text = node.text.nil? || node.text.empty? ? target : node.text
      # Escape TeX-special chars in URL (%, #, &, _) but not URL-valid chars
      "\\weblink{#{latex_escape_url(target)}}{#{latex_escape(link_text)}}"
    when :xref
      # Cross-reference: <<anchor,text>>
      # Asciidoctor stores the id in target with a leading '#' (internal refs);
      # strip it so the name matches the \hypertarget emitted by convert_section.
      target = node.target.to_s.sub(/\A#/, '')
      text   = node.text || target
      "\\hyperlink{#{sanitize_label(target)}}{#{latex_escape(text)}}"
    when :ref
      # Anchor definition: [[id]] — Asciidoctor stores the id in node.id.
      # Emit both \label (for \ref) and \hypertarget (for \hyperlink) under the
      # same sanitized name so xrefs resolve regardless of mechanism.
      label = sanitize_label(node.id)
      "\\label{#{label}}\\hypertarget{#{label}}{}"
    when :bibref
      label = sanitize_label(node.id)
      "\\label{#{label}}\\hypertarget{#{label}}{}"
    else
      node.text || ''
    end
  end

  # --- INLINE IMAGE ---
  def convert_inline_image(node)
    target = node.attr('target') || ''
    "\\image{#{target}}"
  end

  # --- INLINE BREAK — line break ---
  def convert_inline_break(node)
    "#{latex_escape_text(node.text)}\\\\"
  end

  # --- INLINE BUTTON ---
  def convert_inline_button(node)
    "\\textbf{#{latex_escape(node.text)}}"
  end

  # --- INLINE CALLOUT ---
  def convert_inline_callout(node)
    "\\textsuperscript{#{latex_escape(node.text)}}"
  end

  # --- INLINE FOOTNOTE ---
  # NOTE: footnoteref:[id] and a second footnote:id[] arrive as type :xref and
  # currently emit a duplicate \footnote{} instead of a same-number reference.
  # Known limitation, not handled (no sample uses footnote refs).
  def convert_inline_footnote(node)
    "\\footnote{#{escape_text_string(node.text)}}"
  end

  # --- INLINE INDEX TERM ---
  def convert_inline_indexterm(node)
    # Index terms are invisible in output
    ''
  end

  # --- INLINE KBD — keyboard input ---
  def convert_inline_kbd(node)
    keys = node.attr('keys')
    text = keys.is_a?(Array) ? keys.join('+') : keys.to_s
    "\\inlinecode{#{escape_text_string(text)}}"
  end

  # --- INLINE MENU ---
  def convert_inline_menu(node)
    items = node.attr('menus')
    if items
      "\\menu{#{items.map { |i| latex_escape(i) }.join(', ')}}"
    else
      "\\textbf{#{latex_escape(node.text)}}"
    end
  end

  # --- ICON ---
  def convert_icon(_node)
    # Icons don't map cleanly to LaTeX — skip
    ''
  end

  # --- ROLE-BASED BLOCK CONVERTERS ---

  # --- [.objectives] open block → \begin{objectives}...\end{objectives} ---
  def convert_role_objectives(node)
    lines = []
    lines << '\\begin{objectives}'

    node.blocks.each do |block|
      # NOTE: block.text does not exist on Asciidoctor::Block (only
      # ListItem responds to .text) — use block.content, which returns
      # the paragraph text with inline nodes already converted.
      if block.role == 'general-objective'
        lines << "\\generalobjective{#{process_text(block.content)}}"
      elsif block.role == 'prerequisites'
        # Label + list items — route through the role dispatch so the
        # role works whether it sits on the list itself or on a wrapper.
        lines << convert(block)
      elsif block.role == 'objective'
        lines << "\\objective{#{process_text(block.content)}}"
      elsif block.role == 'stepbystep'
        # Label + list items — route through the role dispatch.
        lines << convert(block)
      else
        # Handle list blocks by calling the converter directly
        if block.node_name == 'ulist' || block.node_name == 'olist'
          lines << convert(block)
        else
          lines << block.content
        end
      end
    end

    lines << '\\end{objectives}'
    lines.join("\n")
  end

  # --- [.prerequisites] / [.stepbystep] block roles → label + list ---
  # Emits the language-aware label command (\prerequisites / \stepbystep,
  # see huawei-shared.sty) followed by the list items. The role may sit
  # directly on the list block (the documented form) or on a block
  # wrapping one.
  def convert_role_prerequisites(node)
    "\\prerequisites\n#{convert_content_under_label(node)}"
  end

  def convert_role_stepbystep(node)
    "\\stepbystep\n#{convert_content_under_label(node)}"
  end

  # Convert the content that follows a [.prerequisites]/[.stepbystep]
  # label. List nodes must be routed through convert_ulist/convert_olist:
  # Asciidoctor aliases List#content to List#blocks, which returns the raw
  # ListItem array — and ListItem#content is "" (item text lives in
  # ListItem#text) — so node.content on a list would drop every item.
  def convert_content_under_label(node)
    case node.node_name
    when 'ulist' then convert_ulist(node)
    when 'olist' then convert_olist(node)
    else node.content
    end
  end

  # --- ROLE-BASED INLINE (SPAN) CONVERTERS ---

  # --- [.general-objective]#text# → \generalobjective{text} ---
  # Inline span form used in guide/testbook/setup-guide sources. Also covers
  # a block-role paragraph outside [.objectives] (inside that block the
  # block form is handled by convert_role_objectives). \generalobjective
  # works standalone, see huawei-shared.sty.
  def convert_role_general_objective(node)
    text = node.node_name == 'inline_quoted' ? node.text : node.content
    "\\generalobjective{#{process_text(text)}}"
  end

  # --- [.badge]#text# → \badge{text} ---
  def convert_role_badge(node)
    "\\badge{#{process_text(node.text)}}"
  end

  # --- [.menu]#A ▸ B# → \menu{A, B} ---
  def convert_role_menu(node)
    text = node.text || ''
    # Split on ▸ (U+25B8) or ▻ (U+25BB) or >>
    parts = text.split(/[▸▻]|>>/).map(&:strip).reject(&:empty?)
    "\\menu{#{parts.map { |p| escape_text_string(p) }.join(', ')}}"
  end

  # --- [.note]#text# → \note{text} ---
  def convert_role_note(node)
    "\\note{#{process_text(node.text)}}"
  end

  # --- [.param]#text# → \param{text} ---
  def convert_role_param(node)
    "\\param{#{process_text(node.text)}}"
  end

  # --- [.badge-pass]#Pass# → \testresultbadge{Pass} ---
  def convert_role_badge_pass(node)
    "\\testresultbadge{#{process_text(node.text || 'Pass')}}"
  end

  def convert_role_badge_partial(node)
    "\\testresultbadge{#{process_text(node.text || 'Partial')}}"
  end

  def convert_role_badge_fail(node)
    "\\testresultbadge{#{process_text(node.text || 'Fail')}}"
  end

  # Kept for backwards compat: old documents still carrying the
  # [.badge-blocked] role convert fine; the cls renders its fallback
  # pill (Blocked was dropped from the testbook vocabulary).
  def convert_role_badge_blocked(node)
    "\\testresultbadge{#{process_text(node.text || 'Blocked')}}"
  end

  def convert_role_badge_untested(node)
    "\\testresultbadge{#{process_text(node.text || 'Untested')}}"
  end

  # --- POC result badges → \pocresult{Pass|Partial|Fail|Skip} ---
  # Role determines the output value; node.text is intentionally ignored
  # to prevent contradictory input like [.result-pass]#Fail#.
  def convert_role_result_pass(node)
    "\\pocresult{Pass}"
  end

  def convert_role_result_partial(node)
    "\\pocresult{Partial}"
  end

  def convert_role_result_fail(node)
    "\\pocresult{Fail}"
  end

  def convert_role_result_skip(node)
    "\\pocresult{Skip}"
  end
end
