-- luacheck config for Huawei Pandoc Lua filters
-- Run: luacheck templates/_base/pandoc-common.lua templates/*/*-pandoc.lua
std = "lua54"
globals = {
  "PANDOC_VERSION", "PANDOC_STATE", "FORMAT",
  "pandoc",
}
ignore = {
  "212", -- unused argument (pandoc API requires specific signatures)
  "213", -- unused variable (same reason)
  "311", -- value assigned to unused variable
  "631", -- line too long (Lua filter patterns are long)
}
max_line_length = 120
