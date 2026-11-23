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

-- Buffers: <S-h>/<S-l> for previous/next (replaces H/L = top/bottom of screen)
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- Terminal: a panel at the bottom like VSCode's. One shell, kept running while hidden.
local term = { buf = nil, win = nil }
local function toggle_terminal()
  if term.win and vim.api.nvim_win_is_valid(term.win) then
    if #vim.api.nvim_tabpage_list_wins(0) == 1 then return end -- it's the only window: keep it
    vim.api.nvim_win_hide(term.win)
    term.win = nil
    return
  end
  vim.cmd("botright split")
  vim.api.nvim_win_set_height(0, math.floor(vim.o.lines * 0.3))
  if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
    vim.api.nvim_win_set_buf(0, term.buf)
  else
    vim.cmd.terminal()
    term.buf = vim.api.nvim_get_current_buf()
    vim.bo[term.buf].buflisted = false -- keep it out of the tab bar and <S-h>/<S-l>
  end
  term.win = vim.api.nvim_get_current_win()
  vim.cmd.startinsert()
end
vim.keymap.set({ "n", "t" }, "<C-`>", toggle_terminal, { desc = "Toggle terminal" })
vim.keymap.set("n", "<leader>t", toggle_terminal, { desc = "Toggle terminal" })

-- Leave terminal mode with <Esc><Esc> (single <Esc> still goes to the shell/program);
-- nvim's own <C-\><C-n> works too
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
