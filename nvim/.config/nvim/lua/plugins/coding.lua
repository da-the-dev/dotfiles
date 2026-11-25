-- Syntax highlighting, language servers, completion
return {
  -- Treesitter: parsers + highlighting (needs `tree-sitter` CLI from brew)
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- parsers to install (async on startup; install.sh builds them up front for offline use)
      local parsers = {
        "python", "c", "cpp", "lua", "bash",
        "markdown", "markdown_inline", "vim", "vimdoc", "query",
      }
      -- math in markdown; the only parser here that can't be built without the CLI
      if vim.fn.executable("tree-sitter") == 1 then
        table.insert(parsers, "latex")
      end
      vim.g.treesitter_parsers = parsers
      require("nvim-treesitter").install(parsers)
      -- use treesitter highlighting for any filetype that has a parser
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- Render markdown in the buffer (headings, code blocks, tables, checkboxes, math); the cursor
  -- line and insert mode show raw text. `:RenderMarkdown toggle` to switch off.
  -- Math needs utftex (install.sh builds it) and perl.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    branch = "main", -- for latex.position = "replace"; back to version = "*" once it's in a release (after v8.14.0)
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      latex = {
        enabled = vim.fn.executable("utftex") == 1,
        -- math2text: utftex with its gaps filled. cat: what it still can't draw stays as source (not
        -- the default latex2text, which draws \dfrac{a}{b} as "ab").
        converter = { vim.fn.stdpath("config") .. "/bin/math2text", "cat" },
        position = "replace", -- $$ blocks: instead of the source, not above it
      },
    },
  },

  -- LSP: server configs come from nvim-lspconfig, servers are installed via brew
  -- (basedpyright, ruff, lua-language-server; clangd comes with Xcode)
  {
    "neovim/nvim-lspconfig",
    config = function()
      vim.lsp.config("basedpyright", {
        -- Like Pylance's default: no type checking, only undefined names, unresolved imports and
        -- syntax errors. "off" alone disables the first two as well, and with them the
        -- "add import" code action (gra), which is a fix for an undefined name.
        -- A project's [tool.basedpyright] in pyproject.toml still overrides this.
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "off",
              diagnosticSeverityOverrides = {
                reportUndefinedVariable = "warning",
                reportMissingImports = "warning",
                reportMissingModuleSource = "warning",
              },
            },
          },
        },
        -- point basedpyright at the project's interpreter (see lua/python_env.lua)
        before_init = function(_, config)
          local python = config.root_dir and require("python_env").resolve(config.root_dir)
          if python then
            config.settings.python = vim.tbl_extend("force", config.settings.python or {}, { pythonPath = python })
            require("python_env").activate(python)
          end
        end,
      })
      vim.lsp.enable({ "basedpyright", "ruff", "clangd", "lua_ls", "bashls" })

      -- gd: go to definition, like <C-]> (stock gd is a text search for a local declaration,
      -- and stays that way in buffers without a language server)
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client:supports_method("textDocument/definition") then
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = args.buf, desc = "Go to definition" })
          end
        end,
      })
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

  -- LaTeX snippets in markdown math (see lua/latex_snippets.lua). Only there: blink.cmp keeps using
  -- nvim's own snippets for completion.
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    ft = "markdown",
    config = function()
      require("luasnip").setup({
        enable_autosnippets = true,
        update_events = { "TextChanged", "TextChangedI" }, -- repeated fields follow while typing
        region_check_events = "InsertEnter", -- moving away ends a snippet
        delete_check_events = "TextChanged",
      })
      require("latex_snippets").setup()
    end,
  },

  -- Completion menu
  {
    "saghen/blink.cmp",
    version = "1.*", -- release tags ship a prebuilt fuzzy matcher
    opts = {
      -- "super-tab" preset (like VSCode): <Tab> accepts (or jumps to the next snippet field),
      -- <C-n>/<C-p> or arrows select, <C-space> open, <C-e> close; <C-y> kept as an accept key too.
      -- <CR> accepts as well (VSCode's acceptSuggestionOnEnter): <C-e> first for a new line.
      keymap = {
        preset = "super-tab",
        ["<C-y>"] = { "select_and_accept", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        -- <Tab> in markdown math goes to LaTeX snippets first; the rest is super-tab's own <Tab>
        ["<Tab>"] = {
          function() return require("latex_snippets").tab(1) end,
          function(cmp)
            if cmp.snippet_active() then return cmp.accept() end
            return cmp.select_and_accept()
          end,
          "snippet_forward", "fallback",
        },
        ["<S-Tab>"] = {
          function() return require("latex_snippets").tab(-1) end,
          "snippet_backward", "fallback",
        },
      },
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
