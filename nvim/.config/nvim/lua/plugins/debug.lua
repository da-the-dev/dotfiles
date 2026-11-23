-- Debugging (DAP, the protocol VSCode uses). nvim-dap is the core; adapters per language;
-- the UI (nvim-dap-view) is a separate spec so it can be swapped for nvim-dap-ui.
-- Projects' .vscode/launch.json configurations are picked up automatically.

local function dap(fn, ...)
  local args = { ... }
  return function() require("dap")[fn](unpack(args)) end
end

return {
  {
    "mfussenegger/nvim-dap",
    dependencies = { "mfussenegger/nvim-dap-python", "igorlfs/nvim-dap-view" },
    keys = {
      -- VSCode keys (function keys may not reach nvim over ssh/tmux; <leader>d always works)
      { "<F5>", dap("continue"), desc = "Debug: start/continue" },
      { "<S-F5>", dap("terminate"), desc = "Debug: stop" },
      { "<F17>", dap("terminate"), desc = "Debug: stop" }, -- what some terminals send for Shift+F5
      { "<F9>", dap("toggle_breakpoint"), desc = "Debug: toggle breakpoint" },
      { "<F10>", dap("step_over"), desc = "Debug: step over" },
      { "<F11>", dap("step_into"), desc = "Debug: step into" },
      { "<S-F11>", dap("step_out"), desc = "Debug: step out" },
      { "<F23>", dap("step_out"), desc = "Debug: step out" }, -- Shift+F11 in some terminals

      { "<leader>dc", dap("continue"), desc = "Start / continue" },
      { "<leader>dq", dap("terminate"), desc = "Stop" },
      { "<leader>db", dap("toggle_breakpoint"), desc = "Toggle breakpoint" },
      {
        "<leader>dB",
        function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end,
        desc = "Conditional breakpoint",
      },
      { "<leader>dn", dap("step_over"), desc = "Step over (next)" },
      { "<leader>di", dap("step_into"), desc = "Step into" },
      { "<leader>do", dap("step_out"), desc = "Step out" },
      { "<leader>dC", dap("run_to_cursor"), desc = "Run to cursor" },
      { "<leader>dl", dap("run_last"), desc = "Re-run last" },
      { "<leader>dx", dap("clear_breakpoints"), desc = "Clear all breakpoints" },
      { "<leader>dt", function() require("dap-python").test_method() end, desc = "Debug test under cursor" },
    },
    config = function()
      -- VSCode-style breakpoint markers in the sign column
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticHint" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "Visual" })

      -- Python: debugpy runs from nvim's python host (config/options.lua), but debugs your
      -- code with the interpreter picked via <leader>cv (lua/python_env.lua)
      local dap_python = require("dap-python")
      dap_python.setup(vim.g.python3_host_prog or "python3")
      dap_python.resolve_python = function() return require("python_env").current() end
      dap_python.test_runner = "pytest"

      -- C/C++: lldb-dap (Xcode on macOS, LLVM on Linux), else gdb's built-in DAP (gdb 14+)
      local d = require("dap")
      local lldb_dap = vim.fn.exepath("lldb-dap")
      if lldb_dap == "" and vim.fn.has("mac") == 1 then
        lldb_dap = vim.trim(vim.fn.system({ "xcrun", "-f", "lldb-dap" }))
      end
      local adapter
      if vim.fn.executable(lldb_dap) == 1 then
        d.adapters.lldb = { type = "executable", command = lldb_dap, name = "lldb" }
        adapter = "lldb"
      elseif vim.fn.executable("gdb") == 1 then
        d.adapters.gdb = { type = "executable", command = "gdb", args = { "--interpreter=dap", "--eval-command", "set print pretty on" } }
        adapter = "gdb"
      end
      if adapter then
        d.configurations.c = {
          {
            name = "Launch executable",
            type = adapter,
            request = "launch",
            program = function() return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file") end,
            args = function() return vim.split(vim.fn.input("Arguments: "), " ", { trimempty = true }) end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
          },
        }
        d.configurations.cpp = d.configurations.c
      end
    end,
  },

  -- Debug UI: one panel below the code with tabs (variables, watches, breakpoints, call
  -- stack, REPL, program output), opened/closed with the session; values shown inline.
  -- To try nvim-dap-ui instead, replace this spec (and add nvim-dap-virtual-text for inline values).
  {
    "igorlfs/nvim-dap-view",
    version = "1.*",
    keys = {
      { "<leader>du", function() require("dap-view").toggle() end, desc = "Toggle debug panel" },
      { "<leader>dw", function() require("dap-view").add_expr() end, desc = "Watch expression under cursor" },
      { "<leader>dr", function() require("dap-view").jump_to_view("repl") end, desc = "Debug REPL" },
    },
    opts = {
      auto_toggle = true, -- open when debugging starts, close when it ends
      winbar = {
        sections = { "scopes", "watches", "breakpoints", "threads", "exceptions", "repl", "console" },
        default_section = "scopes",
        controls = { enabled = true }, -- clickable continue/step/stop buttons, like VSCode's toolbar
      },
      virtual_text = { enabled = true, position = "eol" }, -- variable values at end of line
    },
  },
}
