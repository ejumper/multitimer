#!/usr/bin/env bash
# Installs Planner into ~/.local — no root, no installer.
#   app bundle  -> ~/.local/lib/planner        (self-contained Flutter bundle)
#   icon        -> ~/.local/share/icons/hicolor/256x256/apps/planner-timer.png
#   (NOT "planner" — that name is taken by the Breeze/Slot-Ars themes)
#   launcher    -> ~/.local/share/applications/planner.desktop
#   terminal    -> ~/.local/bin/planner        (symlink)
# Re-run after `scripts/build.sh` to upgrade. See uninstall.sh to remove.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE="$REPO/apps/planner/build/linux/x64/release/bundle"
APP_DIR="$HOME/.local/lib/planner"
BIN_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
APPS_DIR="$HOME/.local/share/applications"

if [ ! -x "$BUNDLE/planner" ]; then
  echo "Bundle not built — run: new-app/scripts/build.sh" >&2
  exit 1
fi

echo "· app bundle  -> $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
cp -r "$BUNDLE"/. "$APP_DIR"/

echo "· icon        -> $ICON_DIR/planner-timer.png"
mkdir -p "$ICON_DIR"
cp "$REPO/assets/icon/planner-timer.png" "$ICON_DIR/planner-timer.png"

echo "· launcher    -> $APPS_DIR/com.example.planner.desktop"
mkdir -p "$APPS_DIR"
# The FILE NAME must match the app-id (com.example.planner): on Wayland the
# window decoration's icon is resolved from the app-id -> desktop file, and
# a mismatch leaves KWin's generic placeholder in the titlebar.
sed -e "s|@EXEC@|$APP_DIR/planner|" \
       -e "s|@ICON@|$ICON_DIR/planner-timer.png|" \
       "$REPO/assets/desktop/planner.desktop" \
  > "$APPS_DIR/com.example.planner.desktop"
chmod +x "$APPS_DIR/com.example.planner.desktop"
rm -f "$APPS_DIR/planner.desktop"   # legacy name from earlier installs

echo "· terminal    -> $BIN_DIR/planner"
mkdir -p "$BIN_DIR"
ln -sf "$APP_DIR/planner" "$BIN_DIR/planner"

# Refresh launcher/icon caches (best effort — usually automatic).
update-desktop-database "$APPS_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo
echo "Installed. Launch 'Planner' from the app launcher, or run: planner"
