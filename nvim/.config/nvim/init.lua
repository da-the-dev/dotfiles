-- Basic config
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.termguicolors = true
vim.opt.undofile = true -- persist undo history (stored in stdpath("state")/undo)
-- vim.diagnostic.config({ virtual_text = false }) -- toggle to show diagnostic messages at end of line

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
    -- Colorscheme: VSCode "Dark Modern" = vscode.nvim (Dark+ syntax) + Dark Modern UI colors
    -- (values from microsoft/vscode extensions/theme-defaults/themes/dark_modern.json)
    {
      "Mofiqul/vscode.nvim",
      lazy = false,
      priority = 1000, -- load before other plugins so they pick up its highlights
      config = function()
        local dm = {
          editor = "#1F1F1F",        -- editor.background
          chrome = "#181818",        -- sideBar / statusBar / tab bar background
          border = "#2B2B2B",        -- sideBar.border, statusBar.border
          fg = "#CCCCCC",            -- editor.foreground
          muted = "#9D9D9D",         -- descriptionForeground
          linenr = "#6E7681",        -- editorLineNumber.foreground
          widget = "#202020",        -- editorWidget.background
          widget_border = "#313131", -- widget.border
        }
        require("vscode").setup({
          style = "dark",
          color_overrides = {
            vscBack = dm.editor,
            vscFront = dm.fg,
            vscLineNumber = dm.linenr,
            vscPopupBack = dm.widget,
            vscPopupFront = dm.fg,
          },
          group_overrides = {
            StatusLine = { fg = dm.fg, bg = dm.chrome },
            StatusLineNC = { fg = dm.muted, bg = dm.chrome },
            WinSeparator = { fg = dm.border, bg = "NONE" },
            TabLine = { fg = dm.muted, bg = dm.chrome },
            TabLineFill = { bg = dm.chrome },
            TabLineSel = { fg = dm.fg, bg = dm.editor },
            FloatBorder = { fg = dm.widget_border, bg = dm.widget },
            NeoTreeNormal = { fg = dm.fg, bg = dm.chrome },
            NeoTreeNormalNC = { fg = dm.fg, bg = dm.chrome },
            NeoTreeEndOfBuffer = { fg = dm.chrome, bg = dm.chrome },
            NeoTreeWinSeparator = { fg = dm.border, bg = dm.chrome },
          },
        })
        vim.cmd.colorscheme("vscode")
      end,
    },

    "tpope/vim-surround",
    "tpope/vim-repeat",
    {
      "nvim-telescope/telescope.nvim",
      version = "*",
      dependencies = {
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        "nvim-telescope/telescope-ui-select.nvim",
      },
      init = function()
        -- first vim.ui.select call (code actions, interpreter picker, ...) loads telescope,
        -- whose ui-select extension then replaces vim.ui.select with a telescope popup
        vim.ui.select = function(...)
          require("telescope")
          return vim.ui.select(...)
        end
      end,
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
          extensions = {
            ["ui-select"] = { require("telescope.themes").get_dropdown() },
          },
        })
        require("telescope").load_extension("fzf")
        require("telescope").load_extension("ui-select")
      end,
    },
    {
      "nvim-neo-tree/neo-tree.nvim",
      branch = "v3.x",
      lazy = false, -- neo-tree lazy-loads itself; needed for `nvim <dir>` to open the tree
      dependencies = {
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
        "nvim-tree/nvim-web-devicons",
      },
      keys = {
        { "<leader>e", "<cmd>Neotree toggle reveal<cr>", desc = "File explorer" },
      },
      opts = {
        -- show dotfiles (e.g. .config/) but hide .git; .gitignore'd files stay hidden
        filesystem = {
          filtered_items = {
            hide_dotfiles = false,
            hide_by_name = { ".git" },
          },
        },
      },
    },

    -- Treesitter: parsers + highlighting (needs `tree-sitter` CLI from brew)
    {
      "nvim-treesitter/nvim-treesitter",
      branch = "main",
      lazy = false,
      build = ":TSUpdate",
      config = function()
        require("nvim-treesitter").install({
          "python", "c", "cpp", "lua",
          "markdown", "markdown_inline", "vim", "vimdoc", "query",
        })
        -- use treesitter highlighting for any filetype that has a parser
        vim.api.nvim_create_autocmd("FileType", {
          callback = function(args)
            pcall(vim.treesitter.start, args.buf)
          end,
        })
      end,
    },

    -- LSP: server configs come from nvim-lspconfig, servers are installed via brew
    {
      "neovim/nvim-lspconfig",
      config = function()
        -- point basedpyright at the project's interpreter (see lua/python_env.lua)
        vim.lsp.config("basedpyright", {
          -- "off" = Pylance's default: only unresolved imports, undefined names, syntax errors.
          -- A project's [tool.basedpyright] in pyproject.toml still overrides this.
          settings = { basedpyright = { analysis = { typeCheckingMode = "off" } } },
          before_init = function(_, config)
            local python = config.root_dir and require("python_env").resolve(config.root_dir)
            if python then
              config.settings.python = vim.tbl_extend("force", config.settings.python or {}, { pythonPath = python })
              require("python_env").activate(python)
            end
          end,
        })
        vim.lsp.enable({ "basedpyright", "ruff", "clangd", "lua_ls" })
      end,
    },
    -- Teaches lua_ls about the nvim API (vim.*) when editing nvim config
    {
      "folke/lazydev.nvim",
      ft = "lua",
      opts = {
        library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } },
      },
    },

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
      keys = {
        { "<leader>qs", function() require("persistence").load() end, desc = "Restore session (this dir)" },
        { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
        { "<leader>qS", function() require("persistence").select() end, desc = "Select session" },
        { "<leader>qd", function() require("persistence").stop() end, desc = "Don't save session on quit" },
      },
    },

    -- Completion menu
    {
      "saghen/blink.cmp",
      version = "1.*", -- release tags ship a prebuilt fuzzy matcher
      opts = {
        -- "default" preset: <C-y> accept, <C-n>/<C-p> select, <C-space> open, <C-e> close
        keymap = { preset = "default" },
        completion = { documentation = { auto_show = true } },
        sources = {
          default = { "lazydev", "lsp", "path", "snippets", "buffer" },
          providers = {
            lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
          },
        },
      },
    },
  },
  install = { colorscheme = { "vscode", "default" } },
  -- lazy's partial reload of plugin specs is unreliable; use ZR to apply config changes
  change_detection = { enabled = false },
})

-- Before persistence saves a session: close neo-tree and terminals (e.g. lazygit),
-- which a session would otherwise restore as empty windows / respawned processes
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

-- Restart nvim, keeping the session. Loads it explicitly because :restart reuses the
-- original command line, so `nvim file.py` would come back as just file.py.
-- neo-tree is reopened if it was open.
vim.keymap.set("n", "ZR", function()
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
end, { desc = "Restart nvim (keep session)" })

-- Python interpreter picker (like VSCode's "Python: Select Interpreter")
vim.keymap.set("n", "<leader>cv", function() require("python_env").pick() end, { desc = "Select Python interpreter" })
vim.api.nvim_create_user_command("PythonInterpreter", function() require("python_env").pick() end, {})

-- Statusline: nvim's default, plus the Python interpreter on the right (in Python buffers)
local default_statusline = vim.api.nvim_get_option_info2("statusline", {}).default
vim.o.statusline = default_statusline:gsub("%%=", "%%=%%{v:lua.require'python_env'.status()}", 1)

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

