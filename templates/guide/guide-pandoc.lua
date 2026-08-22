--- guide-pandoc.lua
--- Pandoc Lua filter for the Huawei guide.cls template.
--- Translates custom commands and environments to DOCX, Markdown, and HTML5.
---
--- Usage:
---   pandoc --lua-filter=guide-pandoc.lua -f latex+raw_tex -t docx  input.tex
---   pandoc --lua-filter=guide-pandoc.lua -f latex+raw_tex -t markdown input.tex
---   pandoc --lua-filter=guide-pandoc.lua -f latex+raw_tex -t html5  input.tex
---
--- Requires pandoc >= 3.0 (Table Cell/Row API).
--- Most features work with pandoc >= 2.9; hutable requires >= 3.0.
--- Do NOT add a return table at the end — global functions work.

-- Require pandoc >= 3.0
if PANDOC_VERSION then
  PANDOC_VERSION:must_be_at_least('3.0')
end
-- Ensure C locale for consistent pattern matching
os.setlocale('C')

-- Language labels (English / Portuguese)
local labels = {
  en = {
    warning = "Important", tip = "Tip", infobox = "Info",
    genobj = "General Objective:", obj = "Objective:",
    prereq = "Prerequisites:", stepbystep = "Step by step:",
    changelog = "Changelog",
    toc = "Table of Contents",
  },
  pt = {
    warning = "Importante", tip = "Dica", infobox = "Informação",
    genobj = "Objetivo Geral:", obj = "Objetivo:",
    prereq = "Pré-requisitos:", stepbystep = "Passo a passo:",
    changelog = "Histórico de versões",
    toc = "Sumário",
  },
}

-- Active language: "en" or "pt" (set by documentclass option detection)
local lang = "en"
local function L(key) return labels[lang][key] or key end

local function log_warn(msg)
  io.stderr:write("WARNING: " .. msg .. "\n")
end

-- =====================================================================
--  Utility helpers
-- =====================================================================

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

-- Detect language at filter load time (before AST walk).
-- RawBlock/RawInline handlers run during the walk, before Pandoc(),
-- so lang must be set before any handler that calls L().
do
  local _sp = nil
  if PANDOC_STATE and PANDOC_STATE.input_files then
    for _, f in ipairs(PANDOC_STATE.input_files) do _sp = f; break end
  end
  if _sp then
    local _src = read_file(_sp)
    if _src and _src:find("\\documentclass%s*%[.*portuguese.*%]%s*{guide}") then
      lang = "pt"
    end
  end
end

--- Parse balanced-brace argument from position after opening brace.
--- Returns (content, end_pos) or (nil, nil).
--- Handles nested braces: \foo{a{b}c} → "a{b}c"
local function parse_brace_arg(text, start)
  local depth = 1
  local i = start
  while i <= #text do
    local c = text:sub(i, i)
    if c == "{" then depth = depth + 1
    elseif c == "}" then
      depth = depth - 1
      if depth == 0 then return text:sub(start, i - 1), i end
    elseif c == "\\" and i < #text then
      i = i + 1 -- skip next char after backslash (escaped char or command)
    end
    i = i + 1
  end
  return nil, nil
end

local function find_cmd_arg(text, cmd)
  local start = text:find("\\" .. cmd .. "%s*{")
  if not start then return nil end
  local brace_pos = text:find("{", start)
  if not brace_pos then return nil end
  return parse_brace_arg(text, brace_pos + 1)
end

local function find_all_cmd_args(text, cmd)
  local results = {}
  local pos = 1
  while true do
    local start = text:find("\\" .. cmd .. "%s*{", pos)
    if not start then break end
    local brace_pos = text:find("{", start)
    if not brace_pos then break end
    local content, end_pos = parse_brace_arg(text, brace_pos + 1)
    if content then
      table.insert(results, content)
      pos = (end_pos or brace_pos) + 1
    else break end
  end
  return results
end

--- Split a table row string on & with brace-depth tracking.
--- Pads or trims to exactly num_cols cells. Returns a table of cell strings.
local function split_row(row_str, num_cols)
  local cells = {}
  local cell_start = 1
  local depth = 0
  for i = 1, #row_str do
    local c = row_str:sub(i, i)
    if c == "{" then depth = depth + 1
    elseif c == "}" then depth = depth - 1
    elseif c == "&" and depth == 0 then
      table.insert(cells, trim(row_str:sub(cell_start, i - 1)))
      cell_start = i + 1
    end
  end
  table.insert(cells, trim(row_str:sub(cell_start)))
  while #cells < num_cols do table.insert(cells, "") end
  while #cells > num_cols do table.remove(cells) end
  return cells
end

-- Commands to strip from the document body (preamble setters + structural)
local strip_commands = {
  setguidetitle = true, setheadertitle = true, setcovertext = true,
  setheaderlogo = true, setcoverlogo = true, setdocversion = true,
  setdocdate = true, makecover = true, maketoc = true, startbody = true,
}

--- Check if a raw LaTeX string is a strip command.
local function is_strip_cmd(text)
  for cmd, _ in pairs(strip_commands) do
    if text:match("^%s*\\" .. cmd .. "%s*%[") or
       text:match("^%s*\\" .. cmd .. "%s*{") or
       text:match("^%s*\\" .. cmd .. "%s*$") then
      return true
    end
  end
  return false
