# dotfiles

Personal configs, linked into `~/.config` with GNU Stow. `./install.sh` sets up a machine.
Keys: [nvim cheatsheet](nvim/.config/nvim/CHEATSHEET.md).

# Maintenance

## Add a language to nvim

Two independent parts, both in `nvim/.config/nvim/lua/plugins/coding.lua`:

| Part | Gives |
|---|---|
| treesitter parser | highlighting |
| language server | `<C-]>`/`gd`, `grr`, `K`, completion, diagnostics, `<leader>fs`/`<leader>fS`, `<leader>cf` |

Example: bash.

1. **Parser:** add it to `parsers`. It compiles on the next start (`:TSInstall bash` does it now).

   ```lua
   "python", "c", "cpp", "lua", "bash",
   ```

   Names: [supported languages](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/SUPPORTED_LANGUAGES.md).

2. **Server:** add it to `vim.lsp.enable`.

   ```lua
   vim.lsp.enable({ "basedpyright", "ruff", "clangd", "lua_ls", "bashls" })
   ```

   Names: `:help lspconfig-all`. Each entry says which program to install. Change its settings with
   `vim.lsp.config("<name>", { ... })`, like basedpyright's above that line.

3. **Programs:** install them, and add them to `install.sh` (`install_macos` and `install_linux`).
   A server that isn't installed is skipped without an error.

   ```sh
   brew install bash-language-server shellcheck shfmt                 # macOS
   npm install -g --prefix ~/.local bash-language-server              # Linux, needs Node.js
   uv tool install shellcheck-py && uv tool install shfmt-py          # Linux
   ```

   For bash, the server alone does navigation; shellcheck adds warnings and shfmt formatting.

4. **Check:** open a file, then `:checkhealth vim.lsp` (is the server attached?) and `:InspectTree`
   (is there a parser?).

Notes:
- The server covers `sh` and `bash` files, not zsh.
- bashls only finds scripts with an extension (`.sh`, `.bash`, ...) in the rest of the project, and
  looks at their top folder only. For all folders, start nvim with `GLOB_PATTERN='**/*@(.sh|.bash)'`.
