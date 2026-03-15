#!/usr/bin/env bash
# =============================================================================
# Fred TV Plus - Flatpak Dependency Setup Script
# =============================================================================
# Run this ONCE (or after any dependency changes) before building the Flatpak.
# It pre-fetches all Cargo (Rust) and npm (Node) dependencies so that
# flatpak-builder can build entirely offline inside its sandbox.
#
# Usage:
#   cd ~/DevTest/github/open-tv
#   bash flatpak/setup-flatpak-deps.sh
# =============================================================================

set -e  # Stop on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FLATPAK_DIR="$SCRIPT_DIR"

echo ""
echo "============================================"
echo " Fred TV Plus - Flatpak Dependency Setup"
echo "============================================"
echo ""

# ---------------------------------------------------------------------------
# STEP 1: Check required tools are installed
# ---------------------------------------------------------------------------
echo "[1/6] Checking required tools..."

check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo "  ERROR: '$1' is not installed."
        echo "         Run: sudo apt install $2"
        exit 1
    else
        echo "  OK: $1 found"
    fi
}

check_tool flatpak        "flatpak"
check_tool flatpak-builder "flatpak-builder"
check_tool cargo          "cargo (install via rustup)"
check_tool npm            "npm nodejs"
check_tool curl           "curl"
check_tool python3        "python3"

echo ""

# ---------------------------------------------------------------------------
# STEP 2: Install required Flatpak runtimes and SDKs
# ---------------------------------------------------------------------------
echo "[2/6] Installing Flatpak runtimes (this may take a while on first run)..."

flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install --user --noninteractive flathub \
    org.gnome.Platform//48 \
    org.gnome.Sdk//48 \
    org.freedesktop.Sdk.Extension.rust-nightly//24.08 \
    org.freedesktop.Sdk.Extension.node20//24.08 \
    2>/dev/null || echo "  (Some runtimes may already be installed - continuing)"

echo "  Runtimes installed."
echo ""

# ---------------------------------------------------------------------------
# STEP 3: Pre-fetch Cargo (Rust) dependencies offline
# ---------------------------------------------------------------------------
echo "[3/6] Pre-fetching Cargo dependencies..."

cd "$PROJECT_DIR/src-tauri"

# Fetch all crates into a local vendor directory
mkdir -p "$FLATPAK_DIR/cargo-sources"
cargo fetch 2>&1 | tail -5

# Copy the fetched registry cache to our flatpak folder
# Cargo stores downloaded crates in ~/.cargo/registry
CARGO_REGISTRY="$HOME/.cargo/registry"
if [ -d "$CARGO_REGISTRY" ]; then
    echo "  Copying Cargo registry cache..."
    rsync -a --delete \
        "$CARGO_REGISTRY/" \
        "$FLATPAK_DIR/cargo-sources/registry/" \
        2>/dev/null || cp -rp "$CARGO_REGISTRY/." "$FLATPAK_DIR/cargo-sources/registry/"
    echo "  Cargo sources ready."
else
    echo "  WARNING: Cargo registry not found at $CARGO_REGISTRY"
    echo "           Try running 'cargo fetch' manually in src-tauri/"
fi

cd "$PROJECT_DIR"
echo ""

# ---------------------------------------------------------------------------
# STEP 4: Pre-fetch npm dependencies offline
# ---------------------------------------------------------------------------
echo "[4/6] Pre-fetching npm dependencies..."

mkdir -p "$FLATPAK_DIR/npm-cache"

# Pack all npm deps into the cache directory
npm ci --cache "$FLATPAK_DIR/npm-cache" --prefer-offline 2>&1 | tail -5
echo "  npm cache ready."
echo ""

# ---------------------------------------------------------------------------
# STEP 5: Get the yt-dlp sha256 hash and update the manifest
# ---------------------------------------------------------------------------
echo "[5/6] Fetching yt-dlp sha256 hash for manifest..."

YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
YTDLP_HASH=$(curl -sL --max-time 30 "$YTDLP_URL" 2>/dev/null | sha256sum | cut -d' ' -f1) || true

if [ -z "$YTDLP_HASH" ] || [ "$YTDLP_HASH" = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" ]; then
    echo "  WARNING: Could not fetch yt-dlp (network may be restricted)."
    echo "  Checking if manifest already has a valid hash..."
    MANIFEST="$PROJECT_DIR/io.github.oldgranola.open-tv.yml"
    if grep -q "USE_SETUP_SCRIPT_TO_FILL_THIS" "$MANIFEST"; then
        echo "  ACTION NEEDED: Manually update the sha256 in the manifest."
        echo "  On a machine with github access run:"
        echo "    curl -sL $YTDLP_URL | sha256sum"
        echo "  Then replace 'USE_SETUP_SCRIPT_TO_FILL_THIS' in io.github.oldgranola.open-tv.yml"
    else
        echo "  Manifest already has a hash, continuing."
    fi
else
    echo "  yt-dlp sha256: $YTDLP_HASH"
    MANIFEST="$PROJECT_DIR/io.github.oldgranola.open-tv.yml"
    sed -i "s/sha256: USE_SETUP_SCRIPT_TO_FILL_THIS/sha256: $YTDLP_HASH/" "$MANIFEST"
    echo "  Manifest updated with current yt-dlp hash."
fi

echo ""

# ---------------------------------------------------------------------------
# STEP 6: Summary
# ---------------------------------------------------------------------------
echo "[6/6] Setup complete!"
echo ""
echo "============================================"
echo " Next steps - BUILD the Flatpak:"
echo "============================================"
echo ""
echo "  cd ~/DevTest/github/open-tv"
echo ""
echo "  # Build (first time is slow - compiling everything):"
echo "  flatpak-builder --user --install --force-clean \\"
echo "    build-flatpak io.github.oldgranola.open-tv.yml"
echo ""
echo "  # Test run:"
echo "  flatpak run io.github.oldgranola.open-tv"
echo ""
echo "  # Export a shareable .flatpak bundle file:"
echo "  bash flatpak/export-bundle.sh"
echo ""
