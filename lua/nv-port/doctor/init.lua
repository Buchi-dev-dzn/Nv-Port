--- doctor/init.lua
--- Diagnose the current Neovim environment and display results in a floating window.

local util = require("nv-port.util")
local adapters = require("nv-port.adapters")
local reporter = require("nv-port.reporter")

local M = {}

-- ---------------------------------------------------------------------------
-- Check Definitions
-- ---------------------------------------------------------------------------

---@class DoctorCheck
---@field id string
---@field label string
---@field run fun(): "ok"|"warn"|"error"|"info", string  returns (status, message)

---@type DoctorCheck[]
local checks = {
  -- Neovim version
  {
    id = "nvim_version",
    label = "Neovim version",
    run = function()
      local v = vim.version()
      local ver_str = string.format("%d.%d.%d", v.major, v.minor, v.patch)
      if v.major > 0 or v.minor >= 10 then
        return "ok", "Neovim " .. ver_str
      else
        return "error", "Neovim " .. ver_str .. " — requires >= 0.10"
      end
    end,
  },

  -- lazy.nvim
  {
    id = "lazy_nvim",
    label = "lazy.nvim",
    run = function()
      local ok, _ = pcall(require, "lazy")
      if ok then
        return "ok", "lazy.nvim is loaded"
      else
        return "error", "lazy.nvim not found — plugin restoration will fail"
      end
    end,
  },

  -- Config file
  {
    id = "config_init",
    label = "init.lua",
    run = function()
      local path = util.config_path() .. "/init.lua"
      if util.file_exists(path) then
        return "ok", path
      else
        return "warn", "init.lua not found at " .. path
      end
    end,
  },

  -- Lockfile
  {
    id = "lockfile",
    label = "lazy-lock.json",
    run = function()
      local path = util.lazy_lockfile()
      if path and util.file_exists(path) then
        return "ok", path
      else
        return "warn", "lockfile not found — ensure lazy.nvim is installed and configured"
      end
    end,
  },

  -- git
  {
    id = "git",
    label = "git",
    run = function()
      if util.executable("git") then
        local out, _ = util.run("git --version")
        return "ok", (out[1] or "git found")
      else
        return "error", "git not found — required for plugin installation"
      end
    end,
  },

  -- node
  {
    id = "node",
    label = "node",
    run = function()
      if util.executable("node") then
        local out, _ = util.run("node --version")
        return "ok", (out[1] or "node found")
      else
        return "warn", "node not found — required by many LSP servers (e.g. tsserver, pyright)"
      end
    end,
  },

  -- python3
  {
    id = "python3",
    label = "python3",
    run = function()
      if util.executable("python3") then
        local out, _ = util.run("python3 --version")
        return "ok", (out[1] or "python3 found")
      else
        return "warn", "python3 not found — required by some plugins"
      end
    end,
  },

  -- ripgrep
  {
    id = "ripgrep",
    label = "ripgrep (rg)",
    run = function()
      if util.executable("rg") then
        local out, _ = util.run("rg --version")
        return "ok", (out[1] or "rg found")
      else
        return "info", "ripgrep not found — recommended for telescope.nvim / fzf-lua"
      end
    end,
  },

  -- fd
  {
    id = "fd",
    label = "fd",
    run = function()
      if util.executable("fd") then
        local out, _ = util.run("fd --version")
        return "ok", (out[1] or "fd found")
      else
        return "info", "fd not found — recommended for telescope.nvim / fzf-lua"
      end
    end,
  },

  -- clipboard
  {
    id = "clipboard",
    label = "clipboard",
    run = function()
      local adapter = adapters.get()
      if adapter.has_clipboard() then
        local cmd = type(adapter.clipboard_cmd) == "function"
          and adapter.clipboard_cmd()
          or adapter.clipboard_cmd
        return "ok", "clipboard available" .. (cmd and (" via " .. cmd) or "")
      else
        return "error", "No clipboard tool found — yank/paste to system clipboard will not work"
      end
    end,
  },

  -- Nerd Font warning (icon-dependent plugins)
  {
    id = "nerd_font",
    label = "Nerd Font (icons)",
    run = function()
      local ok, _ = pcall(require, "nvim-web-devicons")
      if ok then
        return "info", "nvim-web-devicons detected — ensure a Nerd Font is active in your terminal"
      end
      local ok2, _ = pcall(require, "mini.icons")
      if ok2 then
        return "info", "mini.icons detected — ensure a Nerd Font is active in your terminal"
      end
      return "ok", "No icon plugin detected"
    end,
  },

  -- Treesitter
  {
    id = "treesitter",
    label = "nvim-treesitter",
    run = function()
      local ok, _ = pcall(require, "nvim-treesitter")
      if ok then
        return "ok", "nvim-treesitter is available"
      else
        return "info", "nvim-treesitter not loaded (optional)"
      end
    end,
  },

  -- Shell setting
  {
    id = "shell",
    label = "shell",
    run = function()
      local shell = vim.o.shell
      if shell and shell ~= "" then
        if util.executable(shell) or util.executable(vim.fn.fnamemodify(shell, ":t")) then
          return "ok", "shell = " .. shell
        else
          return "warn", "shell = " .. shell .. " (not found in PATH)"
        end
      else
        return "warn", "vim.o.shell is empty"
      end
    end,
  },
}

-- ---------------------------------------------------------------------------
-- Status Icons
-- ---------------------------------------------------------------------------

local STATUS_ICON = {
  ok = "✅",
  warn = "⚠️ ",
  error = "❌",
  info = "💡",
}

-- ---------------------------------------------------------------------------
-- Run
-- ---------------------------------------------------------------------------

--- Run all checks and display results in a floating window.
function M.run()
  local lines = {
    "# NvPort Doctor",
    "",
  }

  local counts = { ok = 0, warn = 0, error = 0, info = 0 }

  for _, check in ipairs(checks) do
    local status, message = check.run()
    local icon = STATUS_ICON[status] or "❓"
    counts[status] = (counts[status] or 0) + 1
    table.insert(lines, string.format("%s  **%s** — %s", icon, check.label, message))
  end

  -- Summary line
  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, string.format(
    "✅ %d  ⚠️  %d  ❌ %d  💡 %d",
    counts.ok, counts.warn, counts.error, counts.info
  ))

  -- Overall verdict
  table.insert(lines, "")
  if counts.error > 0 then
    table.insert(lines, "❌ **Issues found** — fix errors above before using NvPort.")
  elseif counts.warn > 0 then
    table.insert(lines, "⚠️  **Warnings present** — environment may have limitations.")
  else
    table.insert(lines, "✅ **Environment looks healthy!**")
  end

  reporter.show_float(lines, "NvPort Doctor", { width = 72, height = #lines + 2 })
end

--- Add a custom check (for user extensibility).
---@param check DoctorCheck
function M.add_check(check)
  table.insert(checks, check)
end

return M
