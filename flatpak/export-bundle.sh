#!/usr/bin/env bash
# =============================================================================
# Fred TV Plus - Export Flatpak Bundle
# =============================================================================
# Run this AFTER a successful flatpak-builder build to create a shareable
# .flatpak file that anyone can install with:
#   flatpak install --user fred-tv-plus.flatpak
#
# Usage:
#   cd ~/DevTest/github/open-tv
#   bash flatpak/export-bundle.sh
# =============================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="io.github.oldgranola.open-tv"
BUILD_DIR="$PROJECT_DIR/build-flatpak"
REPO_DIR="$PROJECT_DIR/flatpak-repo"
BUNDLE_NAME="fred-tv-plus.flatpak"

echo ""
echo "============================================"
echo " Fred TV Plus - Exporting Flatpak Bundle"
echo "============================================"
echo ""

if [ ! -d "$BUILD_DIR" ]; then
    echo "ERROR: Build directory not found at $BUILD_DIR"
    echo "       Run the build first:"
    echo "       flatpak-builder --user --install --force-clean build-flatpak io.github.oldgranola.open-tv.yml"
    exit 1
fi

echo "[1/3] Exporting build to repo..."
flatpak build-export "$REPO_DIR" "$BUILD_DIR"

echo "[2/3] Creating bundle file..."
flatpak build-bundle "$REPO_DIR" "$BUNDLE_NAME" "$APP_ID"

echo "[3/3] Done!"
echo ""
echo "Bundle created: $PROJECT_DIR/$BUNDLE_NAME"
echo ""
echo "To install on this or another machine:"
echo "  flatpak install --user fred-tv-plus.flatpak"
echo ""
echo "To run:"
echo "  flatpak run $APP_ID"
echo ""
