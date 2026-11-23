-- Russian keyboard layout support.
--
-- Decision (2026-11): A + C below. Revisit if it gets in the way.
--   Problem: with the Russian layout active, nvim gets Cyrillic letters, so commands and
--   keymaps don't work.
--   A. Auto-switch layout (this file): leaving insert mode switches macOS to English (ABC),
--      entering insert mode restores what you were typing in. Every keymap works, no
--      translation. Needs `macism` (brew tap laishulu/homebrew; brew install macism), macOS only.
--   C. 'langmap' (config/options.lua): Cyrillic letters act as the Latin key in normal/visual
--      mode (вв = dd, Ж = :). Covers built-in commands only: in multi-key keymaps
--      (<leader>ff, ]j, ...) only the first key is translated, so those still need English.
--      Fallback for SSH sessions / servers, where A can't run.
--   Not chosen: B. langmapper.nvim — creates a Cyrillic copy of every keymap (incl. which-key
--      and plugins), works everywhere without external tools, but patches how nvim registers
--      keymaps. Switch to it if A is unavailable or annoying (e.g. working mostly over SSH).
return {
  {
    "keaising/im-select.nvim",
    cond = vim.fn.has("mac") == 1 and vim.fn.executable("macism") == 1,
    event = "VeryLazy",
    opts = {
      default_command = "macism",
      default_im_select = "com.apple.keylayout.ABC", -- layout for normal mode / commands
      set_default_events = { "VimEnter", "FocusGained", "InsertLeave", "CmdlineLeave" },
      set_previous_events = { "InsertEnter" }, -- back to the layout you last typed in
    },
  },
}
