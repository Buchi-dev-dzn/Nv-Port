--- adapters/linux.lua
--- Linux-specific paths, dependencies, and tooling.

local util = require("nv-port.util")

local M = {}

M.os_name = "linux"

-- ---------------------------------------------------------------------------
-- Paths
-- ---------------------------------------------------------------------------

M.config_root = util.config_path()
M.data_root = util.data_path()
M.lockfile_path = util.lazy_lockfile() or (util.data_path() .. "/lazy/lazy-lock.json")

-- ---------------------------------------------------------------------------
-- ZIP Commands
-- ---------------------------------------------------------------------------

---@param src_dir string
---@param dest_zip string
---@return boolean ok, string|nil err
function M.zip(src_dir, dest_zip)
  local cmd = string.format("cd %s && zip -r %s .", vim.fn.shellescape(src_dir), vim.fn.shellescape(dest_zip))
  local _, code = util.run(cmd)
  if code ~= 0 then
    return false, "zip command failed (exit code: " .. code .. ")"
  end
  return true, nil
end

---@param zip_path string
---@param dest_dir string
---@return boolean ok, string|nil err
function M.unzip(zip_path, dest_dir)
  vim.fn.mkdir(dest_dir, "p")
  local cmd = string.format("unzip -o %s -d %s", vim.fn.shellescape(zip_path), vim.fn.shellescape(dest_dir))
  local _, code = util.run(cmd)
  if code ~= 0 then
    return false, "unzip command failed (exit code: " .. code .. ")"
  end
  return true, nil
end

---@param zip_path string
---@return string[]
function M.zip_list(zip_path)
  local out, _ = util.run("unzip -l " .. vim.fn.shellescape(zip_path))
  local files = {}
  for _, line in ipairs(out) do
    local fname = line:match("^%s*%d+%s+%S+%s+%S+%s+(.+)$")
    if fname and not fname:match("/$") then
      table.insert(files, fname)
    end
  end
  return files
end

-- ---------------------------------------------------------------------------
-- Dependency Checks
-- ---------------------------------------------------------------------------

---@type table[]
M.dep_checks = {
  { name = "git", cmd = "git", category = "required", reason = "Plugin installation via lazy.nvim" },
  { name = "node", cmd = "node", category = "optional", reason = "Required by many LSP servers" },
  { name = "python3", cmd = "python3", category = "optional", reason = "Required by some plugins" },
  { name = "ripgrep", cmd = "rg", category = "optional", reason = "Faster grep for telescope/fzf" },
  { name = "fd", cmd = "fd", category = "optional", reason = "Faster find for telescope/fzf" },
  { name = "lazygit", cmd = "lazygit", category = "optional", reason = "Git TUI integration" },
  { name = "make", cmd = "make", category = "optional", reason = "Build tool for some plugins" },
  -- clipboard (detect whichever is available)
  { name = "xclip (clipboard)", cmd = "xclip", category = "optional", reason = "X11 clipboard" },
  { name = "xsel (clipboard)", cmd = "xsel", category = "optional", reason = "X11 clipboard alternative" },
  { name = "wl-clipboard", cmd = "wl-copy", category = "optional", reason = "Wayland clipboard" },
}

---@return table[]
function M.scan_deps()
  local results = {}
  for _, dep in ipairs(M.dep_checks) do
    local found = util.executable(dep.cmd)
    local version = nil
    if found then
      local out, code = util.run(dep.cmd .. " --version 2>/dev/null")
      if code == 0 and out[1] then
        version = util.trim(out[1])
      end
    end
    table.insert(results, {
      name = dep.name,
      cmd = dep.cmd,
      category = dep.category,
      reason = dep.reason,
      found = found,
      version = version,
    })
  end
  return results
end

-- ---------------------------------------------------------------------------
-- Clipboard
-- ---------------------------------------------------------------------------

---@return boolean
function M.has_clipboard()
  return util.executable("xclip") or util.executable("xsel") or util.executable("wl-copy")
end

---@return string|nil
function M.clipboard_cmd()
  if util.executable("wl-copy") then
    return "wl-copy"
  elseif util.executable("xclip") then
    return "xclip"
  elseif util.executable("xsel") then
    return "xsel"
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Package Manager
-- ---------------------------------------------------------------------------

---@return string|nil
function M.detect_pkg_manager()
  if util.executable("apt") then
    return "apt"
  elseif util.executable("pacman") then
    return "pacman"
  elseif util.executable("dnf") then
    return "dnf"
  elseif util.executable("zypper") then
    return "zypper"
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Shell
-- ---------------------------------------------------------------------------

---@return string
function M.default_shell()
  return vim.fn.getenv("SHELL") or "/bin/bash"
end

return M
