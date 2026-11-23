-- Editing helpers, keybinding hints, sessions
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
        { "<leader>g", group = "git" },
        { "<leader>c", group = "code" },
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
      -- Before saving: close neo-tree and terminals (e.g. lazygit), which a session
      -- would otherwise restore as empty windows / respawned processes
      vim.api.nvim_create_autocmd("User", {
        pattern = "PersistenceSavePre",
        callback = function()
          for _, w in ipairs(vim.api.nvim_list_wins()) do
            if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree" then
              pcall(vim.api.nvim_win_close, w, true)
            end
          end
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            if vim.bo[b].buftype == "terminal" then
              pcall(vim.api.nvim_buf_delete, b, { force = true })
            end
          end
        end,
      })

      -- Auto-restore the directory's session when started as plain `nvim` (no files, no stdin)
      vim.api.nvim_create_autocmd("StdinReadPre", { callback = function() vim.g.started_with_stdin = true end })
      vim.api.nvim_create_autocmd("VimEnter", {
        nested = true, -- let the restored buffers fire their own autocmds (filetype, LSP, ...)
        callback = function()
          if vim.fn.argc(-1) == 0 and not vim.g.started_with_stdin then
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
      -- Restart nvim, keeping the session. Loads it explicitly because :restart reuses the
      -- original command line, so `nvim file.py` would come back as just file.py.
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
          require("persistence").save()
          vim.cmd("restart lua require('persistence').load()" .. (tree_open and " vim.cmd('Neotree show')" or ""))
        end,
        desc = "Restart nvim (keep session)",
      },
    },
  },
}
