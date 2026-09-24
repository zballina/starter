#!/usr/bin/env bash
set -e

export PATH="/opt/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Asegurar que wezterm se localice si está en /Applications o en PATH
if ! command -v wezterm >/dev/null 2>&1; then
  if [ -x "/Applications/WezTerm.app/Contents/MacOS/wezterm" ]; then
    WEZTERM_BIN="/Applications/WezTerm.app/Contents/MacOS/wezterm"
  fi
else
  WEZTERM_BIN="wezterm"
fi

for f in "$@"; do
  if [ -d "$f" ]; then
    "$WEZTERM_BIN" start --cwd "$f" -- env NVIM_APPNAME=nvim-nvchad /opt/local/bin/nvim "$f"
  else
    dir=$(dirname "$f")
    "$WEZTERM_BIN" start --cwd "$dir" -- env NVIM_APPNAME=nvim-nvchad /opt/local/bin/nvim "$f"
  fi
done
