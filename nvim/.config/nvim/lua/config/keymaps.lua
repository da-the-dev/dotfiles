-- Keymaps that don't belong to a plugin (plugin keymaps live in their spec in lua/plugins/)

-- Python interpreter picker (like VSCode's "Python: Select Interpreter"), see lua/python_env.lua
vim.keymap.set("n", "<leader>cv", function() require("python_env").pick() end, { desc = "Select Python interpreter" })
vim.api.nvim_create_user_command("PythonInterpreter", function() require("python_env").pick() end, {})

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

-- Panels: a terminal at the edge of the screen, toggled by a key and kept running while hidden.
-- `split` opens the window and sets its size, `start` starts the program in it.
local function panel(split, start)
  local state = { buf = nil, win = nil }
  return function()
    if state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_buf(state.win) == state.buf then
      if #vim.api.nvim_tabpage_list_wins(0) == 1 then return end -- it's the only window: keep it
      vim.api.nvim_win_hide(state.win)
      state.win = nil
      return
    end
    split()
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      vim.api.nvim_win_set_buf(0, state.buf)
    else
      start()
      state.buf = vim.api.nvim_get_current_buf()
      vim.bo[state.buf].buflisted = false -- keep it out of the tab bar and <S-h>/<S-l>
    end
    state.win = vim.api.nvim_get_current_win()
    vim.cmd.startinsert()
  end
end

-- Terminal: a panel at the bottom like VSCode's
local toggle_terminal = panel(function()
  vim.cmd("botright split")
  vim.api.nvim_win_set_height(0, math.floor(vim.o.lines * 0.3))
end, vim.cmd.terminal)
vim.keymap.set({ "n", "t" }, "<C-`>", toggle_terminal, { desc = "Toggle terminal" })
vim.keymap.set("n", "<leader>t", toggle_terminal, { desc = "Toggle terminal" })

-- Claude Code: a panel on the right. Closes when Claude exits; a new toggle starts it again.
-- Files it edits are reloaded by the timer in config/autocmds.lua.
local open_claude = panel(function()
  vim.cmd("botright vsplit")
  vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * 0.4))
  vim.cmd("setlocal winfixwidth") -- keep its width when other windows open or close
end, function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  vim.fn.jobstart({ "claude" }, {
    term = true,
    on_exit = function()
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end,
  })
  -- Claude uses <Esc> (interrupt) and <Esc><Esc> (rewind) itself, so leave with <C-h> instead
  -- (or <C-\><C-n> to scroll)
  vim.keymap.set("t", "<Esc>", "<Esc>", { buffer = buf, nowait = true })
  vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { buffer = buf, desc = "Go to left window" })
end)
local function toggle_claude()
  if vim.fn.executable("claude") == 0 then
    vim.notify("claude is not installed", vim.log.levels.WARN)
    return
  end
  open_claude()
end
vim.keymap.set({ "n", "t" }, "<C-.>", toggle_claude, { desc = "Toggle Claude" })
vim.keymap.set("n", "<leader>a", toggle_claude, { desc = "Toggle Claude" })

-- Leave terminal mode with <Esc><Esc> (single <Esc> still goes to the shell/program);
-- nvim's own <C-\><C-n> works too
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
