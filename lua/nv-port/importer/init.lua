--- importer/init.lua
--- Import a NvPort ZIP archive: preview or apply to the current system.

local util = require("nv-port.util")
local adapters = require("nv-port.adapters")
local archive = require("nv-port.archive")
local reporter = require("nv-port.reporter")

local M = {}

-- ---------------------------------------------------------------------------
-- Internal Helpers
-- ---------------------------------------------------------------------------

--- Parse args string for --confirm flag.
---@param args string
---@return string zip_path, boolean confirm
local function parse_args(args)
  local confirm = args:find("--confirm") ~= nil
  local zip_path = args:gsub("%s*%-%-confirm%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return zip_path, confirm
end

--- Extract archive and read manifest + portability data.
---@param zip_path string absolute expanded path
---@return string|nil tmp_dir, table|nil manifest, table port_warnings, string|nil err
local function load_package(zip_path)
  -- Verify first
  local ok, v_err = archive.verify(zip_path)
  if not ok then
    return nil, nil, {}, v_err
  end

  -- Extract to temp dir
  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir, "p")
  local ex_ok, ex_err = archive.extract(zip_path, tmp_dir)
  if not ex_ok then
    vim.fn.delete(tmp_dir, "rf")
    return nil, nil, {}, "Extraction failed: " .. (ex_err or "")
  end

  -- Read manifest
  local manifest_str, m_err = util.read_file(tmp_dir .. "/manifest.json")
  if m_err or not manifest_str then
    vim.fn.delete(tmp_dir, "rf")
    return nil, nil, {}, "Cannot read manifest.json: " .. (m_err or "")
  end
  local manifest, j_err = util.json_decode(manifest_str)
  if j_err or not manifest then
    vim.fn.delete(tmp_dir, "rf")
    return nil, nil, {}, "Corrupt manifest.json: " .. (j_err or "")
  end

  -- Schema version check
  local schema = manifest.schema_version or "0"
  if schema ~= "1" then
    util.warn("Unknown schema version: " .. schema .. ". Proceeding with caution.")
  end

  -- Read portability warnings (if present)
  local port_warnings = {}
  local port_path = tmp_dir .. "/portability/warnings.json"
  if util.file_exists(port_path) then
    local ps, _ = util.read_file(port_path)
    if ps then
      port_warnings, _ = util.json_decode(ps)
      port_warnings = port_warnings or {}
    end
  end

  return tmp_dir, manifest, port_warnings, nil
end

--- Recursively copy files from src_dir to dest_dir.
---@param src_dir string
---@param dest_dir string
local function copy_tree(src_dir, dest_dir)
  vim.fn.mkdir(dest_dir, "p")
  local files = util.list_files(src_dir)
  for _, src_file in ipairs(files) do
    local rel = src_file:sub(#src_dir + 2)
    local dest_file = dest_dir .. "/" .. rel
    vim.fn.mkdir(vim.fn.fnamemodify(dest_file, ":h"), "p")
    util.copy_file(src_file, dest_file)
  end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Preview (and optionally apply) a NvPort package.
---@param raw_args string  e.g. "/path/to/package.zip" or "/path/to/package.zip --confirm"
function M.import(raw_args)
  local zip_path, do_confirm = parse_args(raw_args or "")
  zip_path = vim.fn.expand(zip_path)

  if zip_path == "" then
    util.error("Usage: :NvPort import {path/to/archive.zip} [--confirm]")
    return
  end

  -- ── Load package ──────────────────────────────────────────────────────────
  util.notify("Loading package …")
  local tmp_dir, manifest, port_warnings, load_err = load_package(zip_path)
  if load_err or not manifest then
    util.error(load_err or "Failed to load package")
    return
  end

  local adapter = adapters.get()
  local current_os = util.detect_os()
  local os_diff = (manifest.source_os or "") ~= current_os
  local dest_config = adapter.config_root

  -- ── Preview ───────────────────────────────────────────────────────────────
  local preview_lines = reporter.import_preview_lines(manifest, dest_config, port_warnings, os_diff)

  if not do_confirm then
    -- Show preview only — no changes made
    table.insert(preview_lines, "---")
    table.insert(preview_lines, "")
    table.insert(preview_lines, "💡 Run `:NvPort import " .. zip_path .. " --confirm` to apply.")

    reporter.show_float(preview_lines, "NvPort Import Preview", { width = 80, height = 30 })
    vim.fn.delete(tmp_dir, "rf")
    return
  end

  -- ── Apply ─────────────────────────────────────────────────────────────────
  util.notify("Applying package …")

  -- Copy config files
  local config_src = tmp_dir .. "/config"
  if util.dir_exists(config_src) then
    copy_tree(config_src, dest_config)
    util.notify("Config placed at: " .. dest_config)
  else
    util.warn("No config/ directory found in archive. Skipping config placement.")
  end

  -- Copy lockfile
  local lockfile_src = tmp_dir .. "/plugins/lockfile.json"
  if util.file_exists(lockfile_src) then
    -- Favor dynamic path relative to current stdpath to prevent cross-app leakage
    local lockfile_dest = util.lazy_lockfile() or (util.config_path() .. "/lazy-lock.json")
    vim.fn.mkdir(vim.fn.fnamemodify(lockfile_dest, ":h"), "p")
    util.copy_file(lockfile_src, lockfile_dest)
    util.notify("Lockfile placed at: " .. lockfile_dest)
  end

  -- Cleanup temp dir
  vim.fn.delete(tmp_dir, "rf")

  -- ── Post-import guidance ──────────────────────────────────────────────────
  local done_lines = {
    "# NvPort Import — Complete",
    "",
    "✅ Config placed at: `" .. dest_config .. "`",
    "",
    "## Next Steps",
    "",
    "1. **Restart Neovim** to reload the new configuration.",
    "2. Run `:Lazy restore` to restore plugins from lockfile.",
    "3. Run `:NvPort doctor` to verify the environment.",
    "",
    "## Plugin Restore Command",
    "",
    "```",
    ":Lazy restore",
    "```",
  }

  reporter.show_float(done_lines, "NvPort Import — Done", { width = 70, height = 20 })

  -- Auto-launch doctor after a short delay
  vim.defer_fn(function()
    require("nv-port.doctor").run()
  end, 800)
end

return M
