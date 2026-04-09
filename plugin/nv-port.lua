if vim.g.loaded_nv_port then
  return
end
vim.g.loaded_nv_port = true

vim.api.nvim_create_user_command("NvPort", function(opts)
  require("nv-port.commands").dispatch(opts.args)
end, {
  nargs = "*",
  complete = function(...)
    return require("nv-port.commands").complete(...)
  end,
  desc = "NvPort: Neovim environment portability tool",
})
