-- Autocommands that don't belong to a plugin

-- Autosave: write a file 500ms after the last change, also while typing (like VSCode's
-- "files.autoSave": "afterDelay"). Only real files; notebooks wait until you leave insert
-- mode, since saving one converts it back to .ipynb.
local timers = {}
local group = vim.api.nvim_create_augroup("autosave", { clear = true })

local function save(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modified then return end
  if vim.api.nvim_buf_get_name(buf):match("%.ipynb$") and vim.fn.mode():match("^i") then return end
  vim.api.nvim_buf_call(buf, function() vim.cmd("silent! lockmarks update") end)
end

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
  group = group,
  callback = function(args)
    local buf = args.buf
    local bo = vim.bo[buf]
    if bo.buftype ~= "" or not bo.modifiable or bo.readonly or vim.api.nvim_buf_get_name(buf) == "" then return end
    timers[buf] = timers[buf] or vim.uv.new_timer()
    timers[buf]:stop()
    timers[buf]:start(500, 0, vim.schedule_wrap(function() save(buf) end))
  end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(args)
    if timers[args.buf] then
      timers[args.buf]:close()
      timers[args.buf] = nil
    end
  end,
})
