-- Finding files/text (telescope), the file explorer sidebar (neo-tree), buffer tabs (bufferline)
return {
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
      { "<leader>fk", function() require("telescope.builtin").keymaps() end, desc = "Keymaps (search by key or description)" },
      {
        "<leader>cc",
        function() require("telescope.builtin").find_files({ cwd = vim.fn.stdpath("config"), prompt_title = "Config files" }) end,
        desc = "Config files",
      },
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

  -- Open buffers shown as tabs across the top, like VSCode's tab bar
  {
    "akinsho/bufferline.nvim",
    version = "*",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      -- in tab-bar order, which :bprevious/:bnext don't follow once tabs are reordered
      -- (replaces H/L = top/bottom of screen)
      { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous buffer" },
      { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
      -- move the tab; takes a count (3<leader>bl). One step at a time: bufferline's own
      -- move by n swaps the two tabs instead of shifting the ones in between.
      { "<leader>bh", function() for _ = 1, vim.v.count1 do require("bufferline").move(-1) end end, desc = "Move tab left" },
      { "<leader>bl", function() for _ = 1, vim.v.count1 do require("bufferline").move(1) end end, desc = "Move tab right" },
      { "<leader>bp", "<cmd>BufferLinePick<cr>", desc = "Pick buffer by letter" },
      { "<leader>bx", "<cmd>BufferLinePickClose<cr>", desc = "Pick buffer to close" },
      { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "Close other buffers" },
      { "<leader>bH", "<cmd>BufferLineCloseLeft<cr>", desc = "Close buffers to the left" },
      { "<leader>bL", "<cmd>BufferLineCloseRight<cr>", desc = "Close buffers to the right" },
    },
    opts = {
      options = {
        -- closing tabs (mouse, <leader>bo/bH/bL/bx): close like <leader>bd (default is bdelete!, which discards changes)
        close_command = function(n) require("mini.bufremove").delete(n, false) end,
        right_mouse_command = function(n) require("mini.bufremove").delete(n, false) end,
        -- start the tab bar to the right of neo-tree, like VSCode
        offsets = { { filetype = "neo-tree", text = "Explorer", text_align = "left", separator = true } },
      },
    },
  },

  -- Close a buffer but keep the window layout (like closing a tab in VSCode);
  -- asks to save if there are unsaved changes
  {
    "nvim-mini/mini.bufremove",
    version = "*",
    keys = {
      { "<leader>bd", function() require("mini.bufremove").delete(0, false) end, desc = "Close buffer" },
    },
  },
}
