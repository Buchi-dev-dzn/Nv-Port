local M = {}

---@class NvPortConfig
---@field option string Example option

---@type NvPortConfig
local defaults = {
  option = "default",
}

---@type NvPortConfig
M.config = {}

--- Setup the plugin with user configuration.
---@param opts? NvPortConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
end

return M
