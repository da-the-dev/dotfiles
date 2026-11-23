vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.termguicolors = true
vim.opt.undofile = true -- persist undo history (stored in stdpath("state")/undo)
vim.o.winborder = "rounded" -- border around floating windows (diagnostics, hover docs, ...)
-- vim.diagnostic.config({ virtual_text = false }) -- toggle to show diagnostic messages at end of line

-- Python for nvim's own Python plugins (molten), separate from project interpreters. Create with:
--   uv venv --python 3.13 ~/.local/share/nvim/python-host
--   uv pip install --python ~/.local/share/nvim/python-host/bin/python pynvim jupyter_client requests websocket-client
local python_host = vim.fn.stdpath("data") .. "/python-host/bin/python"
if vim.uv.fs_stat(python_host) then
  vim.g.python3_host_prog = python_host
end

-- Statusline: nvim's default, plus the Python interpreter on the right (in Python buffers)
local default_statusline = vim.api.nvim_get_option_info2("statusline", {}).default
vim.o.statusline = default_statusline:gsub("%%=", "%%=%%{v:lua.require'python_env'.status()}", 1)
