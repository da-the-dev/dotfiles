-- Syntax highlighting, language servers, completion
return {
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

  -- Render markdown in the buffer (headings, code blocks, tables, checkboxes); the cursor
  -- line and insert mode show raw text. `:RenderMarkdown toggle` to switch off.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    version = "*",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {},
  },

  -- LSP: server configs come from nvim-lspconfig, servers are installed via brew
  -- (basedpyright, ruff, lua-language-server; clangd comes with Xcode)
  {
    "neovim/nvim-lspconfig",
    config = function()
      vim.lsp.config("basedpyright", {
        -- "off" = Pylance's default: only unresolved imports, undefined names, syntax errors.
        -- A project's [tool.basedpyright] in pyproject.toml still overrides this.
        settings = { basedpyright = { analysis = { typeCheckingMode = "off" } } },
        -- point basedpyright at the project's interpreter (see lua/python_env.lua)
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
}
