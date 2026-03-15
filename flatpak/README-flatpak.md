# Fred TV Plus — Flatpak Packaging Guide

This guide explains how to build and distribute Fred TV Plus as a Flatpak.
Flatpak solves the Linux compatibility problem by bundling its own runtime,
so a build on Linux Mint 22 will work perfectly on Mint 21, 20, Ubuntu 20.04,
Fedora, Arch, and any other modern Linux distro.

---

## Why Flatpak instead of .deb / AppImage?

| Problem                        | .deb / AppImage        | Flatpak                         |
|-------------------------------|------------------------|---------------------------------|
| Links to system WebKitGTK     | Yes — breaks on older  | No — uses bundled runtime       |
| Links to system glibc         | Yes — breaks on older  | No — sandboxed                  |
| Requires mpv/ffmpeg installed | Yes                    | No — bundled or in runtime      |
| Works on Mint 21, 20, Fedora? | Not guaranteed         | Yes                             |
| One file to share with family | No (.deb = one distro) | Yes (.flatpak bundle file)      |

---

## Quick Start (everything in order)

### Prerequisites — install once on your build machine (Mint 22.3)

```bash
# Flatpak tooling
sudo apt update
sudo apt install flatpak flatpak-builder

# Add Flathub (the main Flatpak app store / runtime source)
flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
```

---

### Step 1 — Run the setup script

This downloads all build runtimes and pre-fetches Rust + npm dependencies.
**You must be online for this step.** The build itself is offline.

```bash
cd ~/DevTest/github/open-tv
bash flatpak/setup-flatpak-deps.sh
```

This script:
- Installs the GNOME 47 runtime + Rust + Node20 SDK extensions via Flatpak
- Runs `cargo fetch` to download all Rust crates into `flatpak/cargo-sources/`
- Runs `npm ci --cache` to snapshot npm packages into `flatpak/npm-cache/`
- Fetches the current yt-dlp binary hash and writes it into the manifest

You only need to re-run this when:
- You add/update Rust or npm dependencies (`Cargo.toml` or `package.json` changed)
- yt-dlp releases a new version you want to include

---

### Step 2 — Build the Flatpak

```bash
cd ~/DevTest/github/open-tv

flatpak-builder \
  --user \
  --install \
  --force-clean \
  build-flatpak \
  io.github.oldgranola.open-tv.yml
```

**What each flag means:**
- `--user` — installs for your user only, no sudo needed
- `--install` — installs the built app so you can test it immediately
- `--force-clean` — starts fresh (removes previous build artifacts)
- `build-flatpak` — the temporary build directory (safe to delete)

**First build takes ~10–30 minutes** because Cargo compiles everything from scratch.
Subsequent builds are much faster due to caching.

---

### Step 3 — Test it

```bash
flatpak run io.github.oldgranola.open-tv
```

If it opens and works, you're done. If not, see Troubleshooting below.

---

### Step 4 — Export a shareable bundle file

```bash
bash flatpak/export-bundle.sh
```

This creates `fred-tv-plus.flatpak` in the project root.
Copy this single file to any Linux machine and install it with:

```bash
# On the receiving machine (Mint 21, another laptop, etc.):
flatpak install --user fred-tv-plus.flatpak
flatpak run io.github.oldgranola.open-tv
```

The receiving machine needs Flatpak installed and Flathub configured
(the setup script handles this, or they can run the two apt/flatpak commands
from Prerequisites above).

---

## How it all fits together

```
io.github.oldgranola.open-tv.yml   ← Main manifest (the recipe)
flatpak/
  setup-flatpak-deps.sh            ← Run before building (fetches deps)
  export-bundle.sh                 ← Run after building (makes .flatpak file)
  cargo-sources/                   ← Pre-fetched Rust crates (git-ignored, large)
  npm-cache/                       ← Pre-fetched npm packages (git-ignored, large)
  dev.fredol.open-tv.metainfo.xml  ← App store metadata (already existed)
  open_tv.desktop                  ← Desktop launcher entry (already existed)
```

### What the manifest does

The manifest (`io.github.oldgranola.open-tv.yml`) tells `flatpak-builder`:

1. **Runtime**: Use `org.gnome.Platform//47` — this provides WebKitGTK,
   GTK3, glib, and all the system libraries Tauri needs. No more
   "wrong WebKit version" problems.

2. **SDK Extensions**: Pull in Rust (stable) and Node 20 build tools
   from the Freedesktop SDK extension catalog.

3. **Modules** (built in order):
   - `yt-dlp` — downloads and installs the yt-dlp binary into `/app/bin/`
   - `open-tv` — builds the Angular frontend, then the Rust backend,
     then installs everything into `/app/`

4. **Sandbox permissions** (`finish-args`): Declares what the app is
   allowed to access at runtime — network, home folder, audio, GPU.

---

## Updating the app version

When you make code changes and want to rebuild:

```bash
cd ~/DevTest/github/open-tv

# If you changed Cargo.toml or package.json, re-run setup:
bash flatpak/setup-flatpak-deps.sh

# Rebuild (incremental - faster than first build):
flatpak-builder --user --install --force-clean \
  build-flatpak io.github.oldgranola.open-tv.yml

# Test:
flatpak run io.github.oldgranola.open-tv

# Export new bundle:
bash flatpak/export-bundle.sh
```

---

## Troubleshooting

### Build fails with "WebKit not found" or missing library
The GNOME 47 runtime includes WebKitGTK 4.1. If Tauri is looking for
a different version, check `src-tauri/Cargo.toml` — the `tauri` dependency
version determines which WebKit it expects.

### "cargo: command not found" during build
The Rust SDK extension isn't being found. Make sure the manifest's
`build-options.append-path` includes `/usr/lib/sdk/rust-stable/bin`.

### npm install fails offline
The npm cache in `flatpak/npm-cache/` may be stale or incomplete.
Re-run `bash flatpak/setup-flatpak-deps.sh` to refresh it.

### App opens but mpv won't play streams
mpv needs to be available inside the Flatpak sandbox. The manifest
currently relies on the host system's mpv via `--filesystem=home`.
If this is a problem, mpv can be added as a Flatpak module (ask Claude).

### "App ID not found" when installing bundle on another machine
Make sure the receiving machine has Flatpak installed and the GNOME runtime:
```bash
sudo apt install flatpak
flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user flathub org.gnome.Platform//47
```

---

## .gitignore additions

Add these to your `.gitignore` — the pre-fetched caches are large
and should not be committed to git:

```
flatpak/cargo-sources/
flatpak/npm-cache/
build-flatpak/
flatpak-repo/
fred-tv-plus.flatpak
```
