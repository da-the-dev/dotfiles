-- Editing helpers, keybinding hints, sessions

-- Before a session is saved: remove neo-tree and terminal (e.g. lazygit) buffers, which a
-- session would restore as broken placeholders / respawned processes. Deleting the buffer
-- (not just closing its window) also works when it's the last window.
-- Also clear the argument list (`nvim a.py b.py`): it's saved too, and would bring back files
-- closed since.
local function clean_up_for_session()
  vim.cmd("silent! %argdelete")
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].filetype == "neo-tree" or vim.bo[b].buftype == "terminal" then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
end

return {
  -- ys/cs/ds to add/change/delete surroundings; vim-repeat makes `.` repeat them
  "tpope/vim-surround",
  "tpope/vim-repeat",

  -- Popup listing available keybindings after you press a prefix (e.g. <leader>, g, z)
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>b", group = "buffer" },
        { "<leader>g", group = "git" },
        { "<leader>j", group = "jupyter" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>q", group = "session" },
      },
    },
  },

  -- Sessions: saved per project directory on quit, restored by `nvim` with no file args
  {
    "folke/persistence.nvim",
    lazy = false, -- must be loaded at startup for auto-restore
    opts = {},
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistenceSavePre",
        callback = function()
          clean_up_for_session()

          -- Drop files outside the project dir (e.g. a quick ~/.zshrc edit) from the session
          local cwd = vim.fn.resolve(vim.fn.getcwd())
          local dropped, kept = false, false
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            local name = vim.api.nvim_buf_get_name(b)
            if vim.bo[b].buflisted and vim.bo[b].buftype == "" and name ~= "" then
              if vim.fs.relpath(cwd, vim.fn.resolve(name)) then
                kept = true
              else
                pcall(vim.api.nvim_buf_delete, b, {}) -- not forced: never discards unsaved changes
                dropped = true
              end
            end
          end
          -- Only outside files were open: persistence skips saving an empty session,
          -- so remove the old one instead of letting it come back
          if dropped and not kept then
            os.remove(require("persistence").current())
          end
        end,
      })

      -- Auto-restore the directory's session when started as plain `nvim` (no files, no stdin, not headless)
      vim.api.nvim_create_autocmd("StdinReadPre", { callback = function() vim.g.started_with_stdin = true end })
      vim.api.nvim_create_autocmd("VimEnter", {
        nested = true, -- let the restored buffers fire their own autocmds (filetype, LSP, ...)
        callback = function()
          if vim.fn.argc(-1) == 0 and not vim.g.started_with_stdin and #vim.api.nvim_list_uis() > 0 then
            require("persistence").load()
          end
        end,
      })
    end,
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session (this dir)" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qS", function() require("persistence").select() end, desc = "Select session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't save session on quit" },
      {
        "<leader>qD",
        function()
          local p = require("persistence")
          local file = p.current()
          p.stop() -- otherwise quitting would save it again
          if os.remove(file) then
            vim.notify("Deleted session " .. vim.fn.fnamemodify(file, ":t"))
          else
            vim.notify("No saved session for this directory")
          end
        end,
        desc = "Delete this dir's session",
      },
      -- Restart nvim, keeping the session. Loads it explicitly because :restart reuses the
      -- original command line, so `nvim file.py` would come back as just file.py; buffers from
      -- that command line are dropped first, as they may have been closed since.
      -- neo-tree is reopened if it was open.
      {
        "ZR",
        function()
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.bo[b].modified then
              vim.notify("Restart skipped: unsaved changes in " .. vim.api.nvim_buf_get_name(b), vim.log.levels.WARN)
              return
            end
          end
          local tree_open = vim.iter(vim.api.nvim_list_wins()):any(function(w)
            return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree"
          end)
          clean_up_for_session() -- save() doesn't run the PersistenceSavePre cleanup
          require("persistence").save()
          vim.cmd("restart lua vim.cmd('silent! %bwipeout') require('persistence').load()" .. (tree_open and " vim.cmd('Neotree show')" or ""))
        end,
        desc = "Restart nvim (keep session)",
      },
    },
  },
}
