local status, nvim_aider = pcall(require, "nvim_aider")
local mock = require("luassert.mock")
local spy = require("luassert.spy")

-- Create mock nvim-tree.api module
local mock_tree_api = {
  tree = {
    get_node_under_cursor = function() end
  }
}
package.loaded['nvim-tree.api'] = mock_tree_api

describe("nvim_aider", function()
  it("imports successfully", function()
    assert(status, "nvim_aider module should load")
  end)
  it("calls setup without arguments", function()
    -- Ensure that calling setup without arguments does not error
    local ok, err = pcall(function()
      nvim_aider.setup()
    end)
    assert(ok, "Expected setup() without arguments to not raise an error, but got: " .. (err or ""))

    -- Check that the user commands were created
    local user_commands = vim.api.nvim_get_commands({})
    local expected_commands = {
      "AiderTerminalToggle",
      "AiderTerminalSend",
      "AiderQuickSendCommand",
      "AiderQuickSendBuffer",
      "AiderQuickAddFile",
      "AiderQuickDropFile",
      "AiderTreeAddFile",
      "AiderTreeDropFile",
    }
    for _, cmd in ipairs(expected_commands) do
      assert(user_commands[cmd], "Expected command '" .. cmd .. "' to be registered after setup()")
    end
  end)

  describe("nvim-tree integration", function()
    local terminal_mock

    before_each(function()
      -- Mock nvim-tree.api functions
      mock_tree_api.tree.get_node_under_cursor = function()
        return {
          absolute_path = "/path/to/test/file.lua"
        }
      end
      -- Mock terminal commands
      terminal_mock = mock(require("nvim_aider.terminal"), true)
    end)

    after_each(function()
      mock.revert(terminal_mock)
    end)

    it("should add file from tree when valid node selected", function()
      -- Set filetype to NvimTree
      vim.bo.filetype = "NvimTree"


      -- Mock vim.fn.fnamemodify to return relative path
      local orig_fnamemodify = vim.fn.fnamemodify
      vim.fn.fnamemodify = function(path, mod)
        if mod == ":." then
          return "path/to/test/file.lua"
        end
        return orig_fnamemodify(path, mod)
      end

      -- Call the add file command
      vim.cmd("AiderTreeAddFile")

      -- Verify terminal command was called with correct path
      assert.stub(terminal_mock.command).was_called_with("/add", "path/to/test/file.lua")

      -- Restore original fnamemodify
      vim.fn.fnamemodify = orig_fnamemodify
    end)

    it("should drop file from tree when valid node selected", function()
      -- Set filetype to NvimTree
      vim.bo.filetype = "NvimTree"


      -- Mock vim.fn.fnamemodify to return relative path
      local orig_fnamemodify = vim.fn.fnamemodify
      vim.fn.fnamemodify = function(path, mod)
        if mod == ":." then
          return "path/to/test/file.lua"
        end
        return orig_fnamemodify(path, mod)
      end

      -- Call the drop file command
      vim.cmd("AiderTreeDropFile")

      -- Verify terminal command was called with correct path
      assert.stub(terminal_mock.command).was_called_with("/drop", "path/to/test/file.lua")

      -- Restore original fnamemodify
      vim.fn.fnamemodify = orig_fnamemodify
    end)

    it("should show warning when not in nvim-tree buffer", function()
      -- Set filetype to something else
      vim.bo.filetype = "lua"

      -- Spy on vim.notify
      local notify_spy = spy.on(vim, "notify")

      -- Call commands
      vim.cmd("AiderTreeAddFile")
      vim.cmd("AiderTreeDropFile")

      -- Verify warnings were shown
      assert.spy(notify_spy).was_called_with("Not in nvim-tree buffer", vim.log.levels.WARN)
      assert.spy(notify_spy).was_called_with("Not in nvim-tree buffer", vim.log.levels.WARN)
    end)

    it("should handle invalid nodes gracefully", function()
      -- Set filetype to NvimTree
      vim.bo.filetype = "NvimTree"

      -- Mock node under cursor to return nil
      mock_tree_api.tree.get_node_under_cursor = function()
        return nil
      end

      -- Spy on vim.notify
      local notify_spy = spy.on(vim, "notify")

      -- Call commands
      vim.cmd("AiderTreeAddFile")
      vim.cmd("AiderTreeDropFile")

      -- Verify warnings were shown
      assert.spy(notify_spy).was_called_with("No node found under cursor", vim.log.levels.WARN)
      assert.spy(notify_spy).was_called_with("No node found under cursor", vim.log.levels.WARN)
    end)
  end)
end)
