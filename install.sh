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
  log "brew: nvim, rg, tree-sitter, lazygit, LSPs, uv, stow, imagemagick, tmux"
  brew install neovim ripgrep tree-sitter-cli lazygit lua-language-server basedpyright ruff uv stow imagemagick tmux
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
  trap 'rm -rf "$tmp"' EXIT

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

  log "uv tools: ruff, basedpyright"
  uv tool install -q ruff
  uv tool install -q basedpyright # bundles its own Node.js

  have clangd || warn "clangd not found (C/C++ LSP); install it from your system packages if you need it"
  have tmux || warn "tmux not found; install it from your system packages"
  have magick || have convert || warn "ImageMagick not found: no inline plots in nvim (<leader>jp still works)"
}

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
  Darwin) install_macos; packages=(nvim lazygit tmux skhd yabai) ;;
  Linux) install_linux; packages=(nvim lazygit tmux) ;;
  *) warn "unsupported OS: $(uname -s)"; exit 1 ;;
esac

log "jupytext"
uv tool install -q jupytext

log "nvim python host (for molten): $NVIM_DATA/python-host"
[ -x "$NVIM_DATA/python-host/bin/python" ] || uv venv -q --python 3.13 "$NVIM_DATA/python-host"
uv pip install -q --python "$NVIM_DATA/python-host/bin/python" pynvim jupyter_client requests websocket-client

log "linking configs: ${packages[*]}"
for pkg in "${packages[@]}"; do link_pkg "$pkg"; done

log "nvim plugins (versions from lazy-lock.json)"
nvim --headless "+Lazy! restore" +qa
nvim --headless "+UpdateRemotePlugins" +qa >/dev/null 2>&1

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
log "done"
