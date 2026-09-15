# frozen_string_literal: true

# huawei-latex-converter.rb
# =====================================================================
#  Custom Asciidoctor backend that converts AsciiDoc (.adoc) to
#  LaTeX (.tex) using Huawei template class commands.
#
#  Usage:
#    asciidoctor -b huawei-latex \
#      -r templates/_base/huawei-latex-converter.rb \
#      doc.adoc -o doc.tex
#
#  Reads AsciiDoc document attributes for preamble generation and
#  maps AsciiDoc AST nodes to Huawei LaTeX commands.
# =====================================================================

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

# ─────────────────────────────────────────────────────────────────────
#  Helper: escape LaTeX special characters in text
# ─────────────────────────────────────────────────────────────────────
def latex_escape(text)
  return '' if text.nil? || text.empty?
  text.gsub(LATEX_ESCAPE_RE) { |ch| LATEX_ESCAPES[ch] }
end

# ─────────────────────────────────────────────────────────────────────
#  Helper: convert pixel width to linewidth fraction
#  Heuristic: 600px ≈ 0.8\linewidth, 400px ≈ 0.5\linewidth
# ─────────────────────────────────────────────────────────────────────
def pixel_width_to_linewidth(px)
  fraction = (px.to_i / 750.0).clamp(0.1, 1.0)
  # Round to one decimal place
  rounded = (fraction * 10).round / 10.0
  "#{rounded}\\linewidth"
end

# ─────────────────────────────────────────────────────────────────────
#  Helper: convert AsciiDoc table column specs to LaTeX column specs
#  AsciiDoc cols like "1,3,1" → LaTeX "|l|l|l|"
# ─────────────────────────────────────────────────────────────────────
def latex_col_spec(_node)
  # Default to left-aligned columns; number of columns determines the spec
  '|l'
end

# ─────────────────────────────────────────────────────────────────────
#  Helper: admonition type → LaTeX environment
# ─────────────────────────────────────────────────────────────────────
ADMONITION_MAP = {
  'note'      => 'infobox',
  'tip'       => 'tip',
  'warning'   => 'warning',
  'caution'   => 'warning',
  'important' => 'warning',
}.freeze

# ─────────────────────────────────────────────────────────────────────
#  Helper: badge role → LaTeX command
# ─────────────────────────────────────────────────────────────────────
BADGE_ROLE_MAP = {
  'badge-pass'    => 'testresultbadge',
  'badge-fail'    => 'testresultbadge',
  'badge-blocked' => 'testresultbadge',
  'badge-untested'=> 'testresultbadge',
}.freeze

# ─────────────────────────────────────────────────────────────────────
#  Helper: testfield label → LaTeX command/environment
# ─────────────────────────────────────────────────────────────────────
TESTFIELD_MAP = {
  'Objective'     => :objective,
  'Prerequisites' => :prerequisites,
  'Procedure'     => :procedure,
  'Expected'      => :expected,
  'Result'        => :result,
  'Remarks'       => :remarks,
}.freeze

