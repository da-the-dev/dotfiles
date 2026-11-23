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
