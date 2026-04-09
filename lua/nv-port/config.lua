--- config.lua
--- User configuration defaults and merging logic for nv-port.

local M = {}

---@class NvPortConfig
---@field output_dir string Default export output directory
---@field default_mode "instant"|"portable"|"full" Default export mode
---@field schema_version string Archive schema version

---@type NvPortConfig
M.defaults = {
  output_dir = vim.fn.expand("~/nvport-exports"),
  default_mode = "portable",
  schema_version = "1",
}

---@type NvPortConfig
M.current = {}

--- Merge user options with defaults.
---@param opts? NvPortConfig
function M.setup(opts)
  M.current = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

--- Get a config value by key.
---@param key string
---@return any
function M.get(key)
  return M.current[key]
end

return M