end

-- Forward declaration: set after RawInline/RawBlock are defined.
local inner_filter = nil

--- Pre-process LaTeX text to replace custom commands with standard LaTeX
--- that pandoc.read understands.  Unknown commands like \inlinecode are
--- consumed by pandoc.read rather than preserved as RawInline, so we must
--- translate them before parsing.
local function preprocess_latex(text)
  text = text:gsub("\\inlinecode%s*(%b{})", function(arg)
    return "\\texttt{" .. arg:sub(2, -2) .. "}"
  end)
  text = text:gsub("\\param%s*(%b{})", function(arg)
    return "\\textit{" .. arg:sub(2, -2) .. "}"
  end)
  text = text:gsub("\\badge%s*(%b{})", function(arg)
    return "\\textbf{[" .. arg:sub(2, -2) .. "]}"
  end)
  text = text:gsub("\\menu%s*(%b{})", function(arg)
    local parts = {}
    for item in arg:sub(2, -2):gmatch("([^,]+)") do
      item = trim(item)
      if item ~= "" then table.insert(parts, "\\textbf{" .. item .. "}") end
    end
    return table.concat(parts, " \\textbf{→} ")
  end)
  text = text:gsub("\\weblink%s*(%b{})%s*(%b{})", function(url_arg, text_arg)
    return "\\href{" .. url_arg:sub(2, -2) .. "}{" .. text_arg:sub(2, -2) .. "}"
  end)
  text = text:gsub("\\note%s*(%b{})", function(arg)
    return "\\textit{Note: " .. arg:sub(2, -2) .. "}"
  end)
  return text
end

--- Parse inner LaTeX content into pandoc Blocks using pandoc.read.
--- Walks the result with inner_filter to process any raw LaTeX inside.
local function parse_latex_blocks(content)
  content = preprocess_latex(content)
  local ok, result = pcall(pandoc.read, content, "latex")
  if ok and result then
    if inner_filter then
      local walked = pandoc.Blocks({})
      for _, blk in ipairs(result.blocks) do
        walked:insert(pandoc.walk_block(blk, inner_filter))
      end
      return walked
    end
    return result.blocks
  end
  return {pandoc.Para(pandoc.Str(content))}
end

--- Parse inner LaTeX content into pandoc Inlines.
local function parse_latex_inlines(content)
  content = preprocess_latex(content)
  local ok, result = pcall(pandoc.read, content, "latex")
  if ok and result then
    local inlines = pandoc.Inlines({})
    for _, block in ipairs(result.blocks) do
      local blk = inner_filter and pandoc.walk_block(block, inner_filter) or block
      if blk.t == "Para" then inlines:extend(blk.content)
      elseif blk.t == "Plain" then inlines:extend(blk.content) end
    end
    return inlines
  end
  return pandoc.Inlines({pandoc.Str(content)})
end

--- ARIA role and label mapping for callout types (accessibility).
local aria_roles = {
  warning = { role = "alert",  ["aria-label"] = "Warning" },
  tip     = { role = "note",   ["aria-label"] = "Tip" },
  infobox = { role = "note",   ["aria-label"] = "Info" },
}

--- Create a format-appropriate callout box.
local function make_callout(cls, label, content)
  local label_para = pandoc.Para({pandoc.Strong({pandoc.Str(label)}), pandoc.Str(" ")})

  if FORMAT:match("docx") then
    -- Callout colors: border, background, label color
    local callout_colors = {
      warning = {border = "F57C00", bg = "FFF8E1", label_color = "C7000B"},
      tip     = {border = "2E7D32", bg = "E8F5E9", label_color = "2E7D32"},
      infobox = {border = "1565C0", bg = "E3F2FD", label_color = "1565C0"},
    }
    local c = callout_colors[cls] or callout_colors.infobox
    local esc_label = label:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

    -- Single-cell table: thick left border, thin other borders, cell shading
    local open_xml = string.format(
      '<w:tbl><w:tblPr><w:tblBorders>' ..
      '<w:top w:val="single" w:sz="4" w:space="0" w:color="%s"/>' ..
      '<w:left w:val="single" w:sz="24" w:space="0" w:color="%s"/>' ..
      '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="%s"/>' ..
      '<w:right w:val="single" w:sz="4" w:space="0" w:color="%s"/>' ..
      '</w:tblBorders>' ..
      '<w:tblCellMar><w:top w:w="100" w:type="dxa"/><w:left w:w="200" w:type="dxa"/>' ..
      '<w:bottom w:w="100" w:type="dxa"/><w:right w:w="200" w:type="dxa"/></w:tblCellMar>' ..
      '</w:tblPr><w:tr><w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="%s"/></w:tcPr>' ..
      '<w:p><w:r><w:rPr><w:rFonts w:ascii="HarmonyOS Sans" w:hAnsi="HarmonyOS Sans"/>' ..
      '<w:b/><w:color w:val="%s"/><w:sz w:val="21"/><w:szCs w:val="21"/></w:rPr>' ..
      '<w:t>%s</w:t></w:r></w:p>',
      c.border, c.border, c.border, c.border, c.bg, c.label_color, esc_label)

    local blocks = pandoc.Blocks({
      pandoc.RawBlock("openxml", open_xml),
    })
    blocks:extend(content)
    blocks:insert(pandoc.RawBlock("openxml", '</w:tc></w:tr></w:tbl>'))
    -- Add spacing paragraph after callout table for visual separation
    blocks:insert(pandoc.RawBlock("openxml", '<w:p><w:pPr><w:spacing w:before="120" w:after="0"/></w:pPr></w:p>'))
    return blocks

  elseif FORMAT:match("markdown") then
    -- Avoid double colon if label already ends with ":"
    local label_text = label
    if not label_text:match(":$") then label_text = label_text .. ":" end
    local label_inline = pandoc.Inlines({
      pandoc.Strong({pandoc.Str(label_text)}), pandoc.Space(),
    })
    local quote_blocks = pandoc.Blocks({})
    if #content > 0 and content[1].t == "Para" then
      local first_para = pandoc.Para(label_inline:clone())
      first_para.content:extend(content[1].content)
      quote_blocks:insert(first_para)
      for i = 2, #content do quote_blocks:insert(content[i]) end
    else
      quote_blocks:insert(pandoc.Para(label_inline))
      quote_blocks:extend(content)
    end
    return pandoc.BlockQuote(quote_blocks)

  else
    -- HTML5 (and fallback): Div with callout class and ARIA attributes
    local div_content = pandoc.Blocks({label_para})
    div_content:extend(content)
    local attrs = pandoc.Attr("", {"callout", cls}, {})
    local aria = aria_roles[cls]
    if aria then
      attrs.attributes.role = aria.role
      attrs.attributes["aria-label"] = aria["aria-label"]
    end
    return pandoc.Div(div_content, attrs)
  end
