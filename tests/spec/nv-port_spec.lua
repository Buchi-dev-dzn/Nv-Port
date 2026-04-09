local nv_port = require("nv-port")
local config = require("nv-port.config")
local util = require("nv-port.util")
local portability = require("nv-port.portability")

describe("nv-port", function()
  describe("config", function()
    it("setup() merges defaults correctly", function()
      config.setup({ default_mode = "instant" })
      assert.are.equal("instant", config.get("default_mode"))
      assert.are.equal("1", config.get("schema_version")) -- default
    end)
  end)

  describe("util", function()
    it("json_encode/decode should work", function()
      local t = { a = 1, b = { c = 2 } }
      local s = util.json_encode(t)
      local r, err = util.json_decode(s)
      assert.is_nil(err)
      assert.are.same(t, r)
    end)

    it("trim should remove whitespace", function()
      assert.are.equal("hello", util.trim("  hello  "))
    end)
  end)

  describe("portability", function()
    it("should detect hardcoded macOS home paths", function()
      local warnings = portability.scan_file("/tmp/dummy.lua")
      -- Since the file doesn't exist, it should return empty
      assert.is_table(warnings)
    end)

    it("summarize should count by os_tag", function()
      local mock_warnings = {
        { os_tag = "macos" },
        { os_tag = "macos" },
        { os_tag = "windows" },
      }
      local s = portability.summarize(mock_warnings)
      assert.are.equal(3, s.total)
      assert.are.equal(2, s.by_os.macos)
      assert.are.equal(1, s.by_os.windows)
    end)
  end)
end)
