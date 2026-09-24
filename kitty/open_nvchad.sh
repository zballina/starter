#!/usr/bin/env bash
set -e

export PATH="/opt/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Ensure Kitty is located in /Applications or in PATH
if ! command -v kitty >/dev/null 2>&1; then
  if [ -x "/Applications/kitty.app/Contents/MacOS/kitty" ]; then
    KITTY_BIN="/Applications/kitty.app/Contents/MacOS/kitty"
  fi
else
  KITTY_BIN="kitty"
fi

for f in "$@"; do
  if [ -d "$f" ]; then
    target_dir="$f"
  else
    target_dir="$(dirname "$f")"
  fi

  "$KITTY_BIN" --detach --directory "$target_dir" env NVIM_APPNAME=nvim-nvchad /opt/local/bin/nvim "$f"
done
