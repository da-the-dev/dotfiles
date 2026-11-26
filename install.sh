#!/usr/bin/env bash
# Set up these dotfiles on a machine: nvim + tools, configs linked into ~/.config.
#   macOS: installs with Homebrew.
#   Linux: no root needed; release binaries go to ~/.local (bin/ and opt/).
# Safe to re-run: installed tools are skipped (UPDATE=1 ./install.sh to reinstall them),
# existing non-symlink configs are never overwritten.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOME/.local/bin"
OPT="$HOME/.local/opt"
NVIM_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
UPDATE="${UPDATE:-0}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

mkdir -p "$BIN" "$OPT" "$HOME/.config"
ORIG_PATH="$PATH"
export PATH="$BIN:$PATH"

# ---------- tools ----------

install_macos() {
  have brew || { warn "Install Homebrew first: https://brew.sh"; exit 1; }

  local brewfile
  brewfile="$(dirname "${BASH_SOURCE[0]}")/Brewfile"

  log "brew: $(brew bundle list --formula --file="$brewfile" | paste -sd' ' -)"

  brew bundle --file="$brewfile"

  "$DOTFILES/zoomit/install.sh" || warn "ZoomIt not installed"
}

# Latest release tag of a GitHub repo, e.g. "v14.1.1"
latest_tag() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1
}

# needs <name>: true if <name> should be (re)installed into ~/.local/bin
needs() { [ "$UPDATE" = 1 ] || [ ! -e "$BIN/$1" ]; }

install_linux() {
  local arch tmp tag
  case "$(uname -m)" in
    x86_64 | amd64) arch=x86_64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) warn "unsupported CPU: $(uname -m)"; exit 1 ;;
  esac
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp:-}"' EXIT

  if needs nvim; then
    log "nvim (latest release)"
    curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-$arch.tar.gz" | tar -xz -C "$tmp"
    rm -rf "$OPT/nvim" && mv "$tmp/nvim-linux-$arch" "$OPT/nvim"
    ln -sfn "$OPT/nvim/bin/nvim" "$BIN/nvim"
  fi

  if needs rg; then
    tag="$(latest_tag BurntSushi/ripgrep)"
    local rg_target; [ "$arch" = x86_64 ] && rg_target=x86_64-unknown-linux-musl || rg_target=aarch64-unknown-linux-gnu
    log "ripgrep $tag"
    curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/$tag/ripgrep-$tag-$rg_target.tar.gz" | tar -xz -C "$tmp"
    install -m 755 "$tmp/ripgrep-$tag-$rg_target/rg" "$BIN/rg"
  fi

  if needs tree-sitter; then
    log "tree-sitter CLI (latest release)"
    local ts_arch; [ "$arch" = x86_64 ] && ts_arch=x64 || ts_arch=arm64
    curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$ts_arch.gz" | gunzip > "$BIN/tree-sitter"
    chmod 755 "$BIN/tree-sitter"
    # release binaries need a recent glibc; optional (parsers compile with cc), so drop it if broken
    "$BIN/tree-sitter" --version >/dev/null 2>&1 || { rm "$BIN/tree-sitter"; warn "tree-sitter CLI doesn't run here (glibc too old); skipped, not needed for the bundled parsers"; }
  fi

  if needs lazygit; then
    tag="$(latest_tag jesseduffield/lazygit)"
    log "lazygit $tag"
    curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/$tag/lazygit_${tag#v}_Linux_$arch.tar.gz" | tar -xz -C "$tmp" lazygit
    install -m 755 "$tmp/lazygit" "$BIN/lazygit"
  fi

  if needs lua-language-server; then
    tag="$(latest_tag LuaLS/lua-language-server)"
    local lls_arch; [ "$arch" = x86_64 ] && lls_arch=x64 || lls_arch=arm64
    log "lua-language-server $tag"
    rm -rf "$OPT/lua-language-server" && mkdir -p "$OPT/lua-language-server"
    curl -fsSL "https://github.com/LuaLS/lua-language-server/releases/download/$tag/lua-language-server-$tag-linux-$lls_arch.tar.gz" |
      tar -xz -C "$OPT/lua-language-server"
    ln -sfn "$OPT/lua-language-server/bin/lua-language-server" "$BIN/lua-language-server"
  fi

  if ! have uv; then
    log "uv"
    curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh
  fi

  log "uv tools: ruff, basedpyright, shellcheck-py, shfmt-py"
  uv tool install -q ruff
  uv tool install -q basedpyright # bundles its own Node.js
  uv tool install -q shellcheck-py
  uv tool install -q shfmt-py

  if needs bash-language-server; then
    log "bash-language-server"
    have npm || uv tool install -q nodejs-wheel # Node.js
    npm install -g --silent --prefix "$HOME/.local" bash-language-server || warn "bash-language-server is not installed: no bash LSP in nvim"
  fi

  have clangd || warn "clangd not found (C/C++ LSP); install it from your system packages if you need it"
  have tmux || warn "tmux not found; install it from your system packages"
  have magick || have convert || warn "ImageMagick not found: no inline plots in nvim (<leader>jp still works)"
}

