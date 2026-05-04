#!/usr/bin/env bash
# syncgit installer — links the CLI onto PATH and installs the /sync slash command.
#
# Usage:
#   ./install.sh                    install from this checkout (developer mode)
#   ./install.sh --version=v0.1.0   install a tagged release from GitHub
#   ./install.sh --uninstall        remove symlinks

set -euo pipefail

bin_target="$HOME/.local/bin/syncgit"
cmd_target="$HOME/.claude/commands/sync.md"

print_help() {
  cat <<EOF
Usage:
  ./install.sh                    install from this checkout (developer mode)
  ./install.sh --version=v0.1.0   install a tagged release from GitHub
  ./install.sh --uninstall        remove symlinks
EOF
}

parse_args() {
  VERSION=""
  ACTION="install"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --uninstall) ACTION="uninstall"; shift ;;
      --version=*) VERSION="${1#--version=}"; shift ;;
      --version) VERSION="$2"; shift 2 ;;
      -h|--help) print_help; exit 0 ;;
      *) echo "install.sh: unknown arg $1" >&2; exit 1 ;;
    esac
  done
}

uninstall() {
  [[ -L "$bin_target" ]] && rm "$bin_target" && echo "removed $bin_target"
  [[ -L "$cmd_target" ]] && rm "$cmd_target" && echo "removed $cmd_target"
  if [[ -d "$HOME/.local/share/syncgit" ]]; then
    rm -rf "$HOME/.local/share/syncgit"
    echo "removed $HOME/.local/share/syncgit"
  fi
  echo "syncgit uninstalled."
}

install_release() {
  local version="$1"
  local url="https://github.com/trumanellis/syncgit/archive/refs/tags/${version}.tar.gz"
  local stage="$HOME/.local/share/syncgit/$version"
  if [[ -d "$stage" ]]; then
    echo "syncgit: $version already extracted at $stage; reusing"
  else
    mkdir -p "$stage"
    echo "syncgit: downloading $version..."
    curl -sSL "$url" | tar -xz --strip-components=1 -C "$stage"
  fi
  here="$stage"
}

do_install() {
  mkdir -p "$(dirname "$bin_target")"
  ln -sfn "$here/bin/syncgit" "$bin_target"
  echo "linked $bin_target -> $here/bin/syncgit"

  if [[ -d "$HOME/.claude/commands" ]]; then
    ln -sfn "$here/commands/sync.md" "$cmd_target"
    echo "linked $cmd_target -> $here/commands/sync.md"
  else
    echo "note: ~/.claude/commands not found — Claude Code not detected."
    echo "      skipping /sync slash command install."
  fi

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *)
      echo
      echo "warning: $HOME/.local/bin is not on your PATH."
      echo "add this to your shell rc:"
      echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
      ;;
  esac

  echo
  echo "done. run: syncgit help"
}

parse_args "$@"

if [[ "$ACTION" == "uninstall" ]]; then
  uninstall
  exit 0
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "$VERSION" ]]; then
  install_release "$VERSION"
fi

do_install
