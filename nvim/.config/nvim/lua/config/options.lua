vim.g.mapleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.termguicolors = true
vim.opt.undofile = true -- persist undo history (stored in stdpath("state")/undo)
vim.o.winborder = "rounded" -- border around floating windows (diagnostics, hover docs, ...)
-- Russian keyboard layout: in normal/visual mode, Cyrillic letters act as the Latin letter on
-- the same key (вв = dd, Ж = :). Built-in commands only; see lua/plugins/keyboard.lua for the
-- full decision (auto-switching the layout covers the rest).
local ru = [[ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁйцукенгшщзхъфывапролджэячсмитьбюё]]
local en = [[QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>~qwertyuiop[]asdfghjkl;'zxcvbnm,.`]]
local function escape(str) return (str:gsub("[;,\\]", "\\%0")) end -- ; , \ are special in langmap
vim.opt.langmap = escape(ru) .. ";" .. escape(en)

-- vim.diagnostic.config({ virtual_text = false }) -- toggle to show diagnostic messages at end of line

-- Python for nvim's own Python plugins (molten, debugpy), separate from project interpreters. Create with:
--   uv venv --python 3.13 ~/.local/share/nvim/python-host
--   uv pip install --python ~/.local/share/nvim/python-host/bin/python pynvim jupyter_client requests websocket-client debugpy
local python_host = vim.fn.stdpath("data") .. "/python-host/bin/python"
if vim.uv.fs_stat(python_host) then
  vim.g.python3_host_prog = python_host
end

-- Statusline: nvim's default, plus the Python interpreter on the right (in Python buffers)
local default_statusline = vim.api.nvim_get_option_info2("statusline", {}).default
vim.o.statusline = default_statusline:gsub("%%=", "%%=%%{v:lua.require'python_env'.status()}", 1)
