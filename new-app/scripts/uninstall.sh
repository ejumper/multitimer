#!/usr/bin/env bash
# Removes everything install.sh placed in ~/.local (nothing else is touched).
set -euo pipefail

APP_DIR="$HOME/.local/lib/planner"
BIN="$HOME/.local/bin/planner"
ICON="$HOME/.local/share/icons/hicolor/256x256/apps/planner.png"
DESKTOP="$HOME/.local/share/applications/planner.desktop"
APPS_DIR="$HOME/.local/share/applications"

rm -rf "$APP_DIR"
rm -f "$BIN" "$ICON" "$DESKTOP"

update-desktop-database "$APPS_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "Planner removed from ~/.local."
