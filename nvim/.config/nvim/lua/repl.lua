-- Python REPL panel on the right: run code from the file and see the result, in the interpreter
-- picked with <leader>cv. Uses IPython if that interpreter has it, plain python otherwise.
local M = {}

local job, ipython, python
local queue = {} -- code waiting for the REPL to start

local panel = require("panel")(function()
  vim.cmd("botright vsplit")
  vim.api.nvim_win_set_width(0, math.floor(vim.o.columns * 0.4))
  vim.cmd("setlocal winfixwidth") -- keep its width when other windows open or close
end, function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buf)
  local cmd = { python }
  if ipython then
    -- last_expr_or_assign: also print the value of `x = ...`
    vim.list_extend(cmd, { "-m", "IPython", "--no-banner", "--no-autoindent", "--no-confirm-exit" })
    cmd[#cmd + 1] = "--InteractiveShell.ast_node_interactivity=last_expr_or_assign"
  end
  job = vim.fn.jobstart(cmd, {
    term = true,
    cwd = M.root,
    on_exit = function()
      if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end,
  })
  vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { buffer = buf, desc = "Go to left window" })
end)

-- Before starting: take interpreter and project root from the current file
local function prepare()
  if panel.buf and vim.api.nvim_buf_is_valid(panel.buf) then return end
  queue = {}
  python = require("python_env").current()
  M.root = require("python_env").root()
  ipython = vim.system({ python, "-c", "import IPython" }):wait().code == 0
end

local function write(lines)
  if ipython then
    -- as one paste; a block (def, for, ...) needs a second Enter
    local enter = #lines > 1 and lines[#lines]:match("^%s") and "\r\r" or "\r"
    vim.fn.chansend(job, "\27[200~" .. table.concat(lines, "\n") .. "\27[201~" .. enter)
  elseif #lines == 1 then
    vim.fn.chansend(job, lines[1] .. "\r")
  else
    -- plain python: pasted blocks break on blank lines, so run them as one exec("...") line
    local code = vim.json.encode(table.concat(lines, "\n")):gsub("\\/", "/")
    vim.fn.chansend(job, "exec(" .. code .. ")\r")
  end
end

-- Write the queue once the first prompt is there
local function flush(tries)
  if not (panel.buf and vim.api.nvim_buf_is_valid(panel.buf)) then return end
  local text = table.concat(vim.api.nvim_buf_get_lines(panel.buf, 0, -1, false), "\n")
  if text:find("In %[1%]:") or text:find(">>>") then
    for _, lines in ipairs(queue) do write(lines) end
    queue = {}
  elseif tries > 0 then
    vim.defer_fn(function() flush(tries - 1) end, 100)
  else
    queue = {}
    vim.notify("The REPL didn't start in time; code not sent", vim.log.levels.WARN)
  end
end

-- Run lines first..last of the current buffer; the cursor stays in the file
local function send(first, last)
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local indent = math.huge
  for _, l in ipairs(lines) do
    if l:match("%S") then indent = math.min(indent, #l:match("^%s*")) end
  end
  if indent == math.huge then return end
  lines = vim.tbl_map(function(l) return l:sub(indent + 1) end, lines)
  while not lines[#lines]:match("%S") do table.remove(lines) end

  prepare()
  if not panel.is_open() then
    local code_win = vim.api.nvim_get_current_win()
    panel.open()
    vim.api.nvim_set_current_win(code_win)
  end
  -- a terminal window only follows the output while its cursor is on the last line
  vim.api.nvim_win_set_cursor(panel.win, { vim.api.nvim_buf_line_count(panel.buf), 0 })
  queue[#queue + 1] = lines
  if #queue == 1 then flush(100) end
end

local function is_python()
  if vim.bo.filetype == "python" then return true end
  vim.notify("Not a Python file", vim.log.levels.WARN)
end

-- First line from `row` on that has code (not blank or a comment), or nil
local function next_code_line(row)
  for i = row, vim.fn.line("$") do
    local l = vim.fn.getline(i)
    if l:match("%S") and not l:match("^%s*#") then return i end
  end
end

--- Run the whole statement under the cursor and move to the next one
function M.run_statement()
  if not is_python() then return end
  local row = next_code_line(vim.fn.line("."))
  if not row then return end
  local first, last = row, row
  local parser = vim.treesitter.get_parser(0, "python", { error = false })
  if parser then
    parser:parse()
    local node = vim.treesitter.get_node({ pos = { row - 1, #vim.fn.getline(row):match("^%s*") } })
    while node and node:parent() and node:parent():type() ~= "block" and node:parent():type() ~= "module" do
      node = node:parent()
    end
    if node and node:parent() then
      local s, _, e, e_col = node:range()
      first, last = s + 1, e_col == 0 and e or e + 1
    end
  end
  send(first, last)
  vim.api.nvim_win_set_cursor(0, { next_code_line(last + 1) or last, 0 })
  vim.cmd("normal! ^")
end

--- Run the selected lines
function M.run_selection()
  if not is_python() then return end
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  send(math.min(a, b), math.max(a, b))
end

function M.toggle()
  prepare()
  panel.toggle()
end

--- Start over with a fresh REPL
function M.restart()
  local code_win = vim.api.nvim_get_current_win()
  if panel.buf and vim.api.nvim_buf_is_valid(panel.buf) then
    vim.api.nvim_buf_delete(panel.buf, { force = true }) -- also stops the process
  end
  prepare()
  panel.open()
  if vim.api.nvim_win_is_valid(code_win) then vim.api.nvim_set_current_win(code_win) end
end

return M
