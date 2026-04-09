--- archive/init.lua
--- ZIP creation, extraction and verification, delegating to OS-specific adapter.

local util = require("nv-port.util")
local adapters = require("nv-port.adapters")

local M = {}

-- ---------------------------------------------------------------------------
-- Create
-- ---------------------------------------------------------------------------

--- Stage files into a temp directory whose structure mirrors the ZIP layout,
--- then compress it into a single ZIP file.
---
---@param files_map table<string, string>  { [zip_internal_path] = absolute_src_path }
---@param dest_zip  string                 Destination ZIP path (absolute, expanded)
---@return boolean ok, string|nil err
function M.create(files_map, dest_zip)
  -- 1. Create a temp staging directory
  local stage_dir = vim.fn.tempname()
  vim.fn.mkdir(stage_dir, "p")

  -- 2. Copy every file into staging
  for rel_path, src in pairs(files_map) do
    local dest_file = stage_dir .. "/" .. rel_path
    local dest_dir = vim.fn.fnamemodify(dest_file, ":h")
    vim.fn.mkdir(dest_dir, "p")

    if util.file_exists(src) then
      local ok, err = util.copy_file(src, dest_file)
      if not ok then
        util.warn("Skipping " .. src .. ": " .. (err or "unknown error"))
      end
    elseif util.dir_exists(src) then
      -- Copy whole directory tree
      local sub_files = util.list_files(src)
      for _, sf in ipairs(sub_files) do
        local rel = sf:sub(#src + 2) -- strip leading src/ prefix
        local target = dest_file .. "/" .. rel
        vim.fn.mkdir(vim.fn.fnamemodify(target, ":h"), "p")
        util.copy_file(sf, target)
      end
    end
  end

  -- 3. Ensure parent dir for dest_zip exists
  local zip_dir = vim.fn.fnamemodify(dest_zip, ":h")
  vim.fn.mkdir(zip_dir, "p")

  -- 4. Compress staging dir → ZIP
  local adapter = adapters.get()
  local ok, err = adapter.zip(stage_dir, dest_zip)

  -- 5. Clean up staging dir
  vim.fn.delete(stage_dir, "rf")

  if not ok then
    return false, err
  end
  return true, nil
end

-- ---------------------------------------------------------------------------
-- Extract
-- ---------------------------------------------------------------------------

--- Extract a ZIP archive into dest_dir.
---@param zip_path string
---@param dest_dir string
---@return boolean ok, string|nil err
function M.extract(zip_path, dest_dir)
  local adapter = adapters.get()
  return adapter.unzip(zip_path, dest_dir)
end

-- ---------------------------------------------------------------------------
-- Verify
-- ---------------------------------------------------------------------------

--- Check that a ZIP is a valid NvPort package (manifest.json present).
---@param zip_path string
---@return boolean ok, string|nil err
function M.verify(zip_path)
  if not util.file_exists(zip_path) then
    return false, "File not found: " .. zip_path
  end

  local adapter = adapters.get()
  local files = adapter.zip_list(zip_path)

  local has_manifest = false
  for _, f in ipairs(files) do
    if f:match("manifest%.json$") then
      has_manifest = true
      break
    end
  end

  if not has_manifest then
    return false, "Invalid NvPort package: manifest.json not found in ZIP"
  end
  return true, nil
end

-- ---------------------------------------------------------------------------
-- List
-- ---------------------------------------------------------------------------

--- Return list of files inside a ZIP.
---@param zip_path string
---@return string[] files
function M.list(zip_path)
  local adapter = adapters.get()
  return adapter.zip_list(zip_path)
end

return M
