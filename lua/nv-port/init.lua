--- nv-port/init.lua
--- Public API and entry point for the NvPort plugin.

local M = {}

--- Setup NvPort with user configuration.
---
--- Example (lazy.nvim):
---   require("nv-port").setup({
---     output_dir    = "~/my-backups",
---     default_mode  = "portable",
---   })
---
---@param opts? NvPortConfig
function M.setup(opts)
  require("nv-port.config").setup(opts)
end

-- ---------------------------------------------------------------------------
-- Convenience wrappers (for programmatic use from other plugins / scripts)
-- ---------------------------------------------------------------------------

--- Export the current Neovim environment.
---@param mode? "instant"|"portable"|"full"
---@param output_path? string
function M.export(mode, output_path)
  require("nv-port.exporter").export(mode, output_path)
end

--- Import a NvPort archive (preview or apply).
---@param args string  e.g. "/path/to/file.zip" or "/path/to/file.zip --confirm"
function M.import(args)
  require("nv-port.importer").import(args)
end

--- Inspect a NvPort archive without applying it.
---@param zip_path string
function M.inspect(zip_path)
  require("nv-port.inspector").inspect(zip_path)
end

--- Run the Doctor diagnostics.
function M.doctor()
  require("nv-port.doctor").run()
end

return M
