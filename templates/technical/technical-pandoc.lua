--- technical-pandoc.lua
--- Pandoc Lua filter for the Huawei technical.cls template.
--- Translates custom commands and environments to DOCX, Markdown, and HTML5.
---
--- Usage:
---   pandoc --lua-filter=technical-pandoc.lua -f latex+raw_tex -t docx  input.tex
---   pandoc --lua-filter=technical-pandoc.lua -f latex+raw_tex -t markdown input.tex
---   pandoc --lua-filter=technical-pandoc.lua -f latex+raw_tex -t html5  input.tex
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

-- Load shared filter factory
local C = dofile(debug.getinfo(1, 'S').source:match('@(.*/)')
    .. '../_base/pandoc-common.lua')

-- Technical-specific configuration
local config = {
  class_name = 'technical',
  labels = {
    en = {
      warning = "Important", tip = "Tip", infobox = "Info",
      genobj = "General Objective:", obj = "Objective:",
      prereq = "Prerequisites:", stepbystep = "Step by step:",
      changelog = "Changelog",
      toc = "Contents",
      -- Technical report section labels
      problem = "Problem Description and Impact",
      rootcauseanalysis = "Root Cause Analysis",
      rootcause = "Root Cause",
      triggercondition = "Trigger Condition",
      workaround = "Workaround and Impact",
      impact = "Impact",
      backupdata = "Back up data before the workaround",
      workaroundsteps = "Workaround",
      verification = "Verification after the workaround",
      rollback = "Rollback Operation",
      cleanup = "Cleanup Operation",
    },
    pt = {
      warning = "Importante", tip = "Dica", infobox = "Informação",
      genobj = "Objetivo Geral:", obj = "Objetivo:",
      prereq = "Pré-requisitos:", stepbystep = "Passo a passo:",
      changelog = "Histórico de versões",
      toc = "Sumário",
      -- Technical report section labels
      problem = "Descrição do Problema e Impacto",
      rootcauseanalysis = "Análise de Causa Raiz",
      rootcause = "Causa Raiz",
      triggercondition = "Condição de Disparo",
      workaround = "Solução Alternativa e Impacto",
      impact = "Impacto",
      backupdata = "Backup de dados antes da solução alternativa",
      workaroundsteps = "Solução Alternativa",
      verification = "Verificação após a solução alternativa",
      rollback = "Operação de Rollback",
      cleanup = "Operação de Limpeza",
    },
  },
  strip_commands = {
    setreporttitle = true, setreportversion = true, setreportdate = true,
    setreportscenario = true, setreporttype = true, setheadertitle = true,
    setheaderlogo = true,
    setdocversion = true, setdocdate = true,
    makecover = true, maketoc = true, startbody = true,
  },
  command_map = {
    title = 'setreporttitle',
    version = 'setreportversion',
    date = 'setreportdate',
  },
  cover_text = "Huawei Technologies CO., LTD",  -- hardcoded for technical
  cover_logo = "huawei-logo-cover.png",          -- hardcoded for technical
  warn_setheaderlogo = false,
  -- Section env handlers created via function to get correct closures
  extra_env_handlers = function(L, parse_latex_blocks)
    -- Factory: returns a handler for a technical section environment.
    -- level 1 = \section (problem, rootcauseanalysis, etc.)
    -- level 2 = \subsection (impact, backupdata, etc.)
    local function handle_section_env(env_name, label_key, level)
      return function(text)
        local body = text:match("\\begin%s*{" .. env_name .. "}%s*(.-)%s*\\end%s*{" .. env_name .. "}")
        if not body then return nil end
        local blocks = pandoc.Blocks({})
        blocks:insert(pandoc.Header(level, pandoc.Inlines({pandoc.Str(L(label_key))})))
        for _, blk in ipairs(parse_latex_blocks(body)) do blocks:insert(blk) end
        return blocks
      end
    end

    return {
      -- Technical report 6-section environments (level 1 = section)
      problem           = handle_section_env("problem", "problem", 1),
      rootcauseanalysis = handle_section_env("rootcauseanalysis", "rootcauseanalysis", 1),
      rootcause         = handle_section_env("rootcause", "rootcause", 1),
      triggercondition  = handle_section_env("triggercondition", "triggercondition", 1),
      workaround        = handle_section_env("workaround", "workaround", 1),
      -- Technical report subsection environments (level 2 = subsection)
      impact            = handle_section_env("impact", "impact", 2),
      backupdata        = handle_section_env("backupdata", "backupdata", 2),
      workaroundsteps   = handle_section_env("workaroundsteps", "workaroundsteps", 2),
      verification      = handle_section_env("verification", "verification", 2),
      rollback          = handle_section_env("rollback", "rollback", 2),
      cleanup           = handle_section_env("cleanup", "cleanup", 2),
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
