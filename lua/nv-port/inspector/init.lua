--- inspector/init.lua
--- Read a NvPort ZIP and display its contents without applying anything.

local util = require("nv-port.util")
local archive = require("nv-port.archive")
local reporter = require("nv-port.reporter")

local M = {}

--- Inspect a NvPort ZIP archive and display a summary in a floating window.
---@param zip_path string  expanded, absolute path to the ZIP
function M.inspect(zip_path)
  zip_path = vim.fn.expand(zip_path)

  -- 1. Verify
  local ok, err = archive.verify(zip_path)
  if not ok then
    util.error("Cannot inspect: " .. (err or "unknown error"))
    return
  end

  -- 2. Extract to temp dir
  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir, "p")
  local ex_ok, ex_err = archive.extract(zip_path, tmp_dir)
  if not ex_ok then
    util.error("Failed to extract archive: " .. (ex_err or ""))
    vim.fn.delete(tmp_dir, "rf")
    return
  end

  -- 3. Read manifest.json
  local manifest_path = tmp_dir .. "/manifest.json"
  local manifest_str, m_err = util.read_file(manifest_path)
  if m_err or not manifest_str then
    util.error("Cannot read manifest.json: " .. (m_err or ""))
    vim.fn.delete(tmp_dir, "rf")
    return
  end

  local manifest, j_err = util.json_decode(manifest_str)
  if j_err or not manifest then
    util.error("Corrupt manifest.json: " .. (j_err or ""))
    vim.fn.delete(tmp_dir, "rf")
    return
  end

  -- 4. Read dependencies (optional)
  local dep_data = nil
  local dep_path = tmp_dir .. "/dependencies/detected-tools.json"
  if util.file_exists(dep_path) then
    local dep_str, _ = util.read_file(dep_path)
    if dep_str then
      dep_data, _ = util.json_decode(dep_str)
    end
  end

  -- 5. Read portability warnings (optional)
  local port_warnings = nil
  local port_path = tmp_dir .. "/portability/warnings.json"
  if util.file_exists(port_path) then
    local port_str, _ = util.read_file(port_path)
    if port_str then
      port_warnings, _ = util.json_decode(port_str)
    end
  end

  -- 6. Cleanup temp dir
  vim.fn.delete(tmp_dir, "rf")

  -- 7. Build and show report
  local lines = reporter.inspect_lines(manifest, dep_data, port_warnings)
  -- append file size info
  local size_kb = math.ceil(vim.fn.getfsize(zip_path) / 1024)
  table.insert(lines, "---")
  table.insert(lines, "")
  table.insert(lines, string.format("Archive: `%s` (%d KB)", zip_path, size_kb))

  reporter.show_float(lines, "NvPort Inspect", { width = 80, height = 30 })
end

return M