end

--- Parse \image, \imagecap, or \imageplaceholder commands from text.
--- Returns (caption_inlines, path, is_placeholder, desc_raw) or nil.
--- is_placeholder is true only for \imageplaceholder; the RawInline handler
--- uses desc_raw for the placeholder text instead of creating an Image.
--- For \image without caption: empty alt text (decorative image per WCAG).
local function parse_image(text)
  -- Try \image[opts]{file}
  local file = text:match("\\image%s*%b[]%s*(%b{})") or text:match("\\image%s*(%b{})")
  if file then
    local path = file:sub(2, -2)
    return pandoc.Inlines({}), path, false, nil
  end

  -- Try \imagecap[opts]{file}{caption}
  local start = text:find("\\imagecap%s*")
  if start then
    local pos = start + #("\\imagecap")
    local after_opts = pos
    local opt_bracket = text:find("%[", pos)
    if opt_bracket and opt_bracket < (text:find("{", pos) or math.huge) then
      local depth, i = 0, opt_bracket
      while i <= #text do
        local c = text:sub(i, i)
        if c == "[" then depth = depth + 1
        elseif c == "]" then depth = depth - 1; if depth == 0 then after_opts = i + 1; break end end
        i = i + 1
      end
    end
    local brace1 = text:find("{", after_opts)
    if brace1 then
      local file_path, end1 = parse_brace_arg(text, brace1 + 1)
      if file_path then
        local brace2 = text:find("{", end1 + 1)
        if brace2 then
          local caption_text = parse_brace_arg(text, brace2 + 1)
          if caption_text then
            return parse_latex_inlines(caption_text), file_path, false, nil
          end
        end
      end
    end
  end

  -- Try \imageplaceholder{path}{desc}
  local ph_start = text:find("\\imageplaceholder%s*{")
  if ph_start then
    local brace1 = text:find("{", ph_start)
    if brace1 then
      local path, end1 = parse_brace_arg(text, brace1 + 1)
      if path then
        local brace2 = text:find("{", end1 + 1)
        if brace2 then
          local desc = parse_brace_arg(text, brace2 + 1)
          if desc then
            return parse_latex_inlines(desc), path, true, desc
          end
        end
      end
    end
  end

  return nil
end

--- Parse \codefile[lang]{file} or \codefile{file}. Returns (content, lang_hint) or nil.
local function parse_codefile(text)
  local lang_hint, file_arg = text:match("\\codefile%s*%[([^%]]*)%]%s*(%b{})")
  if not lang_hint then file_arg = text:match("\\codefile%s*(%b{})") end
  if not file_arg then return nil end
  local file_path = file_arg:sub(2, -2)
  local content = read_file(file_path)
  if content then return content, lang_hint end
  return nil, nil, file_path -- third return = path for error message
end

-- =====================================================================
--  Document-level: Pandoc handler
-- =====================================================================

