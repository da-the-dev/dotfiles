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

-- Is there unsaved work that `action` would lose? If so, say where.
local function unsaved(action)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[b].modified then
      vim.notify(action .. " skipped: unsaved changes in " .. vim.api.nvim_buf_get_name(b), vim.log.levels.WARN)
      return true
    end
  end
  return false
end

-- Leave this directory's session for another one, as if quitting: save it (unless saving is
-- off), then close everything in it. Returns false if unsaved changes are in the way.
local function leave_session()
  if unsaved("Switch") then return false end
  local p = require("persistence")
  clean_up_for_session()
  if p.active() then
    p.fire("SavePre")
    -- like quitting, don't save a session without files
    if vim.iter(vim.api.nvim_list_bufs()):any(function(b)
      return vim.bo[b].buflisted and vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) ~= ""
    end) then
      p.save()
    end
  end
  vim.cmd("silent! tabonly | silent! only | silent! %bwipeout")
  return true
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
        { "<leader>r", group = "repl" },
        { "<leader>q", group = "session" },
      },
    },
  },

  -- Sessions: saved per project directory on quit, restored by `nvim` with no file args.
  -- `nvim file` neither restores nor saves, so a quick edit doesn't replace the session;
  -- loading a session by key turns saving on.
  {
    "folke/persistence.nvim",
    lazy = false, -- must be loaded at startup for auto-restore
    opts = {},
    init = function()
      -- also save global variables (capitalized ones): bufferline keeps the tab order in one
      vim.opt.sessionoptions:append("globals")

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
          elseif vim.fn.isdirectory(vim.fn.argv(0)) == 0 then -- `nvim .` still saves
            require("persistence").stop()
          end
        end,
      })
    end,
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").load()
          require("persistence").start()
        end,
        desc = "Restore session (this dir)",
      },
      {
        "<leader>ql",
        function()
          local p = require("persistence")
          local file = p.last() -- before leaving, which makes this directory's session the last one
          if not file or (file ~= p.current() and not leave_session()) then return end
          vim.cmd("silent! source " .. vim.fn.fnameescape(file))
          p.start()
        end,
        desc = "Restore last session",
      },
      {
        "<leader>qS",
        function()
          local select = vim.ui.select
          -- persistence goes straight from the choice to loading it; leave this session in between
          vim.ui.select = function(items, opts, on_choice)
            vim.ui.select = select
            select(items, opts, function(item)
              if not item then return end
              if vim.fn.isdirectory(item.dir) == 0 then
                vim.notify("No such directory: " .. item.dir, vim.log.levels.WARN)
              elseif leave_session() then
                on_choice(item)
                require("persistence").start()
              end
            end)
          end
          require("persistence").select()
        end,
        desc = "Select session",
      },
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
      -- The file explorer is reopened if it was open. With saving off (`nvim file`, <leader>qd),
      -- the files go through a file of their own, not the directory's session.
      {
        "ZR",
        function()
          if unsaved("Restart") then return end
          local tree_open = vim.iter(vim.api.nvim_list_wins()):any(function(w)
            return vim.b[vim.api.nvim_win_get_buf(w)].neo_tree_source == "filesystem"
          end)
          clean_up_for_session() -- save() doesn't run the PersistenceSavePre cleanup
          local restore = "require('persistence').load() require('persistence').start()"
          if require("persistence").active() then
            require("persistence").save()
          else
            vim.cmd("mksession! " .. vim.fn.fnameescape(vim.fn.stdpath("state") .. "/restart.vim"))
            restore = "vim.cmd.source(vim.fn.stdpath('state') .. '/restart.vim') require('persistence').stop()"
          end
          vim.cmd("restart lua vim.cmd('silent! %bwipeout') " .. restore .. (tree_open and " vim.cmd('Neotree show')" or ""))
        end,
        desc = "Restart nvim (keep session)",
      },
    },
  },
}
