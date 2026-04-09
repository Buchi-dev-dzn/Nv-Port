--- reporter/init.lua
--- Generate Markdown and JSON reports, and display them in a buffer.

local util = require("nv-port.util")

local M = {}

-- ---------------------------------------------------------------------------
-- Floating Window Helper
-- ---------------------------------------------------------------------------

---@param lines string[]
---@param title string
---@param opts? { width?: integer, height?: integer }
function M.show_float(lines, title, opts)
  opts = opts or {}
  local width = opts.width or math.min(90, vim.o.columns - 4)
  local height = opts.height or math.min(#lines + 2, vim.o.lines - 6)

  -- Create a scratch buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

  -- Center the window
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win_opts = {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  }

  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_set_option_value("winhl", "Normal:Normal,FloatBorder:FloatBorder", { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  -- Keymaps to close
  local close = function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, silent = true })

  return buf, win
end

--- Open a normal (split) buffer with content.
---@param lines string[]
---@param name string buffer name
function M.show_buffer(lines, name)
  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, name)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  vim.keymap.set("n", "q", ":bd!<CR>", { buffer = buf, nowait = true, silent = true })
end

-- ---------------------------------------------------------------------------
-- Export Report
-- ---------------------------------------------------------------------------

---@param data table  export result data
---@return string[] lines  Markdown lines
function M.export_report_lines(data)
  local lines = {
    "# NvPort Export Report",
    "",
    "| Field | Value |",
    "|-------|-------|",
    "| Mode | " .. (data.mode or "?") .. " |",
    "| OS | " .. (data.source_os or "?") .. " |",
    "| Arch | " .. (data.source_arch or "?") .. " |",
    "| Neovim | " .. (data.nvim_version or "?") .. " |",
    "| Plugin Manager | " .. (data.plugin_manager or "unknown") .. " |",
    "| Exported At | " .. (data.exported_at or "?") .. " |",
    "| Output | " .. (data.output_path or "?") .. " |",
    "",
  }

  -- Plugins
  if data.plugin_summary then
    table.insert(lines, "## Plugins")
    table.insert(lines, "")
    table.insert(lines, "Total: **" .. (data.plugin_summary.total or 0) .. "**")
    table.insert(lines, "")
  end

  -- Dependencies
  if data.deps then
    table.insert(lines, "## Dependencies")
    table.insert(lines, "")
    for _, dep in ipairs(data.deps) do
      local status = dep.found and "✅" or (dep.category == "required" and "❌" or "⚠️")
      local ver = dep.version and (" `" .. dep.version:sub(1, 40) .. "`") or ""
      table.insert(lines, string.format("- %s **%s**%s  _%s_", status, dep.name, ver, dep.reason))
    end
    table.insert(lines, "")
  end

  -- Portability warnings
  if data.portability_warnings then
    local pw = data.portability_warnings
    if #pw == 0 then
      table.insert(lines, "## Portability")
      table.insert(lines, "")
      table.insert(lines, "✅ No portability issues detected.")
      table.insert(lines, "")
    else
      table.insert(lines, "## Portability Warnings (" .. #pw .. ")")
      table.insert(lines, "")
      for _, w in ipairs(pw) do
        local short_file = vim.fn.fnamemodify(w.file, ":t")
        table.insert(lines, string.format(
          "- ⚠️  **%s** line %d — `%s`  \n  → %s  \n  💡 %s",
          short_file, w.line, w.matched, w.reason, w.suggestion
        ))
      end
      table.insert(lines, "")
    end
  end

  return lines
end

---@param data table
---@return string  JSON string
function M.export_report_json(data)
  return util.json_encode(data)
end

-- ---------------------------------------------------------------------------
-- Inspect Report
-- ---------------------------------------------------------------------------

---@param manifest table
---@param dep_data table|nil
---@param port_warnings table|nil
---@return string[] lines
function M.inspect_lines(manifest, dep_data, port_warnings)
  local lines = {
    "# NvPort Package Inspection",
    "",
    "| Field | Value |",
    "|-------|-------|",
    "| Schema Version | " .. (manifest.schema_version or "?") .. " |",
    "| Export Mode | " .. (manifest.export_mode or "?") .. " |",
    "| Source OS | " .. (manifest.source_os or "?") .. " |",
    "| Source Arch | " .. (manifest.source_arch or "?") .. " |",
    "| Neovim Version | " .. (manifest.source_nvim_version or "?") .. " |",
    "| Plugin Manager | " .. (manifest.plugin_manager or "?") .. " |",
    "| Exported At | " .. (manifest.exported_at or "?") .. " |",
    "",
  }

  -- Plugin summary
  if manifest.plugin_summary then
    local ps = manifest.plugin_summary
    table.insert(lines, "## Plugins")
    table.insert(lines, "")
    table.insert(lines, "Total: **" .. (ps.total or 0) .. "**")
    table.insert(lines, "")
  end

  -- Dependencies
  if dep_data then
    table.insert(lines, "## Required Tools")
    table.insert(lines, "")
    local required = dep_data.required or {}
    local optional = dep_data.optional or {}
    if #required > 0 then
      table.insert(lines, "**Required:**")
      for _, d in ipairs(required) do
        table.insert(lines, "- " .. d.name)
      end
    end
    if #optional > 0 then
      table.insert(lines, "")
      table.insert(lines, "**Optional:**")
      for _, d in ipairs(optional) do
        table.insert(lines, "- " .. d.name)
      end
    end
    table.insert(lines, "")
  end

  -- Portability warnings
  if port_warnings and #port_warnings > 0 then
    table.insert(lines, "## Portability Warnings (" .. #port_warnings .. ")")
    table.insert(lines, "")
    for _, w in ipairs(port_warnings) do
      local short_file = vim.fn.fnamemodify(w.file or "", ":t")
      table.insert(lines, string.format("- ⚠️  **%s** line %d — %s", short_file, w.line or 0, w.reason))
    end
    table.insert(lines, "")
  end

  return lines
end

-- ---------------------------------------------------------------------------
-- Import Preview Report
-- ---------------------------------------------------------------------------

---@param manifest table
---@param dest_config_root string
---@param warnings table  portability warnings
---@param os_diff boolean  true if source OS != current OS
---@return string[] lines
function M.import_preview_lines(manifest, dest_config_root, warnings, os_diff)
  local lines = {
    "# NvPort Import Preview",
    "",
    "> Run `:NvPort import {path} --confirm` to apply.",
    "",
    "## Package Info",
    "",
    "| Field | Value |",
    "|-------|-------|",
    "| Source OS | " .. (manifest.source_os or "?") .. " |",
    "| Neovim Version | " .. (manifest.source_nvim_version or "?") .. " |",
    "| Plugin Manager | " .. (manifest.plugin_manager or "?") .. " |",
    "| Export Mode | " .. (manifest.export_mode or "?") .. " |",
    "",
    "## Destination",
    "",
    "Config will be placed at: `" .. dest_config_root .. "`",
    "",
  }

  if os_diff then
    table.insert(lines, "## ⚠️  OS Mismatch")
    table.insert(lines, "")
    table.insert(lines, string.format(
      "Source: **%s** → Current: **%s**",
      manifest.source_os or "?",
      vim.fn.has("mac") == 1 and "macos" or (vim.fn.has("win32") == 1 and "windows" or "linux")
    ))
    table.insert(lines, "")
    table.insert(lines, "Some OS-specific settings may not work correctly.")
    table.insert(lines, "Review portability warnings below.")
    table.insert(lines, "")
  end

  if warnings and #warnings > 0 then
    table.insert(lines, "## Portability Warnings (" .. #warnings .. ")")
    table.insert(lines, "")
    for _, w in ipairs(warnings) do
      local short_file = vim.fn.fnamemodify(w.file or "", ":t")
      table.insert(lines, string.format("- ⚠️  **%s** line %d — %s", short_file, w.line or 0, w.reason))
      table.insert(lines, "  💡 " .. w.suggestion)
    end
    table.insert(lines, "")
  end

  return lines
end

return M
