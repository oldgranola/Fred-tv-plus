# Lessons Learned: Flatpak Packaging with Claude MCP
## Project: Fred TV Plus (Tauri/Rust/Angular app on Linux Mint)

---

## What We Were Doing

Packaging a forked Tauri app (Fred TV Plus) as a Flatpak to solve Linux
cross-version compatibility problems caused by WebKitGTK and system library
mismatches between Linux Mint 22.x and 21.x.

---

## What Went Wrong and Why

### Root Cause of Most Problems: Skipped Primary Research

The single biggest mistake was writing a Flatpak manifest from general knowledge
rather than first reading the original author's published manifest. The original
author had already solved every problem we encountered — runtime selection,
WebKit availability, mpv integration — and their solution was publicly available
on Flathub. We spent hours rediscovering what they already knew.

**Rule: When forking an existing project that already has a working packaged
release, reading that packaging configuration is Step 1, not an afterthought.**

### The Specific Technical Dead Ends

| Attempt | What Failed | Why |
|---|---|---|
| Host mpv via --filesystem=host | libass version mismatch | Host mpv compiled against different libs than sandbox |
| io.mpv.Mpv as base app | libvpx missing | mpv base uses freedesktop runtime, not GNOME |
| Switch to freedesktop runtime | javascriptcoregtk missing | freedesktop doesn't include WebKitGTK, which Tauri needs |
| Build mpv from source modules | Correct direction, abandoned | Unnecessary once flatpak-spawn --host was identified |

**The working solution** was GNOME 48 runtime (for WebKit) + wrapper scripts
using `flatpak-spawn --host mpv` to call the host system's mpv in its own
environment. This avoids all library conflicts entirely.

---

## Better Process for Future Similar Projects

### Phase 1: Research Before Writing Anything

1. **Read the original packaging** — if the upstream project has a Flatpak,
   snap, or AppImage, fetch and read that file completely before writing a line.

2. **Identify the runtime stack** — for any app, answer these questions first:
   - What UI toolkit does it use? (GTK, Qt, Electron, WebView?)
   - Which Flatpak runtime provides that toolkit? (GNOME = WebKit/GTK, KDE = Qt,
     freedesktop = minimal base)
   - Does it call external binaries? (mpv, ffmpeg, etc.) How?

3. **Check for known conflicts** — Tauri apps always need WebKitGTK, which
   lives in the GNOME runtime. Media players need codec libraries that live in
   the freedesktop ffmpeg-full extension. These two requirements pulling in
   different runtimes is a known tension with a known solution (flatpak-spawn).

4. **Identify unknowns explicitly** before starting, for example:
   - "I don't know which runtime version io.mpv.Mpv requires — check before
     assuming."
   - "I don't know if flatpak-builder caches between runs when build dir is
     deleted — test before advising."

### Phase 2: Structured Prompting for Claude MCP

**What worked well in this session:**
- Asking Claude to read actual project files before proposing solutions
- Incremental error fixing with full bash output pasted each time
- Asking "why" questions ("what does budget mean?") rather than just
  accepting what Claude says

**What to do differently:**

Instead of: *"Help me package this as Flatpak"*

Use a structured brief:
```
Context:
- App: [name], tech stack: [Tauri/Rust/Angular]
- Original author's Flatpak manifest: [URL or paste contents]
- Goal: Fork with these changes: [list]
- Target: Personal use, Linux Mint 21+

Research phase (do this before writing any files):
1. Read the original manifest at [URL]
2. Identify the exact runtime, SDK, and base app used
3. List all external binary dependencies and how they are called
4. Identify any known issues in the original author's issue tracker

Only after research: propose a manifest that is a minimal diff from the
original, changing only app-id, name, and version.
```

### Phase 3: Hypothesis-Driven Debugging

When something fails, treat it like a science experiment:

1. **State what you observe** — exact error text
2. **Form a hypothesis** — "mpv fails because libvpx is missing from the
   GNOME runtime. Hypothesis: io.mpv.Mpv requires freedesktop runtime."
3. **Identify the test** — "Check io.mpv.Mpv's manifest to confirm its
   runtime before changing anything."
4. **Run the test, then act** — don't change the manifest until the
   hypothesis is confirmed.

In this session we often skipped straight from observation to action,
which is why we cycled through multiple failed approaches.

---

## Practical Rules for Flatpak + Tauri Apps

1. **GNOME runtime is required for Tauri** — it provides WebKitGTK.
   Never switch away from it to solve a media library problem.

2. **External binaries (mpv, ffmpeg) should use flatpak-spawn --host**
   for personal/family use. This calls the host system's binary in its
   own environment, bypassing all library conflicts. Requires the
   `--talk-name=org.freedesktop.Flatpak` finish-arg.

3. **tauri build --no-bundle --config '{"build":{"beforeBuildCommand":""}}'**
   is the correct way to build a Tauri app inside flatpak-builder. Plain
   `cargo build` skips Tauri's frontend embedding step and produces a
   binary that looks for a dev server.

4. **--force-clean wipes the build cache every time.** Use
   `rm -rf build-flatpak` before each run instead, preserving the
   flatpak-builder internal cache in ~/.flatpak-builder/cache/.
   This makes iterative rebuilds faster. Unfortunately changing the
   manifest's finish-args triggers a full rebuild anyway.

5. **rust-stable SDK extension may lag behind** your project's
   rust-version requirement. Use rust-nightly if rust-stable is too old.

6. **The sha256 in the manifest must be exact.** The setup script
   automates this for yt-dlp. Re-run setup whenever yt-dlp updates.

---

## Files Created in This Project

```
io.github.oldgranola.open-tv.yml   Main Flatpak manifest
flatpak/setup-flatpak-deps.sh      Pre-build dependency fetcher
flatpak/export-bundle.sh           Post-build bundle exporter
flatpak/io.github.oldgranola.open-tv.metainfo.xml  App metadata
flatpak/LESSONS-LEARNED.md         This file
```

## Build Commands Reference

```
# One-time setup (needs internet):
chmod +x flatpak/setup-flatpak-deps.sh flatpak/export-bundle.sh
flatpak/setup-flatpak-deps.sh

# Build:
rm -rf build-flatpak && flatpak-builder --user --install build-flatpak io.github.oldgranola.open-tv.yml

# Test:
flatpak run io.github.oldgranola.open-tv

# Export shareable bundle:
flatpak/export-bundle.sh

# Install on another machine:
flatpak install --user fred-tv-plus.flatpak
flatpak run io.github.oldgranola.open-tv
```

## Installing on a New Machine (Requirements)

The receiving machine needs:
- flatpak installed: `sudo apt install flatpak`
- Flathub configured: `flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo`
- GNOME 48 runtime: `flatpak install --user flathub org.gnome.Platform//48`
- mpv installed on the host: `sudo apt install mpv ffmpeg yt-dlp`

---

*Written after completing the first successful Flatpak build — March 2026*
