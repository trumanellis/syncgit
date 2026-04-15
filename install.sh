#!/usr/bin/env bash
# syncgit installer — links the CLI onto PATH and installs the /sync slash command.
#
# Usage:
#   ./install.sh              # install (or re-install)
#   ./install.sh --uninstall  # remove symlinks

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin_target="$HOME/.local/bin/syncgit"
cmd_target="$HOME/.claude/commands/sync.md"

uninstall() {
  [[ -L "$bin_target" ]] && rm "$bin_target" && echo "removed $bin_target"
  [[ -L "$cmd_target" ]] && rm "$cmd_target" && echo "removed $cmd_target"
  echo "syncgit uninstalled."
}

if [[ "${1:-}" == "--uninstall" ]]; then
  uninstall
  exit 0
fi

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