# =====================================================================
#  Register the 'huawei-latex' converter backend
# =====================================================================
class HuaweiLatexConverter < Asciidoctor::Converter::Base
  register_for 'huawei-latex'

  # ───────────────────────────────────────────────────────────────────
  #  Main dispatch: route node transforms to specific converters
  # ───────────────────────────────────────────────────────────────────
  def convert node, transform = node.node_name, opts = {}
    # Check for custom role-based block converters first
    if node.respond_to?(:role) && node.role && respond_to?("convert_role_#{node.role}", true)
      return send("convert_role_#{node.role}", node)
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
  end

  # ===================================================================
  #  DOCUMENT — generate full LaTeX file with preamble
  # ===================================================================
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

    class_opt_str = class_options.empty? ? '' : "[#{class_options.join(',')}]"

    # --- Document metadata ---
    doctitle   = node.doctitle
    authors    = node.attr('author') || node.attr('authors')
    version    = node.attr('version')
    revdate    = node.attr('revdate')
    header_title = node.attr('header-title')
    cover_text   = node.attr('cover-text')

    # --- Build preamble ---
    lines = []
    lines << "\\documentclass#{class_opt_str}{#{template}}"
    lines << ''
    lines << "\\setdoctitle{#{latex_escape(doctitle)}}" if doctitle
    lines << "\\setdocauthors{#{latex_escape(authors)}}" if authors && !noauthors
    lines << "\\setdocversion{#{latex_escape(version)}}" if version
    if revdate
      lines << "\\setdocdate{#{latex_escape(revdate)}}"
    end
    lines << "\\setheadertitle{#{latex_escape(header_title)}}" if header_title
    lines << "\\setcovertext{#{latex_escape(cover_text)}}" if cover_text
    lines << ''
    lines << '\\begin{document}'
    lines << '\\makecover'
    lines << '\\maketoc'
    lines << '\\startbody'
    lines << ''

    # --- Body content ---
    lines << node.content

    # --- Document end ---
    lines << ''
    lines << '\\end{document}'

    lines.join("\n")
  end

  # ===================================================================
  #  EMBEDDED — content without preamble (for includes)
  # ===================================================================
  def convert_embedded(node)
    node.content
  end

  # ===================================================================
  #  SECTION — \section, \subsection, \subsubsection, \paragraph
  # ===================================================================
  def convert_section(node)
    # Level 0 is the document title (already in preamble)
    return '' if node.level == 0

    title = latex_escape(node.title)
    body = node.content
    case node.level
    when 1 then "\\section{#{title}}\n#{body}"
    when 2 then "\\subsection{#{title}}\n#{body}"
    when 3 then "\\subsubsection{#{title}}\n#{body}"
    when 4 then "\\paragraph{#{title}}\n#{body}"
    else "\\paragraph{#{title}}\n#{body}"  # deeper levels map to \paragraph
    end
  end

  # ===================================================================
  #  Helper: escape inline content from an AsciiDoc node
  #
  #  Gets node.content, unescapes HTML entities that asciidoctor adds,
  #  then escapes LaTeX special characters that are NOT preceded by a
  #  backslash (to avoid double-escaping already-generated LaTeX
  #  commands like \textbf).
  # ===================================================================
  def escape_inline_content(node)
    content = node.content
    return '' if content.nil? || content.empty?
    # Unescape HTML entities that asciidoctor adds
    content = content.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&amp;', '&').gsub('&quot;', '"')
    # Escape LaTeX special chars not preceded by a backslash
    content.gsub(/(?<!\\)([%$#&_{}~^])/) { |ch| LATEX_ESCAPES[ch] }
  end

  # ===================================================================
  #  PARAGRAPH — plain text paragraph
  # ===================================================================
  def convert_paragraph(node)
    content = escape_inline_content(node)
    return '' if content.nil? || content.strip.empty?
    content
  end

  # ===================================================================
  #  ADMONITION — NOTE/TIP/WARNING/CAUTION/IMPORTANT → callout boxes
  # ===================================================================
  def convert_admonition(node)
    admon_type = node.attr('name') || 'note'
    env = ADMONITION_MAP[admon_type] || 'infobox'
    content = escape_inline_content(node)
    "\\begin{#{env}}\n#{content}\n\\end{#{env}}"
  end

  # ===================================================================
  #  LISTING — source code blocks → \begin{code}[lang]...\end{code}
  # ===================================================================
  def convert_listing(node)
    # Check for include:: directive inside source block → \codefile
    source = node.source || ''
    if source.include?('include::')
      # Extract include target
      source.scan(/include::([^\[]+)/).each do |match|
        return "\\codefile{#{match.first}}"
      end
    end

    language = node.attr('language')
    # Code content is verbatim — use raw source, no escaping
    code_text = source

    if language
      "\\begin{code}[#{language}]\n#{code_text}\n\\end{code}"
    else
      "\\begin{code}\n#{code_text}\n\\end{code}"
    end
  end

  # ===================================================================
  #  LITERAL — literal/layout blocks → verbatim
  # ===================================================================
  def convert_literal(node)
    content = node.source || ''
    "\\begin{code}\n#{content}\n\\end{code}"
  end

  # ===================================================================
  #  TABLE — with .hutable or .longhutable role → Huawei table env
  # ===================================================================
  def convert_table(node)
    role = node.role
    num_cols = node.columns ? node.columns.size : 1
    col_spec = "|#{'l|' * num_cols}"

    # Test summary table
    if role == 'testsummary'
      return convert_testsummary(node)
    end

    # Determine table environment
    if role == 'hutable'
      env_name = 'hutable'
    elsif role == 'longhutable'
      env_name = 'longhutable'
    else
      # Default to hutable for any table
      env_name = 'hutable'
    end

    lines = []
    lines << "\\begin{#{env_name}}{#{col_spec}}"

    # Process rows: head row with \thd, body rows with \tbody
    rows_head = node.rows.head
    rows_body = node.rows.body
    rows_foot = node.rows.foot

    # Header row
    unless rows_head.empty?
      header_cells = rows_head.first.map { |cell| "\\thd{#{latex_escape(cell.text)}}" }
      lines << "\\rowcolor{huaweired} #{header_cells.join(' & ')} \\\\"
      if env_name == 'longhutable'
        lines << '\\endhead'
      end
    end

    # Body rows
    unless rows_body.empty?
      lines << '\\tbody'
      rows_body.each do |row|
        cells = row.map { |cell| latex_escape(cell.text) }
        lines << "#{cells.join(' & ')} \\\\"
      end
    end

    # Footer rows (rare, but handle them)
    rows_foot.each do |row|
      cells = row.map { |cell| latex_escape(cell.text) }
      lines << "#{cells.join(' & ')} \\\\"
    end

    lines << "\\end{#{env_name}}"

    # Wrap in \begin{table}[H] if there's a title (caption)
    if node.title?
      caption = latex_escape(node.title)
      wrapped = []
      wrapped << '\\begin{table}[H]'
      wrapped += lines
      wrapped << "\\caption{#{caption}}"
      wrapped << '\\end{table}'
      return wrapped.join("\n")
    end

    lines.join("\n")
  end

  # ===================================================================
  #  TEST SUMMARY — [.testsummary] table → \begin{testsummary}...
  # ===================================================================
  def convert_testsummary(node)
    rows_body = node.rows.body
    lines = []
    lines << '\\begin{testsummary}'
    rows_body.each do |row|
      # First col = ID, second = title, third = status
      id    = row[0] ? latex_escape(row[0].text) : ''
      title = row[1] ? latex_escape(row[1].text) : ''
      # Status may contain badge markup — extract text
      status = row[2] ? latex_escape(row[2].text) : ''
      lines << "\\testsummaryrow{#{id}}{#{title}}{#{status}}"
    end
    lines << '\\end{testsummary}'
    lines.join("\n")
  end

  # ===================================================================
  #  IMAGE — block image → \image or \imagecap
  # ===================================================================
  def convert_image(node)
    target = node.attr('target') || ''
    width  = node.attr('width')
    title  = node.title

    # Build optional width parameter
    width_opt = ''
    if width
      if width =~ /^\d+$/  # pure number = pixels
        width_opt = "[width=#{pixel_width_to_linewidth(width)}]"
      else
        width_opt = "[width=#{width}]"
      end
    end

    if title && !title.empty?
      "\\imagecap#{width_opt}{#{target}}{#{latex_escape(title)}}"
    else
      "\\image#{width_opt}{#{target}}"
    end
  end

  # ===================================================================
  #  UNORDERED LIST → \begin{itemize}
  # ===================================================================
  def convert_ulist(node)
    items = node.items.map do |item|
      text = latex_escape(item.text)
      # Check for nested content (compound list items)
      nested = item.blocks.any? ? "\n#{item.content}" : ''
      "\\item #{text}#{nested}"
    end
    "\\begin{itemize}\n#{items.join("\n")}\n\\end{itemize}"
  end

  # ===================================================================
  #  ORDERED LIST → \begin{enumerate}
  # ===================================================================
  def convert_olist(node)
    items = node.items.map do |item|
      text = latex_escape(item.text)
      nested = item.blocks.any? ? "\n#{item.content}" : ''
      "\\item #{text}#{nested}"
    end
    "\\begin{enumerate}\n#{items.join("\n")}\n\\end{enumerate}"
  end

  # ===================================================================
  #  DEFINITION LIST → used for changelog entries
  # ===================================================================
  def convert_dlist(node)
    # Check if parent has .changelog role — handled by convert_role_changelog
    # Default: render as description list
    items = node.items.map do |terms, desc|
      term_text = terms.map(&:text).join(', ')
      desc_text = desc ? desc.text : ''
      "\\item[#{latex_escape(term_text)}] #{desc_text}"
    end
    "\\begin{description}\n#{items.join("\n")}\n\\end{description}"
  end

  # ===================================================================
  #  CALLOUT LIST → numbered list with callout numbers
  # ===================================================================
  def convert_colist(node)
    items = node.items.map do |item|
      "\\item #{item.text}"
    end
    "\\begin{enumerate}\n#{items.join("\n")}\n\\end{enumerate}"
  end

  # ===================================================================
  #  EXAMPLE BLOCK → tcolorbox-like
  # ===================================================================
  def convert_example(node)
    content = node.content
    if node.title?
      "\\begin{infobox}\n#{latex_escape(node.title)}\n\n#{content}\n\\end{infobox}"
    else
      content
    end
  end

  # ===================================================================
  #  QUOTE BLOCK
  # ===================================================================
  def convert_quote(node)
    content = node.content
    attribution = node.attr('attribution') || node.attr('cite')
    if attribution
      "#{content}\n\\par\\raggedleft --- #{latex_escape(attribution)}"
    else
      content
    end
  end

  # ===================================================================
  #  OPEN BLOCK — check for custom roles (.changelog, .testcase, .objectives)
  # ===================================================================
  def convert_open(node)
    role = node.role
    if role && respond_to?("convert_role_#{role}", true)
      return send("convert_role_#{role}", node)
    end
    # Default: just pass through content
    node.content
  end

  # ===================================================================
  #  PASSTHROUGH BLOCK — raw LaTeX
  # ===================================================================
  def convert_pass(node)
    node.content
  end

  # ===================================================================
  #  FLOATING TITLE — unnumbered heading
  # ===================================================================
  def convert_floating_title(node)
    title = latex_escape(node.title)
    case node.level
    when 1 then "\\section*{#{title}}"
    when 2 then "\\subsection*{#{title}}"
    when 3 then "\\subsubsection*{#{title}}"
    else "\\paragraph*{#{title}}"
    end
  end

  # ===================================================================
  #  THEMATIC BREAK — horizontal rule
  # ===================================================================
  def convert_thematic_break(_node)
    "\n\\noindent\\rule{\\linewidth}{0.5pt}\n"
  end

  # ===================================================================
  #  PAGE BREAK
  # ===================================================================
  def convert_page_break(_node)
    '\\clearpage'
  end

  # ===================================================================
  #  INLINE QUOTED — bold, italic, code, highlight, etc.
  # ===================================================================
  def convert_inline_quoted(node)
    text = node.text
    case node.type
    when :strong
      "\\textbf{#{text}}"
    when :emphasis
      "\\emph{#{text}}"
    when :monospaced
      "\\inlinecode{#{text}}"
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

  # ===================================================================
  #  INLINE ANCHOR — links and cross-references
  # ===================================================================
  def convert_inline_anchor(node)
    case node.type
    when :link
      target = node.target
      # Get link text; fall back to URL itself
      link_text = node.text.nil? || node.text.empty? ? target : node.text
      # Don't escape URLs
      "\\weblink{#{target}}{#{latex_escape(link_text)}}"
    when :xref
      # Cross-reference: <<anchor,text>>
      target = node.target
      text   = node.text || target
      "\\hyperlink{#{target}}{#{latex_escape(text)}}"
    when :ref
      # Anchor definition: [[id]]
      "\\label{#{node.target}}"
    when :bibref
      "\\label{#{node.target}}"
    else
      node.text || ''
    end
  end

  # ===================================================================
  #  INLINE IMAGE
  # ===================================================================
  def convert_inline_image(node)
    target = node.attr('target') || ''
    "\\image{#{target}}"
  end

  # ===================================================================
  #  INLINE BREAK — line break
  # ===================================================================
  def convert_inline_break(node)
    "#{node.text}\\\\"
  end

  # ===================================================================
  #  INLINE BUTTON
  # ===================================================================
  def convert_inline_button(node)
    "\\textbf{#{latex_escape(node.text)}}"
  end

  # ===================================================================
  #  INLINE CALLOUT
  # ===================================================================
  def convert_inline_callout(node)
    "\\textsuperscript{#{node.text}}"
  end

  # ===================================================================
  #  INLINE FOOTNOTE
  # ===================================================================
  def convert_inline_footnote(node)
    "\\footnote{#{node.content}}"
  end

  # ===================================================================
  #  INLINE INDEX TERM
  # ===================================================================
  def convert_inline_indexterm(node)
    # Index terms are invisible in output
    ''
  end

  # ===================================================================
  #  INLINE KBD — keyboard input
  # ===================================================================
  def convert_inline_kbd(node)
    "\\inlinecode{#{node.text}}"
  end

  # ===================================================================
  #  INLINE MENU
  # ===================================================================
  def convert_inline_menu(node)
    items = node.attr('menus')
    if items
      "\\menu{#{items.join(', ')}}"
    else
      "\\textbf{#{latex_escape(node.text)}}"
    end
  end

  # ===================================================================
  #  ICON
  # ===================================================================
  def convert_icon(_node)
    # Icons don't map cleanly to LaTeX — skip
    ''
  end

  # ===================================================================
  #  ROLE-BASED BLOCK CONVERTERS
  # ===================================================================

  # ───────────────────────────────────────────────────────────────────
  #  [.changelog] open block → \begin{changelog}...\end{changelog}
  #
  #  Expected structure: a definition list where each term is the
  #  version number, the first line of the description is the date,
  #  and subsequent lines are the change items.
  # ───────────────────────────────────────────────────────────────────
  def convert_role_changelog(node)
    lines = []
    lines << '\\begin{changelog}'

    # Walk child blocks looking for a dlist
    node.blocks.each do |block|
      if block.node_name == 'dlist'
        block.items.each do |terms, desc|
          # Term = version number
          version = terms.map(&:text).join.strip

          # Description block: first line = date, rest = items
          desc_text = desc ? desc.text : ''
          desc_content = desc && desc.content? ? desc.content : ''

          # Parse date from the first line of description
          date = ''
          items_text = ''

          if desc_text && !desc_text.empty?
            # The desc text often contains the date on the first line
            # and items follow. In AsciiDoc dlist, desc is a paragraph.
            # Format: "date\n* item1\n* item2"
            parts = desc_text.split("\n", 2)
            date = parts[0].strip
            items_text = parts[1] || ''
          end

          # Convert bullet items to \item entries
          if items_text && !items_text.empty?
            # Strip leading "* " from each line and wrap in \item
            item_lines = items_text.strip.split("\n").map do |line|
              cleaned = line.gsub(/^\*\s+/, '')
              "\\item #{cleaned}" unless cleaned.strip.empty?
            end.compact
            items_latex = item_lines.join(' ')
          elsif desc_content && !desc_content.strip.empty?
            # Content may have already been converted with \item
            items_latex = desc_content.strip
          else
            items_latex = "\\item #{desc_text}"
          end

          lines << "\\changelogentry{#{version}}{#{date}}{#{items_latex}}"
        end
      elsif block.node_name == 'paragraph'
        # Standalone paragraph inside changelog — skip or emit as-is
        lines << block.content
      end
    end

    lines << '\\end{changelog}'
    lines.join("\n")
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.testcase] open block → \begin{testcase}{title}...\end{testcase}
  # ───────────────────────────────────────────────────────────────────
  def convert_role_testcase(node)
    tc_title = node.attr('title') || node.title || ''
    lines = []
    lines << "\\begin{testcase}{#{latex_escape(tc_title)}}"

    # Process child blocks — look for [.testfield] sub-blocks
    node.blocks.each do |block|
      if block.role == 'testfield'
        label = block.attr('label') || ''
        field_type = TESTFIELD_MAP[label]

        case field_type
        when :objective
          lines << "\\testobjective{#{block.content}}"

        when :prerequisites
          lines << '\\begin{testprerequisites}'
          lines << convert_teststeps(block)
          lines << '\\end{testprerequisites}'

        when :procedure
          lines << '\\begin{testprocedure}'
          lines << convert_teststeps(block)
          lines << '\\end{testprocedure}'

        when :expected
          lines << '\\begin{testexpected}'
          lines << convert_teststeps(block)
          lines << '\\end{testexpected}'

        when :result
          lines << "\\testresult{#{block.content}}"

        when :remarks
          lines << "\\testremarks{#{block.content}}"

        else
          # Unknown field — emit as plain content
          lines << block.content
        end
      else
        # Non-testfield content inside testcase (images, code, etc.)
        lines << block.content
      end
    end

    lines << '\\end{testcase}'
    lines.join("\n")
  end

  # ───────────────────────────────────────────────────────────────────
  #  Helper: convert numbered/bullet list items in a testfield to
  #  \teststep{...} entries
  # ───────────────────────────────────────────────────────────────────
  def convert_teststeps(block)
    steps = []
    # Walk child blocks for list items
    if block.blocks
      block.blocks.each do |child|
        case child.node_name
        when 'olist', 'ulist'
          child.items.each do |item|
            steps << "\\teststep{#{item.text}}"
          end
        when 'paragraph'
          steps << "\\teststep{#{child.content}}"
        else
          steps << child.content
        end
      end
    end
    # If no child blocks, treat the text content as a single step
    if steps.empty? && block.content && !block.content.strip.empty?
      steps << "\\teststep{#{block.content.strip}}"
    end
    steps.join("\n")
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.objectives] open block → \begin{objectives}...\end{objectives}
  # ───────────────────────────────────────────────────────────────────
  def convert_role_objectives(node)
    lines = []
    lines << '\\begin{objectives}'

    node.blocks.each do |block|
      if block.role == 'general-objective'
        lines << "\\generalobjective{#{block.content}}"
      elsif block.role == 'prerequisites'
        lines << '\\prerequisites'
        # Prerequisites items — render as itemize
        if block.blocks
          block.blocks.each do |child|
            if child.node_name == 'ulist'
              items = child.items.map { |item| "\\item #{item.text}" }
              lines << "\\begin{itemize}"
              lines += items
              lines << '\\end{itemize}'
            else
              lines << child.content
            end
          end
        end
      elsif block.role == 'objective'
        lines << "\\objective{#{block.content}}"
      elsif block.role == 'stepbystep'
        lines << '\\stepbystep'
      else
        lines << block.content
      end
    end

    lines << '\\end{objectives}'
    lines.join("\n")
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.testsummary] on a table — already handled in convert_table
  # ───────────────────────────────────────────────────────────────────
  def convert_role_testsummary(node)
    convert_testsummary(node)
  end

  # ===================================================================
  #  ROLE-BASED INLINE (SPAN) CONVERTERS
  # ===================================================================

  # ───────────────────────────────────────────────────────────────────
  #  [.badge]#text# → \badge{text}
  # ───────────────────────────────────────────────────────────────────
  def convert_role_badge(node)
    "\\badge{#{node.text}}"
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.menu]#A ▸ B# → \menu{A, B}
  # ───────────────────────────────────────────────────────────────────
  def convert_role_menu(node)
    text = node.text || node.content || ''
    # Split on ▸ (U+25B8) or ▻ (U+25BB) or >>
    parts = text.split(/[▸▻]|>>/).map(&:strip).reject(&:empty?)
    "\\menu{#{parts.join(', ')}}"
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.note]#text# → \note{text}
  # ───────────────────────────────────────────────────────────────────
  def convert_role_note(node)
    "\\note{#{node.text}}"
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.param]#text# → \param{text}
  # ───────────────────────────────────────────────────────────────────
  def convert_role_param(node)
    "\\param{#{node.text}}"
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.badge-pass]#Pass# → \testresultbadge{Pass}
  # ───────────────────────────────────────────────────────────────────
  def convert_role_badge_pass(node)
    "\\testresultbadge{#{node.text || 'Pass'}}"
  end

  def convert_role_badge_fail(node)
    "\\testresultbadge{#{node.text || 'Fail'}}"
  end

  def convert_role_badge_blocked(node)
    "\\testresultbadge{#{node.text || 'Blocked'}}"
  end

  def convert_role_badge_untested(node)
    "\\testresultbadge{#{node.text || 'Untested'}}"
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.hutable] / [.longhutable] — delegate to table converter
  # ───────────────────────────────────────────────────────────────────
  def convert_role_hutable(node)
    convert_table(node)
  end

  def convert_role_longhutable(node)
    convert_table(node)
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.general-objective] — handled inside objectives
  # ───────────────────────────────────────────────────────────────────
  def convert_role_general_objective(node)
    "\\generalobjective{#{node.content}}"
  end

  # ───────────────────────────────────────────────────────────────────
  #  [.testfield] — handled inside testcase
  # ───────────────────────────────────────────────────────────────────
  def convert_role_testfield(node)
    # Standalone testfield (rare) — just emit content
    node.content
  end
end
