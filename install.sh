#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p ~/.local/bin
install -m 755 bin/reopen-save bin/reopen-restore bin/reopen-restore-agents ~/.local/bin/

# Install the boot hook the official way when available
if command -v omarchy-hook-install &>/dev/null; then
  omarchy-hook-install post-boot hooks/post-boot.d/10-reopen
else
  mkdir -p ~/.config/omarchy/hooks/post-boot.d
  install -m 755 hooks/post-boot.d/10-reopen ~/.config/omarchy/hooks/post-boot.d/
fi

echo "Installed:"
echo "  ~/.local/bin/reopen-save"
echo "  ~/.local/bin/reopen-restore"
echo "  ~/.local/bin/reopen-restore-agents"
echo "  ~/.config/omarchy/hooks/post-boot.d/10-reopen"
echo
echo "Optional: merge extensions/omarchy-menu-snippet.jsonc into"
echo "~/.config/omarchy/extensions/omarchy-menu.jsonc for menu integration,"
echo "then run: omarchy menu refresh"
