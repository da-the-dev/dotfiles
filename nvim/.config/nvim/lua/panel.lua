-- Panels: a terminal at the edge of the screen, toggled by a key and kept running while hidden.
-- `split` opens the window and sets its size, `start` starts the program in it.
return function(split, start)
  local M = { buf = nil, win = nil }

  function M.is_open()
    return M.win ~= nil and vim.api.nvim_win_is_valid(M.win) and vim.api.nvim_win_get_buf(M.win) == M.buf
  end

  -- Opens the window (starting the program if needed) and goes to it
  function M.open()
    split()
    if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
      vim.api.nvim_win_set_buf(0, M.buf)
    else
      start()
      M.buf = vim.api.nvim_get_current_buf()
      vim.bo[M.buf].buflisted = false -- keep it out of the tab bar and <S-h>/<S-l>
    end
    M.win = vim.api.nvim_get_current_win()
  end

  function M.toggle()
    if M.is_open() then
      if #vim.api.nvim_tabpage_list_wins(0) == 1 then return end -- it's the only window: keep it
      vim.api.nvim_win_hide(M.win)
      M.win = nil
      return
    end
    M.open()
    vim.cmd.startinsert()
  end

  return M
end
