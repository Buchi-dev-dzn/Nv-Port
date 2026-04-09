--- util.lua
--- Common utilities for nv-port.

local M = {}

-- ---------------------------------------------------------------------------
-- Notification
-- ---------------------------------------------------------------------------

---@param msg string
---@param level? integer vim.log.levels.*
function M.notify(msg, level)
  vim.notify("[nv-port] " .. msg, level or vim.log.levels.INFO)
end

---@param msg string
function M.error(msg)
  vim.notify("[nv-port] " .. msg, vim.log.levels.ERROR)
end

---@param msg string
function M.warn(msg)
  vim.notify("[nv-port] " .. msg, vim.log.levels.WARN)
end

-- ---------------------------------------------------------------------------
-- File System
-- ---------------------------------------------------------------------------

---@param path string
---@return boolean
function M.file_exists(path)
  return vim.fn.filereadable(vim.fn.expand(path)) == 1
end

---@param path string
---@return boolean
function M.dir_exists(path)
  return vim.fn.isdirectory(vim.fn.expand(path)) == 1
end

--- Read a file and return its content as a string.
---@param path string
---@return string|nil content, string|nil err
function M.read_file(path)
  local expanded = vim.fn.expand(path)
  local ok, lines = pcall(vim.fn.readfile, expanded)
  if not ok or lines == nil then
    return nil, "Cannot read file: " .. expanded
  end
  return table.concat(lines, "\n"), nil
end

--- Write a string to a file (creates parent directories if needed).
---@param path string
---@param content string
---@return boolean ok, string|nil err
function M.write_file(path, content)
  local expanded = vim.fn.expand(path)
  local dir = vim.fn.fnamemodify(expanded, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
  local lines = vim.split(content, "\n", { plain = true })
  local ok = pcall(vim.fn.writefile, lines, expanded)
  if not ok then
    return false, "Cannot write file: " .. expanded
  end
  return true, nil
end

--- Copy a file to a destination path.
---@param src string
---@param dest string
---@return boolean ok, string|nil err
function M.copy_file(src, dest)
  local content, err = M.read_file(src)
  if err then
    return false, err
  end
  return M.write_file(dest, content)
end

--- Recursively list all files under a directory.
---@param dir string
---@return string[] file paths (absolute)
function M.list_files(dir)
  local expanded = vim.fn.expand(dir)
  if vim.fn.isdirectory(expanded) == 0 then
    return {}
  end
  local result = vim.fn.globpath(expanded, "**/*", false, true)
  local files = {}
  for _, p in ipairs(result) do
    if vim.fn.isdirectory(p) == 0 then
      table.insert(files, p)
    end
  end
  return files
end

-- ---------------------------------------------------------------------------
-- JSON
-- ---------------------------------------------------------------------------

--- Encode a table to a JSON string.
---@param t table
---@return string
function M.json_encode(t)
  return vim.fn.json_encode(t)
end

--- Decode a JSON string to a table.
---@param s string
---@return table|nil result, string|nil err
function M.json_decode(s)
  local ok, result = pcall(vim.fn.json_decode, s)
  if not ok then
    return nil, "JSON decode error: " .. tostring(result)
  end
  return result, nil
end

-- ---------------------------------------------------------------------------
-- Shell / Process
-- ---------------------------------------------------------------------------

--- Run a shell command and return output lines.
---@param cmd string
---@return string[] output, integer exit_code
function M.run(cmd)
  local output = vim.fn.systemlist(cmd)
  local code = vim.v.shell_error
  return output, code
end

--- Check if an executable is available.
---@param name string
---@return boolean
function M.executable(name)
  return vim.fn.executable(name) == 1
end

-- ---------------------------------------------------------------------------
-- String Utilities
-- ---------------------------------------------------------------------------

--- Trim whitespace from both ends of a string.
---@param s string
---@return string
function M.trim(s)
  return s:match("^%s*(.-)%s*$")
end

--- Join table values with separator.
---@param t string[]
---@param sep string
---@return string
function M.join(t, sep)
  return table.concat(t, sep)
end

-- ---------------------------------------------------------------------------
-- OS Detection
-- ---------------------------------------------------------------------------

---@return "macos"|"linux"|"windows"
function M.detect_os()
  if vim.fn.has("mac") == 1 then
    return "macos"
  elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    return "windows"
  else
    return "linux"
  end
end

---@return string e.g. "x86_64", "arm64"
function M.detect_arch()
  local out, _ = M.run("uname -m")
  if out and out[1] then
    return M.trim(out[1])
  end
  -- Windows fallback
  local arch = vim.fn.getenv("PROCESSOR_ARCHITECTURE")
  if arch and arch ~= vim.NIL then
    return tostring(arch):lower()
  end
  return "unknown"
end

---@return string absolute path to Neovim config directory
function M.config_path()
  return vim.fn.stdpath("config")
end

---@return string e.g. "0.10.4"
function M.nvim_version()
  local v = vim.version()
  return string.format("%d.%d.%d", v.major, v.minor, v.patch)
end

---@return string absolute path to Neovim data directory
function M.data_path()
  return vim.fn.stdpath("data")
end

--- Get the lazy-lock.json path via lazy.nvim if available.
---@return string|nil
function M.lazy_lockfile()
  -- 1. Try to get it from lazy.nvim core config (standard way)
  local ok, lazy_config = pcall(require, "lazy.core.config")
  if ok and lazy_config then
    if lazy_config.options and lazy_config.options.lockfile then
      return lazy_config.options.lockfile
    end
    if lazy_config.lockfile then
      return lazy_config.lockfile
    end
  end

  -- 2. Fallback: check standard locations relative to current stdpath
  local candidates = {
    M.config_path() .. "/lazy-lock.json",
    M.data_path() .. "/lazy/lazy-lock.json",
  }

  for _, path in ipairs(candidates) do
    if M.file_exists(path) then
      return path
    end
  end

  return nil
end

--- Get lazy.nvim plugin list.
---@return table[] plugins
function M.lazy_plugins()
  local ok, lazy = pcall(require, "lazy")
  if not ok then
    return {}
  end
  return (type(lazy.plugins) == "function" and lazy.plugins() or {})
end

return M
