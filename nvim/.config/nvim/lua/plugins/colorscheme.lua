-- VSCode "Dark Modern" = vscode.nvim (Dark+ syntax colors) + Dark Modern UI colors
-- (values from microsoft/vscode extensions/theme-defaults/themes/dark_modern.json)
return {
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
        widget_border = "#454545", -- editorHoverWidget.border (VSCode default; Dark Modern keeps it)
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
}
