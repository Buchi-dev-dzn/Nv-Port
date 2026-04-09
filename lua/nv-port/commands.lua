--- commands.lua
--- Route :NvPort subcommands to their respective modules.

local M = {}

-- Subcommand → handler mapping
local subcommands = {
  export = function(args)
    -- args may be empty (default mode) or "instant" / "portable" / "full"
    local mode = (args and args ~= "") and args or nil
    require("nv-port.exporter").export(mode)
  end,

  import = function(args)
    -- args: "{path}" or "{path} --confirm"
    require("nv-port.importer").import(args)
  end,

  inspect = function(args)
    if not args or args == "" then
      require("nv-port.util").error("Usage: :NvPort inspect {path/to/archive.zip}")
      return
    end
    require("nv-port.inspector").inspect(args)
  end,

  doctor = function(_)
    require("nv-port.doctor").run()
  end,

  report = function(_)
    -- Alias: run doctor (report is doctor for now)
    require("nv-port.doctor").run()
  end,
}

-- Complete subcommand names for cmdline completion
local subcommand_names = vim.tbl_keys(subcommands)
table.sort(subcommand_names)

-- Export-mode completions (for "export" subcommand)
local export_modes = { "instant", "portable", "full" }

--- Dispatch a :NvPort command.
---@param raw string  full args string, e.g. "export portable" or "import /tmp/x.zip --confirm"
function M.dispatch(raw)
  if not raw or raw == "" then
    -- Default: show doctor
    require("nv-port.doctor").run()
    return
  end

  -- Split into subcommand + rest
  local sub, rest = raw:match("^(%S+)%s*(.*)")
  sub = sub and sub:lower() or ""
  rest = rest or ""

  local handler = subcommands[sub]
  if not handler then
    require("nv-port.util").error(
      "Unknown subcommand: '" .. sub .. "'. Available: " .. table.concat(subcommand_names, ", ")
    )
    return
  end

  handler(rest)
end

--- Tab-completion for :NvPort.
---@param arg_lead string
---@param cmd_line string
---@param cursor_pos integer
---@return string[]
function M.complete(arg_lead, cmd_line, _cursor_pos)
  -- Tokenise what the user has typed so far
  local tokens = {}
  for t in cmd_line:gmatch("%S+") do
    table.insert(tokens, t)
  end

  -- tokens[1] is "NvPort"; tokens[2] is the first argument
  if #tokens <= 1 or (#tokens == 2 and arg_lead ~= "") then
    -- Complete subcommand
    local matches = {}
    for _, name in ipairs(subcommand_names) do
      if name:sub(1, #arg_lead) == arg_lead then
        table.insert(matches, name)
      end
    end
    return matches
  end

  local sub = tokens[2] and tokens[2]:lower() or ""

  -- "export" → complete modes
  if sub == "export" and #tokens <= 3 then
    local matches = {}
    for _, m in ipairs(export_modes) do
      if m:sub(1, #arg_lead) == arg_lead then
        table.insert(matches, m)
      end
    end
    return matches
  end

  -- "import" / "inspect" → complete file paths
  if (sub == "import" or sub == "inspect") and #tokens <= 3 then
    return vim.fn.getcompletion(arg_lead, "file")
  end

  return {}
end

return M
