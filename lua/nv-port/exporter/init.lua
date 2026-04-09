--- exporter/init.lua
--- Orchestrates the export process: collect config, build manifest, create ZIP.

local util = require("nv-port.util")
local config = require("nv-port.config")
local adapters = require("nv-port.adapters")
local archive = require("nv-port.archive")
local portability = require("nv-port.portability")
local reporter = require("nv-port.reporter")

local M = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

--- Collect plugin info from lazy.nvim.
---@return table plugin_summary, table[] plugin_list
local function collect_lazy_plugins()
  local plugins = util.lazy_plugins()
  local list = {}
  for _, p in pairs(plugins) do
    table.insert(list, {
      name = p.name or "?",
      url = (p.url or (p.dir and "") or ""),
      version = p.commit or p.branch or p.tag or nil,
    })
  end
  table.sort(list, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  return { total = #list }, list
end

--- Build the files_map for archive.create().
--- Keys are ZIP-internal paths; values are absolute source paths.
---@param mode string
---@param plugin_list table[]
---@param dep_results table[]
---@param port_warnings table[]
---@param manifest table
---@param report_md string
---@return table<string, string> files_map
local function build_files_map(mode, plugin_list, dep_results, port_warnings, manifest, report_md)
  local files_map = {}
  local cfg_root = util.config_path()

  -- Config files
  local config_items = {
    "init.lua",
    "lua",
    "after",
    "ftplugin",
    "snippets",
  }
  for _, item in ipairs(config_items) do
    local src = cfg_root .. "/" .. item
    if util.file_exists(src) or util.dir_exists(src) then
      files_map["config/" .. item] = src
    end
  end

  -- Lockfile
  local lockfile = util.lazy_lockfile()
  if lockfile and util.file_exists(lockfile) then
    files_map["plugins/lockfile.json"] = lockfile
  end

  -- Manager info (inline JSON written to temp file)
  local manager_json = util.json_encode({
    name = "lazy.nvim",
    plugins = plugin_list,
  })
  local manager_tmp = vim.fn.tempname() .. ".json"
  util.write_file(manager_tmp, manager_json)
  files_map["plugins/manager.json"] = manager_tmp

  -- Dependencies
  local deps_json = util.json_encode({
    required = vim.tbl_filter(function(d)
      return d.category == "required"
    end, dep_results),
    optional = vim.tbl_filter(function(d)
      return d.category == "optional"
    end, dep_results),
    guessed = vim.tbl_filter(function(d)
      return d.category == "guessed"
    end, dep_results),
  })
  local deps_tmp = vim.fn.tempname() .. ".json"
  util.write_file(deps_tmp, deps_json)
  files_map["dependencies/detected-tools.json"] = deps_tmp

  -- Portability warnings (Portable mode only)
  if mode == "portable" or mode == "full" then
    local port_json = util.json_encode(port_warnings)
    local port_tmp = vim.fn.tempname() .. ".json"
    util.write_file(port_tmp, port_json)
    files_map["portability/warnings.json"] = port_tmp
  end

  -- Manifest
  local manifest_json = util.json_encode(manifest)
  local manifest_tmp = vim.fn.tempname() .. ".json"
  util.write_file(manifest_tmp, manifest_json)
  files_map["manifest.json"] = manifest_tmp

  -- Report
  local report_tmp = vim.fn.tempname() .. ".md"
  util.write_file(report_tmp, report_md)
  files_map["report.md"] = report_tmp

  return files_map
end

-- ---------------------------------------------------------------------------
-- Main Export
-- ---------------------------------------------------------------------------

---@param mode? "instant"|"portable"|"full"
---@param output_path? string  destination directory or full zip path
function M.export(mode, output_path)
  mode = mode or config.get("default_mode") or "portable"
  if mode ~= "instant" and mode ~= "portable" and mode ~= "full" then
    util.error("Unknown mode: " .. mode .. ". Use instant, portable, or full.")
    return
  end

  local adapter = adapters.get()
  util.notify("Starting export (mode: " .. mode .. ") …")

  -- 1. Collect system info
  local source_os = util.detect_os()
  local source_arch = util.detect_arch()
  local nvim_ver = util.nvim_version()
  local exported_at = os.date("!%Y-%m-%dT%H:%M:%SZ")

  -- 2. Collect plugins
  local plugin_summary, plugin_list = collect_lazy_plugins()

  -- 3. Scan dependencies
  util.notify("Scanning dependencies …")
  local dep_results = adapter.scan_deps()

  -- 4. Portability analysis (portable / full only)
  local port_warnings = {}
  if mode == "portable" or mode == "full" then
    util.notify("Analyzing portability …")
    port_warnings = portability.scan_dir(util.config_path())
    local port_summary = portability.summarize(port_warnings)
    if port_summary.total > 0 then
      util.warn(string.format("Found %d portability warning(s). Check the report for details.", port_summary.total))
    end
  end

  -- 5. Build manifest
  local manifest = {
    schema_version = config.get("schema_version") or "1",
    exported_at = exported_at,
    source_os = source_os,
    source_arch = source_arch,
    source_nvim_version = nvim_ver,
    plugin_manager = "lazy.nvim",
    export_mode = mode,
    config_root = util.config_path(),
    plugin_summary = plugin_summary,
    dependency_summary = {
      total = #dep_results,
      missing_required = #vim.tbl_filter(function(d)
        return d.category == "required" and not d.found
      end, dep_results),
    },
    portability_summary = (mode ~= "instant") and portability.summarize(port_warnings) or nil,
  }

  -- 6. Build report
  local report_data = {
    mode = mode,
    source_os = source_os,
    source_arch = source_arch,
    nvim_version = nvim_ver,
    exported_at = exported_at,
    plugin_manager = "lazy.nvim",
    plugin_summary = plugin_summary,
    deps = dep_results,
    portability_warnings = (mode ~= "instant") and port_warnings or nil,
  }
  local report_lines = reporter.export_report_lines(report_data)
  local report_md = table.concat(report_lines, "\n")

  -- 7. Determine output path
  local out_dir = output_path or config.get("output_dir") or vim.fn.expand("~/nvport-exports")
  vim.fn.mkdir(out_dir, "p")
  local filename = string.format("nvport-%s-%s.zip", mode, os.date("%Y%m%d-%H%M%S"))
  local dest_zip = out_dir .. "/" .. filename

  -- 8. Build archive
  util.notify("Building archive …")
  local files_map = build_files_map(mode, plugin_list, dep_results, port_warnings, manifest, report_md)

  local ok, err = archive.create(files_map, dest_zip)
  if not ok then
    util.error("Export failed: " .. (err or "unknown error"))
    return
  end

  -- 9. Show report in buffer
  report_data.output_path = dest_zip
  local final_lines = reporter.export_report_lines(report_data)
  table.insert(final_lines, 1, "")
  table.insert(final_lines, 1, "Archive: `" .. dest_zip .. "`")
  reporter.show_float(final_lines, "NvPort Export — " .. mode)

  util.notify("Export complete → " .. dest_zip)
end

return M
