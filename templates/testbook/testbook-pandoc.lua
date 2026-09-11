--- testbook-pandoc.lua
--- Pandoc Lua filter for the Huawei testbook.cls template.
--- Translates custom commands and environments to DOCX, Markdown, and HTML5.
---
--- Usage:
---   pandoc --lua-filter=testbook-pandoc.lua -f latex+raw_tex -t docx  input.tex
---   pandoc --lua-filter=testbook-pandoc.lua -f latex+raw_tex -t markdown input.tex
---   pandoc --lua-filter=testbook-pandoc.lua -f latex+raw_tex -t html5  input.tex
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

-- Note: pandoc must invoke this filter with a full path (e.g.,
-- --lua-filter=templates/testbook/testbook-pandoc.lua, not just testbook-pandoc.lua).
-- A bare filename causes debug.getinfo to return nil for the path.
-- Load shared filter factory
local C = dofile(debug.getinfo(1, 'S').source:match('@(.*/)')
    .. '../_base/pandoc-common.lua')

-- Testbook-specific configuration
local config = {
  class_name = 'testbook',
  labels = {
    en = {
      warning = "Important", tip = "Tip", infobox = "Info",
      genobj = "General Objective:", obj = "Objective:",
      prereq = "Prerequisites:", stepbystep = "Step by step:",
      changelog = "Changelog",
      toc = "Contents",
      -- Test case field labels
      objective = "Objective",
      prerequisites = "Prerequisites",
      procedure = "Procedure",
      expectedresult = "Expected Result",
      remarks = "Remarks",
      testresult = "Test Result",
    },
    pt = {
      warning = "Importante", tip = "Dica", infobox = "Informação",
      genobj = "Objetivo Geral:", obj = "Objetivo:",
      prereq = "Pré-requisitos:", stepbystep = "Passo a passo:",
      changelog = "Histórico de versões",
      toc = "Sumário",
      -- Test case field labels
      objective = "Objetivo",
      prerequisites = "Pré-requisitos",
      procedure = "Procedimento",
      expectedresult = "Resultado Esperado",
      remarks = "Observações",
      testresult = "Resultado do Teste",
    },
  },
  strip_commands = {
    settestbooktitle = true, setheadertitle = true, setcovertext = true,
    setcoverlogo = true, setheaderlogo = true, setdocversion = true,
    setdocdate = true, setdocauthors = true, makecover = true, maketoc = true, startbody = true,
  },
  command_map = {
    title = 'settestbooktitle',
    version = 'setdocversion',
    date = 'setdocdate',
  },
  cover_text = nil,  -- read from preamble.commands.setcovertext
  cover_logo = nil,  -- read from preamble.commands.setcoverlogo
  warn_setheaderlogo = true,
  -- Test case environment handler
  extra_env_handlers = function(L, parse_latex_blocks, preamble)
    -- Handler for the testcase environment.
    -- Converts \begin{testcase}{Title}...\end{testcase} into a
    -- subsection heading + a definition-list style table with
    -- field labels (Objective, Prerequisites, etc.) as bold terms
    -- and their content as definitions.
    --
    -- In the LaTeX source, the testcase environment produces a
    -- subsection + a 2-column table (label | content). We replicate
    -- that as a subsection heading followed by a 2-column Pandoc
    -- Table with Huawei-red header styling.
    local function handle_testcase_env(text)
      -- Extract the mandatory argument (test case title)
      local title = text:match("\\begin%s*{testcase}%s*(%b{})")
      if not title then return nil end
      title = title:sub(2, -2)  -- strip braces

      -- Extract body between \begin{testcase}{...} and \end{testcase}
      local body = text:match("\\begin%s*{testcase}%s*%b{}%s*(.-)%s*\\end%s*{testcase}")
      if not body then return nil end

      local blocks = pandoc.Blocks({})
      -- Add subsection heading for the test case title
      blocks:insert(pandoc.Header(2, pandoc.Inlines({pandoc.Str(title)})))

      -- Parse test field commands from the body.
      -- Each \testfield{content} becomes a row: label | content.
      -- When noanswers option is true, skip testremarks and testresult.
      local field_order = {
        { cmd = "testobjective",   label_key = "objective" },
        { cmd = "testprerequisites", label_key = "prerequisites" },
        { cmd = "testprocedure",  label_key = "procedure" },
        { cmd = "testexpected",   label_key = "expectedresult" },
        { cmd = "testremarks",    label_key = "remarks",     answer = true },
        { cmd = "testresult",     label_key = "testresult",  answer = true },
      }

      local noanswers = preamble and preamble.options and preamble.options.noanswers
      local rows = {}
      for _, field in ipairs(field_order) do
        if noanswers and field.answer then
          -- Skip answer fields when noanswers is set
        else
          local content = body:match("\\" .. field.cmd .. "%s*(%b{})")
          if content then
            content = content:sub(2, -2)  -- strip braces
            local label = L(field.label_key)
            table.insert(rows, { label = label, content = content })
          end
        end
      end

      if #rows == 0 then return blocks end

      -- Build a markdown table and parse it (same approach as hutable handler).
      local function cell_to_md(cell_text)
        cell_text = cell_text:gsub("\\\\", "\n")  -- line breaks → newlines
        -- Strip remaining LaTeX commands that aren't meaningful in MD
        -- Apply \cmd{arg} → arg iteratively to handle nested commands
        local prev = nil
        while prev ~= cell_text do
          prev = cell_text
          cell_text = cell_text:gsub("\\[a-zA-Z]+%s*(%b{})", function(m) return m:sub(2, -2) end)
        end
        cell_text = cell_text:gsub("\\_", "_")  -- escaped underscores
        cell_text = cell_text:gsub("\\[a-zA-Z]+", "")
        return (cell_text:gsub("^%s+", ""):gsub("%s+$", ""))  -- trim
      end

      local md_lines = {}
      -- Header row
      md_lines[#md_lines + 1] = "| Field | Description |"
      md_lines[#md_lines + 1] = "| --- | --- |"
      -- Body rows
      for _, row in ipairs(rows) do
        local label_md = cell_to_md(row.label)
        local content_md = cell_to_md(row.content)
        -- Escape pipes in cell content
        label_md = label_md:gsub("|", "\\|")
        content_md = content_md:gsub("|", "\\|")
        md_lines[#md_lines + 1] = "| " .. label_md .. " | " .. content_md .. " |"
      end

      local md_table = table.concat(md_lines, "\n") .. "\n"
      local parsed = pandoc.read(md_table, "markdown")
      if #parsed.blocks > 0 then
        for _, blk in ipairs(parsed.blocks) do blocks:insert(blk) end
      end

      return blocks
    end

    return {
      testcase = handle_testcase_env,
    }
  end,
}

-- Create filter
local F = C.make_filter(config)

-- Wire globals (L16: must assign, NOT return)
Pandoc = F.Pandoc
RawBlock = F.RawBlock
RawInline = F.RawInline
Header = F.Header
CodeBlock = F.CodeBlock
