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

-- Note: pandoc must invoke this filter with a full path (e.g.,
-- --lua-filter=templates/guide/guide-pandoc.lua, not just guide-pandoc.lua).
-- A bare filename causes debug.getinfo to return nil for the path.
-- Load shared filter factory
local C = dofile(debug.getinfo(1, 'S').source:match('@(.*/)')
    .. '../_base/pandoc-common.lua')

-- Guide-specific configuration
local config = {
  class_name = 'guide',
  labels = {
    en = {
      warning = "Important", tip = "Tip", infobox = "Info",
      genobj = "General Objective:", obj = "Objective:",
      prereq = "Prerequisites:", stepbystep = "Step by step:",
      changelog = "Changelog",
      toc = "Contents",
    },
    pt = {
      warning = "Importante", tip = "Dica", infobox = "Informação",
      genobj = "Objetivo Geral:", obj = "Objetivo:",
      prereq = "Pré-requisitos:", stepbystep = "Passo a passo:",
      changelog = "Histórico de versões",
      toc = "Sumário",
    },
  },
  strip_commands = {
    setguidetitle = true, setheadertitle = true, setcovertext = true,
    setheaderlogo = true, setcoverlogo = true, setdocversion = true,
    setdocdate = true, makecover = true, maketoc = true, startbody = true,
  },
  command_map = {
    title = 'setguidetitle',
    version = 'setdocversion',
    date = 'setdocdate',
  },
  cover_text = nil,  -- read from preamble.commands.setcovertext
  cover_logo = nil,  -- read from preamble.commands.setcoverlogo
  warn_setheaderlogo = true,
  extra_env_handlers = {},
}

-- Create filter
local F = C.make_filter(config)

-- Wire globals (L16: must assign, NOT return)
Pandoc = F.Pandoc
RawBlock = F.RawBlock
RawInline = F.RawInline
Header = F.Header
CodeBlock = F.CodeBlock
