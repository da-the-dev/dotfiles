-- Jupyter notebooks: jupytext opens .ipynb as a Python script with `# %%` cell markers,
-- molten runs cells in a Jupyter kernel and shows output below them.
-- Needs: `jupytext` CLI (uv tool install jupytext), nvim's python host (see config/options.lua),
-- and ipykernel in the project's interpreter.

-- Cell = lines between `# %%` markers. Returns first/last line of the cell under the cursor.
local function cell_range()
  local start = vim.fn.search("^# %%", "bcnW") -- marker at/above cursor
  local stop = vim.fn.search("^# %%", "nW") -- next marker below
  local is_markdown = start > 0 and vim.fn.getline(start):find("%[markdown%]") ~= nil
  return start + 1, (stop == 0 and vim.fn.line("$") or stop - 1), stop, is_markdown
end

local function run_cell(move_next)
  local first, last, next_marker, is_markdown = cell_range()
  if not is_markdown and first <= last then
    vim.fn.MoltenEvaluateRange(first, last)
  end
  if move_next and next_marker > 0 then
    vim.api.nvim_win_set_cursor(0, { math.min(next_marker + 1, vim.fn.line("$")), 0 })
  end
end

-- Start a kernel for the interpreter picked with <leader>cv (like VSCode's kernel = interpreter).
-- Writes a kernelspec pointing at that python into nvim's own data dir, not ~/Library/Jupyter.
local function start_kernel()
  local ok, running = pcall(vim.fn.MoltenRunningKernels, true)
  if ok and #running > 0 then
    vim.notify("Kernel already running for this buffer: " .. table.concat(running, ", ") .. "\nStop it with <leader>jk")
    return
  end
  local python = require("python_env").current()
  if vim.system({ python, "-c", "import ipykernel" }):wait().code ~= 0 then
    vim.notify(
      ("ipykernel isn't installed for %s\nInstall it with:\n  uv pip install --python %s ipykernel"):format(python, python),
      vim.log.levels.WARN
    )
    return
  end
  local name = "nvim-" .. vim.fn.sha256(python):sub(1, 8)
  local dir = vim.env.JUPYTER_PATH .. "/kernels/" .. name
  vim.fn.mkdir(dir, "p")
  vim.fn.writefile({
    vim.json.encode({
      argv = { python, "-m", "ipykernel_launcher", "-f", "{connection_file}" },
      display_name = "Python (" .. vim.fn.fnamemodify(python, ":~") .. ")",
      language = "python",
    }),
  }, dir .. "/kernel.json")
  vim.cmd("MoltenInit " .. name)
end

-- image.nvim can't draw inside tmux unless tmux passes graphics through (allow-passthrough on);
-- there it's disabled instead of erroring on every start, and <leader>jp still works
local images_supported = not vim.env.TMUX
  or vim.trim(vim.fn.system({ "tmux", "show", "-gv", "allow-passthrough" })) ~= "off"

return {
  -- Images in the terminal via Ghostty's (kitty) graphics protocol: molten plots, and
  -- images in markdown files. Needs ImageMagick (brew install imagemagick).
  {
    "3rd/image.nvim",
    version = "*",
    cond = images_supported,
    opts = {
      backend = "kitty",
      processor = "magick_cli", -- uses the `magick` command, no lua rock needed
      max_width = 100, -- in cells; molten recommends capping these, huge images can crash the terminal
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true, -- hide images under popups (completion, hover)
      window_overlap_clear_ft_ignore = { "blink-cmp-menu", "blink-cmp-documentation", "" },
    },
  },

  {
    "GCBallesteros/jupytext.nvim",
    lazy = false, -- must be set up before a .ipynb is opened
    -- "percent" = `# %%` cells, `# %% [markdown]` for markdown; same format VSCode understands
    opts = { style = "percent" },
  },

  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    lazy = false,
    build = ":UpdateRemotePlugins", -- registers molten's commands with nvim's python host
    init = function()
      vim.env.JUPYTER_PATH = vim.fn.stdpath("data") .. "/jupyter" -- where start_kernel() writes kernelspecs
      vim.g.molten_auto_open_output = false -- don't pop up a float when the cursor enters a cell
      vim.g.molten_virt_text_output = true -- show output below the cell, like VSCode
      vim.g.molten_wrap_output = true
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_image_provider = images_supported and "image.nvim" or "none" -- plots inline under the cell
    end,
    dependencies = { "3rd/image.nvim" },
    keys = {
      { "<leader>ji", start_kernel, desc = "Start kernel (current interpreter)" },
      { "<leader>jI", "<cmd>MoltenInit<cr>", desc = "Start kernel (pick / connect)" },
      { "<leader>jj", function() run_cell(true) end, desc = "Run cell and go to next" },
      { "<leader>jc", function() run_cell(false) end, desc = "Run cell" },
      { "<leader>jl", "<cmd>MoltenEvaluateLine<cr>", desc = "Run line" },
      { "<leader>j", ":<C-u>MoltenEvaluateVisual<cr>gv<Esc>", mode = "x", desc = "Run selection" },
      { "<leader>jo", "<cmd>noautocmd MoltenEnterOutput<cr>", desc = "Open output window" },
      { "<leader>jh", "<cmd>MoltenHideOutput<cr>", desc = "Hide output" },
      { "<leader>jd", "<cmd>MoltenDelete<cr>", desc = "Clear cell output" },
      { "<leader>jx", "<cmd>MoltenInterrupt<cr>", desc = "Interrupt kernel" },
      { "<leader>jR", "<cmd>MoltenRestart!<cr>", desc = "Restart kernel" },
      { "<leader>jk", "<cmd>MoltenDeinit<cr>", desc = "Stop kernel" },
      { "<leader>jp", "<cmd>MoltenImagePopup<cr>", desc = "Open plot in Preview" },
      { "]j", function() vim.fn.search("^# %%", "W") end, desc = "Next cell" },
      { "[j", function() vim.fn.search("^# %%", "bW") end, desc = "Previous cell" },
    },
  },
}
