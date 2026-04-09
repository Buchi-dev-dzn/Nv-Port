-- plugin/nv-port.lua
-- This file is automatically sourced by Neovim at startup.
-- Register commands and keymaps here.

if vim.g.loaded_nv_port then
  return
end
vim.g.loaded_nv_port = true

vim.api.nvim_create_user_command("NvPort", function(_opts)
  -- Example command
  vim.notify("nv-port is loaded!", vim.log.levels.INFO)
end, { desc = "Run nv-port" })