function Pandoc(doc)
  -- Detect language from source file
  local source_path = nil
  if PANDOC_STATE and PANDOC_STATE.input_files then
    for _, f in ipairs(PANDOC_STATE.input_files) do source_path = f; break end
  end

  if source_path then
    local src = read_file(source_path)
    if src then
      -- Set doc.meta.lang so the HTML template's $lang$ variable works
      doc.meta.lang = (lang == "pt") and "pt" or "en"
      local title = find_cmd_arg(src, "setguidetitle")
      if title then
        local current_title = doc.meta.title
        if not current_title or (type(current_title) == "table" and #current_title == 0) then
          doc.meta.title = pandoc.Inlines({pandoc.Str(title)})
        end
      end
      local version = find_cmd_arg(src, "setdocversion")
      if version then doc.meta["doc-version"] = version end
      local date = find_cmd_arg(src, "setdocdate")
      if date then doc.meta.date = date:gsub("\\today", os.date("%Y-%m-%d")) end

      -- For DOCX: add cover page content (cover text + version/date + page break)
      -- The title is rendered by pandoc via doc.meta.title (Title style).
      if FORMAT:match("docx") then
        local ct = find_cmd_arg(src, "setcovertext") or "Huawei Technologies CO., LTD"
        local meta_parts = {}
        if version and version ~= "" then table.insert(meta_parts, "v" .. version) end
        if date then
          local ds = date:gsub("\\today", os.date("%Y-%m-%d"))
          ds = ds .. " " .. os.date("%H:%M")
          if ds ~= "" then table.insert(meta_parts, ds) end
        end
        local mt = table.concat(meta_parts, " — ")
        local cb = pandoc.Blocks({})
        -- Cover logo (centered, 3.6cm wide — matches PDF)
        cb:insert(pandoc.Div(
            {pandoc.Para({pandoc.Image(pandoc.Inlines({}), "huawei-logo-cover.png", "", pandoc.Attr("", {}, {width = "3.6cm"}))})},
            pandoc.Attr("", {}, {["custom-style"] = "CoverLogo"})))
        cb:insert(pandoc.Div(
            {pandoc.Para({pandoc.Str(ct)})},
            pandoc.Attr("", {}, {["custom-style"] = "CoverText"})))
        if mt ~= "" then
          cb:insert(pandoc.Div(
              {pandoc.Para({pandoc.Str(mt)})},
              pandoc.Attr("", {}, {["custom-style"] = "CoverMeta"})))
        end
        cb:insert(pandoc.RawBlock("openxml", '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'))
        for i = #cb, 1, -1 do doc.blocks:insert(1, cb[i]) end
        -- Word TOC field (right-aligned 22pt heading + TOC + page break)
        local toc_title = L("toc")
        local toc_blocks = pandoc.Blocks({})
        toc_blocks:insert(pandoc.Div(
            {pandoc.Para({pandoc.Str(toc_title)})},
            pandoc.Attr("", {}, {["custom-style"] = "TOCTitle"})))
        -- Native Word TOC field wrapped in w:sdt (structured document tag)
        -- w:dirty="true" tells Word to update on open (one-time security warning)
        -- Word generates all entries: page numbers, hyperlinks, dot leaders, indentation
        -- TOC1/TOC2/TOC3 styles in reference DOCX control appearance
        toc_blocks:insert(pandoc.RawBlock("openxml",
          '<w:sdt><w:sdtPr><w:docPartObj>' ..
          '<w:docPartGallery w:val="Table of Contents"/>' ..
          '<w:docPartUnique/></w:docPartObj></w:sdtPr>' ..
          '<w:sdtContent>' ..
          '<w:p><w:r>' ..
          '<w:fldChar w:fldCharType="begin" w:dirty="true"/>' ..
          '<w:instrText xml:space="preserve"> TOC \\o "1-3" \\h \\z \\u </w:instrText>' ..
          '<w:fldChar w:fldCharType="separate"/>' ..
          '<w:fldChar w:fldCharType="end"/>' ..
          '</w:r></w:p>' ..
          '</w:sdtContent></w:sdt>'))
        toc_blocks:insert(pandoc.RawBlock("openxml", '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'))
        for i = #toc_blocks, 1, -1 do doc.blocks:insert(#cb + 1, toc_blocks[i]) end
        doc.meta.date = nil
      end
    end
  end

  -- Strip structural/preamble commands from the body
  local function strip_from_inlines(inlines)
    local new_inlines = pandoc.Inlines({})
    for i = 1, #inlines do
      local inl = inlines[i]
      if inl.t == "RawInline" and inl.format == "latex" and is_strip_cmd(inl.text) then
        -- skip
      else
        new_inlines:insert(inl)
      end
    end
    return new_inlines
  end

  local function strip_from_blocks(blocks)
    local new_blocks = pandoc.Blocks({})
    for _, blk in ipairs(blocks) do
      if blk.t == "RawBlock" and blk.format == "latex" and is_strip_cmd(blk.text) then
        -- skip
      else
        if blk.t == "Para" or blk.t == "Plain" then
          blk.content = strip_from_inlines(blk.content)
        elseif blk.t == "Div" or blk.t == "BlockQuote" then
          blk.content = strip_from_blocks(blk.content)
        elseif blk.t == "BulletList" then
          for _, item in ipairs(blk.content) do
            if item.t == "Para" or item.t == "Plain" then
              item.content = strip_from_inlines(item.content)
            end
          end
        elseif blk.t == "OrderedList" then
          -- blk.content[1] is the list items, blk.content[2] is the list attrs
          for _, item in ipairs(blk.content[1]) do
            if item.t == "Para" or item.t == "Plain" then
              item.content = strip_from_inlines(item.content)
            end
          end
        end
        new_blocks:insert(blk)
      end
    end
    return new_blocks
  end

  doc.blocks = strip_from_blocks(doc.blocks)

  -- Promote \codefile Code inlines to CodeBlocks.
  -- When \codefile appears inline in a Para (no blank line before it),
  -- pandoc treats it as RawInline. The RawInline handler returns
  -- pandoc.Code with a "codefile" marker class. Multi-line code
  -- content should be a fenced code block, not inline code.
  local function promote_codefile_inlines(blocks)
    local new_blocks = pandoc.Blocks({})
    for _, blk in ipairs(blocks) do
      if blk.t ~= "Para" then
        new_blocks:insert(blk)
      else
        local codefile_positions = {}
        for i, inl in ipairs(blk.content) do
          if inl.t == "Code" then
            local has_cf = false
            for _, cls in ipairs(inl.classes) do if cls == "codefile" then has_cf = true; break end end
            if has_cf then
              local cf_classes = {}
              for _, cls in ipairs(inl.classes) do if cls ~= "codefile" then table.insert(cf_classes, cls) end end
              table.insert(codefile_positions, { idx = i, text = inl.text, classes = cf_classes })
            end
          end
        end
        if #codefile_positions == 0 then
          new_blocks:insert(blk)
        else
          local prev_end = 0
          for _, cf in ipairs(codefile_positions) do
            if cf.idx > prev_end + 1 then
              local before = pandoc.Inlines({})
              for i = prev_end + 1, cf.idx - 1 do before:insert(blk.content[i]) end
              new_blocks:insert(pandoc.Para(before))
            end
            new_blocks:insert(pandoc.CodeBlock(cf.text, pandoc.Attr("", cf.classes, {})))
            prev_end = cf.idx
          end
          local last_idx = codefile_positions[#codefile_positions].idx
          if last_idx < #blk.content then
            local after = pandoc.Inlines({})
            for i = last_idx + 1, #blk.content do after:insert(blk.content[i]) end
            new_blocks:insert(pandoc.Para(after))
          end
        end
      end
    end
    return new_blocks
  end

  doc.blocks = promote_codefile_inlines(doc.blocks)
  return doc
end

-- =====================================================================
--  RawBlock environment handlers
--  Each receives the full raw text, does its own \begin{env} matching,
--  and returns a pandoc element or nil.
-- =====================================================================

local function handle_code_env(text)
  local lang_hint, body = text:match("\\begin%s*{code}%s*%[([^%]]*)%]%s*(.-)%s*\\end%s*{code}")
  if not lang_hint then body = text:match("\\begin%s*{code}%s*(.-)%s*\\end%s*{code}") end
  if not body then return nil end
  -- Trim trailing whitespace from each line (fancyvrb artifact)
  local cleaned = body:gsub("\n%s+\n", "\n\n"):gsub("%s+$", "")
  local classes = (lang_hint and lang_hint ~= "") and {lang_hint} or {}
  return pandoc.CodeBlock(cleaned, pandoc.Attr("", classes, {}))
end

--- Factory: returns a handler for a callout environment (warning/tip/infobox).
local function handle_callout_env(cls, label_key)
  return function(text)
    local body = text:match("\\begin%s*{" .. cls .. "}%s*(.-)%s*\\end%s*{" .. cls .. "}")
    if not body then return nil end
    return make_callout(cls, L(label_key), parse_latex_blocks(body))
  end
end

local function handle_objectives_env(text)
  local body = text:match("\\begin%s*{objectives}%s*(.-)%s*\\end%s*{objectives}")
  if not body then return nil end
  local blocks = pandoc.Blocks({})

  local function add_labeled_para(label_text, content_text)
    local inlines = pandoc.Inlines({pandoc.Strong({pandoc.Str(label_text)}), pandoc.Space()})
    if content_text and content_text ~= "" then inlines:extend(parse_latex_inlines(content_text)) end
    blocks:insert(pandoc.Para(inlines))
  end

  local genobj = find_cmd_arg(body, "generalobjective")
  if genobj then add_labeled_para(L("genobj"), genobj) end
  for _, arg in ipairs(find_all_cmd_args(body, "objective")) do
    add_labeled_para(L("obj"), arg)
  end

  if body:find("\\prerequisites") then
    add_labeled_para(L("prereq"), nil)
    local after = body:match("\\prerequisites%s*(.*)")
    if after then for _, blk in ipairs(parse_latex_blocks(after)) do blocks:insert(blk) end end
  end
  if body:find("\\stepbystep") then
    add_labeled_para(L("stepbystep"), nil)
    local after = body:match("\\stepbystep%s*(.*)")
    if after then for _, blk in ipairs(parse_latex_blocks(after)) do blocks:insert(blk) end end
  end

  if #blocks == 0 then blocks = parse_latex_blocks(body) end
  if FORMAT:match("docx") then
    -- Add bottom rule via named style (matches PDF \hrulefill after objectives)
    blocks:insert(pandoc.Div(
        {pandoc.Para({pandoc.Str("\u{200B}")})},
        pandoc.Attr("", {}, {["custom-style"] = "ObjectivesRule"})))
    return pandoc.Div(blocks, pandoc.Attr("", {"objectives"}, {}))
  elseif FORMAT:match("html5") then
    return pandoc.Div(blocks, pandoc.Attr("", {"objectives"}, {}))
  else
    return pandoc.BlockQuote(blocks)
  end
end

local function handle_hutable_env(text)
  local body = text:match("\\begin%s*{hutable}%s*%b{}%s*(.-)%s*\\end%s*{hutable}")
  local spec_arg = text:match("\\begin%s*{hutable}%s*({[^}]*})")
  if not body or not spec_arg then return nil end

  local col_spec_str = spec_arg:sub(2, -2)
  local num_cols = 0
  for _ in col_spec_str:gmatch("[lcrp]") do num_cols = num_cols + 1 end
  if num_cols == 0 then num_cols = 1 end

  -- Clean: strip \rowcolor{...}, \tbody, \thd{...} → content
  local cleaned = body
  cleaned = cleaned:gsub("\\rowcolor%s*%b{}", "")
  cleaned = cleaned:gsub("\\tbody", "")
  cleaned = cleaned:gsub("\\thd%s*(%b{})", function(m) return m:sub(2, -2) end)

  -- Split into rows on \\
  local rows = {}
  for row_str in cleaned:gmatch("(.-)\\\\") do
    row_str = trim(row_str)
    if row_str ~= "" then table.insert(rows, split_row(row_str, num_cols)) end
  end
  -- Handle last row without trailing \\
  -- gmatch above captured every row ending with \\. If the body ends with \\,
  -- all rows are captured. Only when the final row lacks a trailing \\ do we
  -- extract the content after the LAST \\ (greedy .* finds the last \\).
  local trimmed_body = trim(cleaned)
  if trimmed_body ~= "" and not trimmed_body:find("\\\\%s*$") then
    local after_last_sep = trimmed_body:match(".*\\\\%s*(.-)%s*$")
    if after_last_sep and after_last_sep ~= "" then
      table.insert(rows, split_row(after_last_sep, num_cols))
    elseif #rows == 0 then
      table.insert(rows, split_row(trimmed_body, num_cols))
    end
  end

  if #rows == 0 then return pandoc.Para({pandoc.Str("[Empty table]")}) end
  local header_row = table.remove(rows, 1)

  -- Render a LaTeX cell to markdown-safe plain text
  local function cell_to_md(cell_text)
    cell_text = preprocess_latex(cell_text)
    local inlines = parse_latex_inlines(cell_text)
    local doc = pandoc.Pandoc({pandoc.Para(inlines)})
    return pandoc.write(doc, "markdown"):gsub("\n", " "):gsub("%s+$", "")
  end

  -- Build a markdown table string and parse it.
  -- This is version-safe across pandoc 2.x and 3.x.
  local md_lines = {}
  local hdr_cells = {}
  for _, ct in ipairs(header_row) do hdr_cells[#hdr_cells + 1] = cell_to_md(ct) end
  md_lines[#md_lines + 1] = "| " .. table.concat(hdr_cells, " | ") .. " |"
  local sep_cells = {}
  for _ = 1, num_cols do sep_cells[#sep_cells + 1] = "---" end
  md_lines[#md_lines + 1] = "| " .. table.concat(sep_cells, " | ") .. " |"
  for _, row in ipairs(rows) do
    local body_cells = {}
    for _, ct in ipairs(row) do body_cells[#body_cells + 1] = cell_to_md(ct) end
    md_lines[#md_lines + 1] = "| " .. table.concat(body_cells, " | ") .. " |"
  end

  local md_table = table.concat(md_lines, "\n") .. "\n"
  local parsed = pandoc.read(md_table, "markdown")
  if #parsed.blocks > 0 and parsed.blocks[1].t == "Table" then
    -- For markdown output, use RawBlock to preserve pipe table syntax.
    -- The markdown writer converts Table AST to simple tables (whitespace-
    -- aligned), which lose the pipe delimiters. RawBlock passes the pipe
    -- table through verbatim.
    if FORMAT:match("markdown") then return pandoc.RawBlock("markdown", md_table) end

    -- For DOCX: render as OpenXML table with Huawei styling
    if FORMAT:match("docx") then
      local function esc(t)
        return t:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
      end
      local parts = {}
      -- Table opening with red borders (all sides + inside)
      parts[#parts+1] = '<w:tbl><w:tblPr><w:tblBorders>' ..
        '<w:top w:val="single" w:sz="4" w:space="0" w:color="C7000B"/>' ..
        '<w:left w:val="single" w:sz="4" w:space="0" w:color="C7000B"/>' ..
        '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="C7000B"/>' ..
        '<w:right w:val="single" w:sz="4" w:space="0" w:color="C7000B"/>' ..
        '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="C7000B"/>' ..
        '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="C7000B"/>' ..
        '</w:tblBorders><w:tblCellMar>' ..
        '<w:left w:w="100" w:type="dxa"/><w:right w:w="100" w:type="dxa"/>' ..
        '</w:tblCellMar></w:tblPr>'
      -- Header row: red background, white bold text, 9pt (sz=18), centered
      parts[#parts+1] = '<w:tr><w:trPr><w:tblHeader/></w:trPr>'
      for _, ct in ipairs(header_row) do
        parts[#parts+1] = '<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="C7000B"/></w:tcPr>' ..
          '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>' ..
          '<w:r><w:rPr><w:rFonts w:ascii="HarmonyOS Sans" w:hAnsi="HarmonyOS Sans"/>' ..
          '<w:b/><w:color w:val="FFFFFF"/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>' ..
          '<w:t>' .. esc(cell_to_md(ct)) .. '</w:t></w:r></w:p></w:tc>'
      end
      parts[#parts+1] = '</w:tr>'
      -- Body rows: alternating white/F6F8FA, 9pt (sz=18), centered
      for i, row in ipairs(rows) do
        local bg = (i % 2 == 0) and "F6F8FA" or "FFFFFF"
        parts[#parts+1] = '<w:tr>'
        for _, ct in ipairs(row) do
          parts[#parts+1] = '<w:tc><w:tcPr><w:shd w:val="clear" w:color="auto" w:fill="' .. bg .. '"/></w:tcPr>' ..
            '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>' ..
            '<w:r><w:rPr><w:rFonts w:ascii="HarmonyOS Sans" w:hAnsi="HarmonyOS Sans"/>' ..
            '<w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr>' ..
            '<w:t>' .. esc(cell_to_md(ct)) .. '</w:t></w:r></w:p></w:tc>'
        end
        parts[#parts+1] = '</w:tr>'
      end
      parts[#parts+1] = '</w:tbl>'
      return pandoc.RawBlock("openxml", table.concat(parts))
    end

    return parsed.blocks[1]
  end
  return pandoc.CodeBlock(md_table)
end

local function handle_changelog_env(text)
  local body = text:match("\\begin%s*{changelog}%s*(.-)%s*\\end%s*{changelog}")
  if not body then return nil end
  local blocks = pandoc.Blocks({})
  blocks:insert(pandoc.Header(1, pandoc.Inlines({pandoc.Str(L("changelog"))})))

  local pos = 1
  while true do
    local entry_start = body:find("\\changelogentry%s*{", pos)
    if not entry_start then break end
    local brace1 = body:find("{", entry_start)
    if not brace1 then break end
    local version, end1 = parse_brace_arg(body, brace1 + 1)
    if not version then break end
    local brace2 = body:find("{", end1 + 1)
    if not brace2 then break end
    local date_str, end2 = parse_brace_arg(body, brace2 + 1)
    if not date_str then break end
    local brace3 = body:find("{", end2 + 1)
    if not brace3 then break end
    local items_content, end3 = parse_brace_arg(body, brace3 + 1)
    if not items_content then break end
    blocks:insert(pandoc.Para({
      pandoc.Strong({pandoc.Str(version)}), pandoc.Str("  "), pandoc.Emph({pandoc.Str(date_str)}),
    }))
    for _, blk in ipairs(parse_latex_blocks(items_content)) do blocks:insert(blk) end
    pos = (end3 or brace3) + 1
  end
  return blocks
end

-- Dispatch table: environment name → handler function.
local block_env_handlers = {
  code       = handle_code_env,
  warning    = handle_callout_env("warning", "warning"),
  tip        = handle_callout_env("tip", "tip"),
  infobox    = handle_callout_env("infobox", "infobox"),
  objectives = handle_objectives_env,
  hutable    = handle_hutable_env,
  changelog  = handle_changelog_env,
}

-- =====================================================================
--  Header handler — page break before H1 in DOCX (matches PDF \clearpage)
-- =====================================================================

local h1_count = 0
function Header(el)
  if FORMAT:match("docx") and el.level == 1 then
    h1_count = h1_count + 1
    if h1_count > 1 then
      return pandoc.Blocks({
        pandoc.RawBlock("openxml", '<w:p><w:r><w:br w:type="page"/></w:r></w:p>'),
        el
      })
    end
  end
end

-- Strip syntax highlighting classes for DOCX (PDF uses monochrome code)
function CodeBlock(el)
  if FORMAT:match("docx") and #el.classes > 0 then
    el.classes = {}
    return el
  end
end

-- =====================================================================
--  RawBlock handler
-- =====================================================================

function RawBlock(raw)
  if raw.format ~= "latex" then return nil end
  local text = raw.text

  -- Try environment handlers via dispatch table
  for env, handler in pairs(block_env_handlers) do
    if text:find("\\begin%s*{" .. env .. "}") then
      local result = handler(text)
      if result then return result end
    end
  end

  -- Command handlers (sequential — different pattern structures)

  -- \objective{...}  →  callout with "Objective:" label
  do
    local arg = text:match("\\objective%s*(%b{})")
    if arg then return make_callout("infobox", L("obj"), parse_latex_blocks(arg:sub(2, -2))) end
  end

  -- \stepbystep  →  bold paragraph (section marker)
  if text:match("^%s*\\stepbystep%s*$") then
    return pandoc.Para({pandoc.Strong({pandoc.Str(L("stepbystep"))})})
  end

  -- \image, \imagecap  →  Image (block-level)
  -- \imageplaceholder  →  placeholder para in all formats (the image does
  -- not exist; emitting a real Image would produce broken links in output)
  do
    local caption, path, is_placeholder, desc = parse_image(text)
    if caption and path then
      if is_placeholder then
        return pandoc.Para({pandoc.Emph({pandoc.Str("[Image placeholder: " .. desc .. "]")})})
      end
      if FORMAT:match("docx") then
        local image_div = pandoc.Div(
            {pandoc.Para({pandoc.Image(caption, path)})},
            pandoc.Attr("", {}, {["custom-style"] = "ImageBlock"}))
        -- If caption has content (\imagecap), add a visible caption paragraph with Caption style
        if #caption > 0 then
          local caption_div = pandoc.Div(
            {pandoc.Para(caption)},
            pandoc.Attr("", {}, {["custom-style"] = "Caption"}))
          return {image_div, caption_div}
        end
        return image_div
      end
      return pandoc.Para({pandoc.Image(caption, path)})
    end
  end

  -- \note{...}  →  italic text (PDF: \textit); DOCX: plain italic, not callout
  do
    local arg = text:match("\\note%s*(%b{})")
    if arg then
      if FORMAT:match("docx") then
        return pandoc.Para({pandoc.Emph(parse_latex_inlines(arg:sub(2, -2)))})
      else
        return make_callout("infobox", "Note", parse_latex_blocks(arg:sub(2, -2)))
      end
    end
  end

  -- \badge{...}  →  red pill badge (DOCX: custom-style character; HTML: badge class)
  do
    local arg = text:match("\\badge%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2)
      if FORMAT:match("docx") then
        return pandoc.Para({pandoc.Span(pandoc.Inlines({pandoc.Str(content)}), pandoc.Attr("", {}, {["custom-style"] = "badge"}))})
      elseif FORMAT:match("html5") then
        return pandoc.Div(pandoc.Blocks({pandoc.Para({pandoc.Str(content)})}), pandoc.Attr("", {"badge"}, {}))
      else
        return pandoc.Para({pandoc.Strong({pandoc.Str("[" .. content .. "]")})})
      end
    end
  end

  -- \codefile[lang]{file}  →  CodeBlock (block-level)
  do
    local content, lang_hint, err_path = parse_codefile(text)
    if content then
      local classes = (lang_hint and lang_hint ~= "") and {lang_hint} or {}
      return pandoc.CodeBlock(content, pandoc.Attr("", classes, {}))
    elseif err_path then
      log_warn("Code file not found: " .. err_path)
      return pandoc.Para({})
    end
  end

  return nil
end

-- =====================================================================
--  RawInline handler
-- =====================================================================

function RawInline(raw)
  if raw.format ~= "latex" then return nil end
  local text = raw.text

  -- \inlinecode{x}  →  Code("x")
  do
    local arg = text:match("\\inlinecode%s*(%b{})")
    if arg then return pandoc.Code(arg:sub(2, -2)) end
  end

  -- \menu{A, B, C}  →  **A** → **B** → **C**
  do
    local arg = text:match("\\menu%s*(%b{})")
    if arg then
      local inlines = pandoc.Inlines({})
      local first = true
      for item in arg:sub(2, -2):gmatch("([^,]+)") do
        item = trim(item)
        if item ~= "" then
          if not first then inlines:insert(pandoc.Str(" → ")) end
          inlines:insert(pandoc.Strong({pandoc.Str(item)}))
          first = false
        end
      end
      return inlines
    end
  end

  -- \badge{x}  →  format-specific span
  do
    local arg = text:match("\\badge%s*(%b{})")
    if arg then
      local content = arg:sub(2, -2)
      if FORMAT:match("docx") or FORMAT:match("html5") then
        return pandoc.Span(pandoc.Inlines({pandoc.Str(content)}), pandoc.Attr("", {"badge"}, {}))
      else
        return pandoc.Inlines({pandoc.Str("[" .. content .. "]")})
      end
    end
  end

  -- \note{x}  →  italic text with "Note: " prefix
  do
    local arg = text:match("\\note%s*(%b{})")
    if arg then
      local inlines = pandoc.Inlines({pandoc.Str("Note: ")})
      inlines:extend(parse_latex_inlines(arg:sub(2, -2)))
      return pandoc.Emph(inlines)
    end
  end

  -- \weblink{url}{text}  →  Link
  do
    local start = text:find("\\weblink%s*{")
    if start then
      local brace1 = text:find("{", start)
      if brace1 then
        local url, end1 = parse_brace_arg(text, brace1 + 1)
        if url then
          local brace2 = text:find("{", end1 + 1)
          if brace2 then
            local link_text = parse_brace_arg(text, brace2 + 1)
            if link_text then return pandoc.Link(parse_latex_inlines(link_text), url) end
          end
        end
      end
    end
  end

  -- \param{x}  →  italic text
  do
    local arg = text:match("\\param%s*(%b{})")
    if arg then return pandoc.Emph(parse_latex_inlines(arg:sub(2, -2))) end
  end

  -- \image, \imagecap  →  Image (inline)
  -- \imageplaceholder  →  Emph placeholder text (inline)
  do
    local caption, path, is_placeholder, desc = parse_image(text)
    if caption and path then
      if is_placeholder then
        return pandoc.Emph({pandoc.Str("[Image placeholder: " .. path .. " — " .. desc .. "]")})
      else
        return pandoc.Image(caption, path)
      end
    end
  end

  -- \codefile[lang]{file}  →  Code inline with "codefile" marker class
  -- (promote_codefile_inlines in the Pandoc function promotes
  -- multi-line codefile Code inlines to CodeBlocks)
  do
    local content, lang_hint, err_path = parse_codefile(text)
    if content then
      local classes = {"codefile"}
      if lang_hint and lang_hint ~= "" then table.insert(classes, lang_hint) end
      return pandoc.Code(content, pandoc.Attr("", classes, {}))
    elseif err_path then
      log_warn("Code file not found: " .. err_path)
      return pandoc.Inlines({})
    end
  end

  -- Strip preamble/structural commands that appear as inline raw
  if is_strip_cmd(text) then return pandoc.Inlines({}) end

  return nil
end

-- Set up inner filter for walking parsed LaTeX content
-- (must be after RawInline/RawBlock definitions)
inner_filter = { RawInline = RawInline, RawBlock = RawBlock }

-- Global functions Pandoc/RawBlock/RawInline are auto-discovered by pandoc.