# utftex (math in markdown): no packages, so it's built from the release tarball (needs cc and make)
install_utftex() (
  needs utftex || exit 0
  version=1.31 sha256=8ca5a11d387631a34979295f73f9a2eccc87e17c690dcd4c1454eb65a9e372bc
  log "utftex $version (compiled with cc)"
  tmp="$(mktemp -d)" && trap 'rm -rf "$tmp"' EXIT && cd "$tmp" || exit 1
  curl -fsSLO "https://github.com/bartp5/libtexprintf/releases/download/v$version/libtexprintf-$version.tar.gz" || exit 1
  [ "$( (sha256sum *.tar.gz 2>/dev/null || shasum -a 256 *.tar.gz) | cut -d' ' -f1)" = "$sha256" ] || { warn "utftex: wrong checksum"; exit 1; }
  tar -xzf *.tar.gz && cd "libtexprintf-$version" || exit 1
  { ./configure -q --disable-shared && make -s; } >build.log 2>&1 || { tail -5 build.log >&2; exit 1; }
  install -m 755 src/utftex "$BIN/utftex"
)

# ---------- configs ----------

# Link <pkg>/.config/* into ~/.config, with stow if available (same result either way)
link_pkg() {
  local pkg="$1" src dst
  if have stow; then
    stow -d "$DOTFILES" -t "$HOME" "$pkg" || warn "stow $pkg failed (existing files in the way?), skipped"
    return
  fi
  for src in "$DOTFILES/$pkg/.config/"*; do
    dst="$HOME/.config/$(basename "$src")"
    if [ -L "$dst" ]; then
      ln -sfn "$src" "$dst"
    elif [ -e "$dst" ]; then
      warn "$dst already exists; move it away and re-run to link $pkg"
    else
      ln -s "$src" "$dst"
    fi
  done
}

# ---------- run ----------

case "$(uname -s)" in
  Darwin) install_macos; packages=(nvim lazygit tmux git skhd yabai) ;;
  Linux) install_linux; packages=(nvim lazygit tmux git) ;;
  *) warn "unsupported OS: $(uname -s)"; exit 1 ;;
esac

log "jupytext"
uv tool install -q jupytext

install_utftex || warn "utftex not installed: math in markdown stays as source in nvim"

log "nvim python host (molten, debugpy): $NVIM_DATA/python-host"
[ -x "$NVIM_DATA/python-host/bin/python" ] || uv venv -q --python 3.13 "$NVIM_DATA/python-host"
uv pip install -q --python "$NVIM_DATA/python-host/bin/python" pynvim jupyter_client requests websocket-client debugpy

log "linking configs: ${packages[*]}"
# git identity lives in ~/.gitconfig (per machine, not in dotfiles). It must exist: otherwise
# `git config --global` would write into ~/.config/git/config, i.e. into this repo.
if [ ! -e "$HOME/.gitconfig" ]; then
  printf '# Machine-specific git identity. Shared aliases/settings: ~/.config/git/config (dotfiles)\n' > "$HOME/.gitconfig"
fi
for pkg in "${packages[@]}"; do link_pkg "$pkg"; done

log "nvim plugins (versions from lazy-lock.json)"
nvim --headless "+Lazy! restore" +qa
nvim --headless "+UpdateRemotePlugins" +qa >/dev/null 2>&1

# Things nvim would otherwise download on first start (needed for offline machines):
log "treesitter parsers (compiled with cc)"
nvim --headless -c "lua require('nvim-treesitter').install(vim.g.treesitter_parsers):wait(600000)" -c qa
log "blink.cmp fuzzy matcher library"
nvim --headless -c "lua vim.defer_fn(function() vim.cmd('cq') end, 120000)" \
  -c "lua require('blink.cmp.fuzzy.download').ensure_downloaded(function(err) if err then io.stderr:write(tostring(err)) vim.cmd('cq') else vim.cmd('qa') end end)"

# ---------- reminders ----------

case ":$ORIG_PATH:" in
  *":$BIN:"*) ;;
  *) warn "$BIN isn't on your PATH; add to your shell rc:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac
if [ "$(uname -s)" = Darwin ] && [ -z "${LG_CONFIG_FILE:-}" ]; then
  warn "lazygit on macOS reads ~/Library/Application Support; add to ~/.zshrc:  export LG_CONFIG_FILE=\"\$HOME/.config/lazygit/config.yml\""
fi
if have tmux && [ "$(tmux -V | sed 's/[^0-9.]//g' | awk -F. '{print ($1 * 100 + $2 >= 301)}')" = 0 ]; then
  warn "tmux < 3.1 doesn't read ~/.config/tmux; run:  ln -s ~/.config/tmux/tmux.conf ~/.tmux.conf"
fi
git config --file "$HOME/.gitconfig" user.email >/dev/null ||
  warn "set your git identity: git config --file ~/.gitconfig user.name \"...\"; git config --file ~/.gitconfig user.email \"...\""
log "done"
