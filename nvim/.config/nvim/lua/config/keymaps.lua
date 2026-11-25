-- Keymaps that don't belong to a plugin (plugin keymaps live in their spec in lua/plugins/)

-- Python interpreter picker (like VSCode's "Python: Select Interpreter"), see lua/python_env.lua
vim.keymap.set("n", "<leader>cv", function() require("python_env").pick() end, { desc = "Select Python interpreter" })
vim.api.nvim_create_user_command("PythonInterpreter", function() require("python_env").pick() end, {})

-- Format with the language server (Python: ruff, C/C++: clangd, Lua: lua_ls): the file, or the
-- selected lines. Not on save: autosave would reformat while you type.
vim.keymap.set({ "n", "x" }, "<leader>cf", function() vim.lsp.buf.format({ timeout_ms = 3000 }) end, { desc = "Format file / selection" })

-- Lazygit in a new tab w/ autoclose
vim.keymap.set("n", "<leader>gg", function()
  vim.cmd.tabnew()
  local buf = vim.api.nvim_get_current_buf()
  vim.fn.jobstart({ "lazygit" }, {
    term = true,
    on_exit = function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
  })
  -- lazygit uses <Esc> itself: don't make it wait for the <Esc><Esc> mapping below
  vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = buf, nowait = true })
  vim.cmd.startinsert()
end, { desc = "Lazygit" })

-- Windows: <C-h/j/k/l> to move between splits (incl. neo-tree), instead of <C-w>h/j/k/l
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Panels (lua/panel.lua): terminal, Claude, Python REPL
local panel = require("panel")

-- Terminal: a panel at the bottom like VSCode's
local terminal = panel(function()
  vim.cmd("botright split")
  vim.api.nvim_win_set_height(0, math.floor(vim.o.lines * 0.3))
end, vim.cmd.terminal)
vim.keymap.set({ "n", "t" }, "<C-`>", terminal.toggle, { desc = "Toggle terminal" })
vim.keymap.set("n", "<leader>t", terminal.toggle, { desc = "Toggle terminal" })

-- Claude Code: a panel on the right. Closes when Claude exits; a new toggle starts it again.
-- Files it edits are reloaded by the timer in config/autocmds.lua.
local claude = panel(function()
  vim.cmd("botright vsplit")
  vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * 0.4))
  vim.cmd("setlocal winfixwidth") -- keep its width when other windows open or close
end, function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.fn.jobstart({ "claude" }, {
    term = true,
    -- Claude's full-screen renderer: the default one sometimes ends up drawing on the wrong row in
    -- nvim's terminal after resizes (Ctrl+L repairs it)
    env = { CLAUDE_CODE_NO_FLICKER = "1" },
    on_exit = function()
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end,
  })
  -- Claude uses <Esc> (interrupt) and <Esc><Esc> (rewind) itself, so leave with <C-h> instead
  vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = buf, nowait = true })
  vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { buffer = buf, desc = "Go to left window" })
end)
local function toggle_claude()
  if vim.fn.executable("claude") == 0 then
    vim.notify("claude is not installed", vim.log.levels.WARN)
    return
  end
  claude.toggle()
end
vim.keymap.set({ "n", "t" }, "<C-.>", toggle_claude, { desc = "Toggle Claude" })
vim.keymap.set("n", "<leader>a", toggle_claude, { desc = "Toggle Claude" })

-- Python REPL: a panel on the right, see lua/repl.lua
vim.keymap.set("n", "<leader>rr", function() require("repl").toggle() end, { desc = "Toggle Python REPL" })
vim.keymap.set("n", "<leader>rl", function() require("repl").run_statement() end, { desc = "Run statement, go to next" })
vim.keymap.set("x", "<leader>r", function() require("repl").run_selection() end, { desc = "Run selection in REPL" })
vim.keymap.set("n", "<leader>rn", function() require("repl").restart() end, { desc = "New (fresh) REPL" })

-- YouTube videos (<leader>v...), see lua/video.lua; does nothing without mpv and yt-dlp
require("video").setup()

-- Leave terminal mode with <Esc><Esc> (single <Esc> still goes to the shell/program);
-- nvim's own <C-\><C-n> works too
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
