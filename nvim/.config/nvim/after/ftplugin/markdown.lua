-- Markdown-only settings (runs for every markdown buffer)

-- <leader>x: toggle checkboxes `- [ ]` <-> `- [x]` on the current line, or every selected line
local function toggle_checkboxes(first, last)
  if first > last then first, last = last, first end
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  for i, line in ipairs(lines) do
    -- list marker (-, *, +, 1., 1)) followed by [ ] / [x]
    local prefix, mark, rest = line:match("^(%s*[-*+] %[)(.)(%].*)$")
    if not prefix then prefix, mark, rest = line:match("^(%s*%d+[.)] %[)(.)(%].*)$") end
    if prefix then
      lines[i] = prefix .. (mark == " " and "x" or " ") .. rest
    end
  end
  vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)
end

vim.keymap.set("n", "<leader>x", function()
  local l = vim.fn.line(".")
  toggle_checkboxes(l, l)
end, { buffer = true, desc = "Toggle checkbox" })

vim.keymap.set("x", "<leader>x", function()
  toggle_checkboxes(vim.fn.line("v"), vim.fn.line("."))
end, { buffer = true, desc = "Toggle checkboxes" })
