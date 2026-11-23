-- Basic config
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.termguicolors = true

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out } }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    "tpope/vim-surround",
    "tpope/vim-repeat",
    {
      "nvim-telescope/telescope.nvim",
      version = "*",
      dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      },
      keys = {
        { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" },
        { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
        { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Buffers" },
        { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Help tags" },
      },
      config = function()
        -- include hidden files and .gitignore, but skip .git
        require("telescope").setup({
          defaults = {
            vimgrep_arguments = {
              "rg", "--color=never", "--no-heading", "--with-filename",
              "--line-number", "--column", "--smart-case",
              "--hidden", "--glob", "!**/.git/*",
            },
          },
          pickers = {
            find_files = {
              find_command = { "rg", "--files", "--hidden", "--glob", "!**/.git/*" },
            },
          },
        })
        require("telescope").load_extension("fzf")
      end,
    },
  },
  install = { colorscheme = { "default" } },
})

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
