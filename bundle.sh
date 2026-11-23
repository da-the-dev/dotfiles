#!/usr/bin/env bash
# Build an offline bundle (dotfiles + nvim + all tools and plugins) for a Linux server
# without internet. Runs install.sh inside a Linux container whose $HOME is the server's
# $HOME, so all absolute paths (Python venvs, symlinks) are already right; on the server
# you only unpack it. Needs Docker.
#
#   ./bundle.sh /home/you                        # the server's $HOME (`echo $HOME` there)
#   ARCH=arm64 ./bundle.sh /home/you             # for an ARM server (default x86_64)
#   IMAGE=ubuntu:20.04 ./bundle.sh /home/you     # build on an older distro (see below)
#
# IMAGE: compiled parts need the same or a newer glibc on the server than in the image.
# Default ubuntu:22.04 (glibc 2.35); use an older image for older servers.
set -euo pipefail

SERVER_HOME="${1:?usage: ./bundle.sh <server \$HOME, e.g. /home/you>}"
ARCH="${ARCH:-x86_64}"
IMAGE="${IMAGE:-ubuntu:22.04}"
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$DOTFILES/dist"
NAME="dotfiles-bundle-linux-$ARCH.tar.gz"

case "$ARCH" in
  x86_64) platform=linux/amd64 ;;
  arm64) platform=linux/arm64 ;;
  *) echo "ARCH must be x86_64 or arm64" >&2; exit 1 ;;
esac

if [ -n "$(git -C "$DOTFILES" status --porcelain)" ]; then
  echo "note: the bundle is built from the last commit; uncommitted changes are not included" >&2
fi
mkdir -p "$OUT"

docker run --rm --platform "$platform" \
  -v "$DOTFILES:/src:ro" -v "$OUT:/out" \
  -e SERVER_HOME="$SERVER_HOME" -e NAME="$NAME" \
  "$IMAGE" bash -euo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive
    echo "==> container: build tools"
    apt-get update -qq && apt-get install -y -qq curl ca-certificates git build-essential >/dev/null

    export HOME="$SERVER_HOME"
    export UV_PYTHON_PREFERENCE=only-managed # bundle its own Python, not the image'"'"'s
    mkdir -p "$HOME"
    git config --global --add safe.directory "*"
    git clone -q /src "$HOME/dotfiles"
    origin="$(git -C /src remote get-url origin 2>/dev/null || true)"
    [ -n "$origin" ] && git -C "$HOME/dotfiles" remote set-url origin "$origin"

    "$HOME/dotfiles/install.sh"

    echo "==> packing $NAME"
    tar -czf "/out/$NAME" -C "$HOME" dotfiles .local/bin .local/opt .local/share .config
  '

cat <<EOF

Built dist/$NAME ($(du -h "$OUT/$NAME" | cut -f1)). On the server:

  scp dist/$NAME server:
  ssh server
  ls -d ~/.config/nvim ~/.config/lazygit ~/.config/tmux 2>/dev/null  # move these away first if listed
  tar -xzf $NAME -C ~ && rm $NAME
  echo 'export PATH="\$HOME/.local/bin:\$PATH"' >> ~/.bashrc           # once

Rebuilding and unpacking again updates everything in place.
EOF
