--- portability/init.lua
--- Detect OS-specific patterns in Lua config files that may break cross-OS migration.

local util = require("nv-port.util")

local M = {}

-- ---------------------------------------------------------------------------
-- Pattern Definitions
-- ---------------------------------------------------------------------------

---@class PortabilityPattern
---@field id string
---@field pattern string  Lua pattern (string.find)
---@field reason string
---@field suggestion string
---@field auto_fixable boolean
---@field os_tag string  Which OS this is specific to

---@type PortabilityPattern[]
M.patterns = {
  {
    id = "macos_home_path",
    pattern = "/Users/[^/\"' ]+",
    reason = "Hardcoded macOS home path",
    suggestion = "Use vim.fn.expand('~') or os.getenv('HOME') instead",
    auto_fixable = false,
    os_tag = "macos",
  },
  {
    id = "homebrew_path",
    pattern = "/opt/homebrew",
    reason = "macOS Homebrew-specific path",
    suggestion = "Use vim.fn.exepath('brew') or check PATH dynamically",
    auto_fixable = false,
    os_tag = "macos",
  },
  {
    id = "homebrew_cellar",
    pattern = "/usr/local/Cellar",
    reason = "macOS Homebrew Cellar path (Intel Mac)",
    suggestion = "Use vim.fn.exepath() or rely on PATH",
    auto_fixable = false,
    os_tag = "macos",
  },
  {
    id = "pbcopy",
    pattern = "pbcopy",
    reason = "macOS-only clipboard command",
    suggestion = "Use vim.g.clipboard with OS detection or let Neovim handle clipboard automatically",
    auto_fixable = false,
    os_tag = "macos",
  },
  {
    id = "pbpaste",
    pattern = "pbpaste",
    reason = "macOS-only clipboard command",
    suggestion = "Use vim.g.clipboard with OS detection or let Neovim handle clipboard automatically",
    auto_fixable = false,
    os_tag = "macos",
  },
  {
    id = "windows_path",
    pattern = "C:\\\\[Uu]sers\\\\",
    reason = "Hardcoded Windows path",
    suggestion = "Use vim.fn.expand('~') or os.getenv('USERPROFILE')",
    auto_fixable = false,
    os_tag = "windows",
  },
  {
    id = "windows_path_fwd",
    pattern = "C:/Users/",
    reason = "Hardcoded Windows path (forward slash variant)",
    suggestion = "Use vim.fn.expand('~') or os.getenv('USERPROFILE')",
    auto_fixable = false,
    os_tag = "windows",
  },
  {
    id = "win32yank",
    pattern = "win32yank",
    reason = "Windows-only clipboard tool",
    suggestion = "Gate with vim.fn.has('win32') check",
    auto_fixable = false,
    os_tag = "windows",
  },
  {
    id = "powershell",
    pattern = "powershell%.exe",
    reason = "Windows-only shell reference",
    suggestion = "Gate with vim.fn.has('win32') check",
    auto_fixable = false,
    os_tag = "windows",
  },
  {
    id = "pwsh",
    pattern = '"pwsh"',
    reason = "PowerShell Core reference (Windows-common)",
    suggestion = "Gate with vim.fn.has('win32') or check vim.fn.executable('pwsh')",
    auto_fixable = false,
    os_tag = "windows",
  },
  {
    id = "exe_extension",
    pattern = "%.exe[\"' ]",
    reason = "Windows .exe binary reference",
    suggestion = "Use vim.fn.exepath() or vim.fn.executable() with the name only",
    auto_fixable = false,
    os_tag = "windows",
  },
  {
    id = "wsl",
    pattern = "wsl%.exe",
    reason = "WSL-specific reference",
    suggestion = "Gate with vim.fn.has('wsl') check",
    auto_fixable = false,
    os_tag = "windows",
  },
  {
    id = "shell_zsh_hardcoded",
    pattern = 'shell%s*=%s*["\']/?usr/bin/zsh["\']',
    reason = "Hardcoded zsh path — may not exist on all systems",
    suggestion = "Use vim.o.shell = vim.fn.exepath('zsh') or leave as default",
    auto_fixable = false,
    os_tag = "macos",
  },
  {
    id = "linux_home_path",
    pattern = "/home/[^/\"' ]+",
    reason = "Hardcoded Linux home path",
    suggestion = "Use vim.fn.expand('~') or os.getenv('HOME') instead",
    auto_fixable = false,
    os_tag = "linux",
  },
}

-- ---------------------------------------------------------------------------
-- Analyze
-- ---------------------------------------------------------------------------

---@class PortabilityWarning
---@field file string
---@field line integer
---@field col integer
---@field pattern_id string
---@field matched string
---@field reason string
---@field suggestion string
---@field auto_fixable boolean
---@field os_tag string

--- Scan a single file for portability issues.
---@param filepath string  absolute path
---@return PortabilityWarning[]
function M.scan_file(filepath)
  local warnings = {}
  local content, err = util.read_file(filepath)
  if err or not content then
    return warnings
  end

  local lines = vim.split(content, "\n", { plain = true })
  for lineno, line in ipairs(lines) do
    -- Skip comment lines (single-line Lua comments)
    if not line:match("^%s*%-%-") then
      for _, pat in ipairs(M.patterns) do
        local col = line:find(pat.pattern)
        if col then
          local matched = line:match(pat.pattern) or ""
          table.insert(warnings, {
            file = filepath,
            line = lineno,
            col = col,
            pattern_id = pat.id,
            matched = matched,
            reason = pat.reason,
            suggestion = pat.suggestion,
            auto_fixable = pat.auto_fixable,
            os_tag = pat.os_tag,
          })
        end
      end
    end
  end
  return warnings
end

--- Scan a directory of Lua files recursively.
---@param dir string  absolute path to config root
---@return PortabilityWarning[]
function M.scan_dir(dir)
  local all_warnings = {}
  local files = util.list_files(dir)
  for _, filepath in ipairs(files) do
    if filepath:match("%.lua$") then
      local w = M.scan_file(filepath)
      for _, warning in ipairs(w) do
        table.insert(all_warnings, warning)
      end
    end
  end
  return all_warnings
end

--- Summarize warnings into a count-by-os_tag table.
---@param warnings PortabilityWarning[]
---@return table summary { total, by_os }
function M.summarize(warnings)
  local by_os = {}
  for _, w in ipairs(warnings) do
    by_os[w.os_tag] = (by_os[w.os_tag] or 0) + 1
  end
  return {
    total = #warnings,
    by_os = by_os,
  }
end

return M
