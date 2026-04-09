--- adapters/init.lua
--- OS detection and adapter selection.

local util = require("nv-port.util")

local M = {}

--- Return the adapter for the current OS.
---@return table adapter
function M.get()
  local os = util.detect_os()
  if os == "macos" then
    return require("nv-port.adapters.macos")
  elseif os == "windows" then
    return require("nv-port.adapters.windows")
  else
    return require("nv-port.adapters.linux")
  end
end

return M
