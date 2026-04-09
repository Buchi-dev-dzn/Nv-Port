--- adapters/windows.lua
--- Windows-specific paths, dependencies, and tooling.

local util = require("nv-port.util")

local M = {}

M.os_name = "windows"

-- ---------------------------------------------------------------------------
-- Paths
-- ---------------------------------------------------------------------------

M.config_root = util.config_path()
M.data_root = util.data_path()
M.lockfile_path = util.lazy_lockfile() or (util.data_path() .. "/lazy/lazy-lock.json")

-- ---------------------------------------------------------------------------
-- ZIP Commands (PowerShell)
-- ---------------------------------------------------------------------------

---@param src_dir string
---@param dest_zip string
---@return boolean ok, string|nil err
function M.zip(src_dir, dest_zip)
  -- Use PowerShell Compress-Archive
  local cmd = string.format(
    'powershell -NoProfile -Command "Compress-Archive -Path %s\\* -DestinationPath %s -Force"',
    src_dir:gsub("/", "\\"),
    dest_zip:gsub("/", "\\")
  )
  local _, code = util.run(cmd)
  if code ~= 0 then
    -- Fallback: try 7z if available
    if util.executable("7z") then
      local cmd7z = string.format("7z a %s %s\\*", vim.fn.shellescape(dest_zip), vim.fn.shellescape(src_dir))
      local _, c2 = util.run(cmd7z)
      if c2 == 0 then
        return true, nil
      end
    end
    return false, "zip failed: PowerShell Compress-Archive returned error code " .. code
  end
  return true, nil
end

---@param zip_path string
---@param dest_dir string
---@return boolean ok, string|nil err
function M.unzip(zip_path, dest_dir)
  vim.fn.mkdir(dest_dir, "p")
  local cmd = string.format(
    'powershell -NoProfile -Command "Expand-Archive -Path %s -DestinationPath %s -Force"',
    zip_path:gsub("/", "\\"),
    dest_dir:gsub("/", "\\")
  )
  local _, code = util.run(cmd)
  if code ~= 0 then
    if util.executable("7z") then
      local cmd7z = string.format("7z x %s -o%s -y", vim.fn.shellescape(zip_path), vim.fn.shellescape(dest_dir))
      local _, c2 = util.run(cmd7z)
      if c2 == 0 then
        return true, nil
      end
    end
    return false, "unzip failed: PowerShell Expand-Archive returned error code " .. code
  end
  return true, nil
end

---@param zip_path string
---@return string[]
function M.zip_list(zip_path)
  local cmd = string.format(
    'powershell -NoProfile -Command "(Get-ChildItem (Get-Item %s) | Select-Object -ExpandProperty Name)"',
    zip_path:gsub("/", "\\")
  )
  -- Simpler: use powershell to list zip contents
  local cmd2 = string.format(
    "powershell -NoProfile -Command \"Add-Type -Assembly System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::OpenRead('%s').Entries | Select-Object -ExpandProperty FullName\"",
    zip_path:gsub("/", "\\")
  )
  local out, _ = util.run(cmd2)
  local files = {}
  for _, line in ipairs(out) do
    local f = util.trim(line)
    if f ~= "" and not f:match("[\\/]$") then
      table.insert(files, f)
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
  { name = "win32yank (clipboard)", cmd = "win32yank", category = "optional", reason = "Windows clipboard for Neovim" },
  { name = "make", cmd = "make", category = "optional", reason = "Build tool for some plugins" },
  { name = "powershell", cmd = "powershell", category = "required", reason = "Required for ZIP operations" },
}

---@return table[]
function M.scan_deps()
  local results = {}
  for _, dep in ipairs(M.dep_checks) do
    local found = util.executable(dep.cmd)
    local version = nil
    if found then
      local out, code = util.run(dep.cmd .. " --version 2>nul")
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
  return util.executable("win32yank") or util.executable("clip")
end

---@return string|nil
function M.clipboard_cmd()
  if util.executable("win32yank") then
    return "win32yank"
  elseif util.executable("clip") then
    return "clip"
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Package Manager
-- ---------------------------------------------------------------------------

---@return string|nil
function M.detect_pkg_manager()
  if util.executable("winget") then
    return "winget"
  elseif util.executable("scoop") then
    return "scoop"
  elseif util.executable("choco") then
    return "chocolatey"
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Shell
-- ---------------------------------------------------------------------------

---@return string
function M.default_shell()
  if util.executable("pwsh") then
    return "pwsh"
  end
  return "powershell"
end

return M
