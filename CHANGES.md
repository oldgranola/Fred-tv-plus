# Local Changes to open-tv / Fred TV

## Feature: Custom Playlists
**Date:** March 2026  
**Author:** oldgraola (with AI assistance from Claude, Anthropic)

### What was added

A custom playlist system allowing users to organize channels from any source 
(M3U, Xtream, custom) into named playlists of their own creation, independent 
of the provider's category structure.

### Changes by file

**Rust backend (`src-tauri/src/`)**
- `types.rs` — Added `Playlist` struct; added `playlist_id: Option<i64>` to `Filters`
- `sql.rs` — Added database migration (v9) creating `playlists` and 
  `playlist_channels` tables; extended `search()` to filter by playlist; 
  added functions: `get_playlists`, `create_playlist`, `rename_playlist`, 
  `delete_playlist`, `add_to_playlist`, `remove_from_playlist`, 
  `get_channel_playlist_ids`, `playlist_name_exists`
- `lib.rs` — Registered 8 new Tauri commands for playlist management

**Angular frontend (`src/app/`)**
- `models/playlist.ts` — New file: `Playlist` TypeScript interface
- `models/viewMode.ts` — Added `Playlist = 5` enum value
- `models/filters.ts` — Added `playlist_id?: number`
- `app.module.ts` — Added `MatDividerModule` import
- `home.component.ts` — Added playlist state management, `loadPlaylists()`, 
  `switchToPlaylist()`, `createPlaylist()`, `deletePlaylist()`
- `home.component.html` — Added "Playlists ▾" dropdown button with inline 
  create/delete UI and playlist list
- `channel-tile.component.ts` — Added `togglePlaylist()`, `isInPlaylist()`, 
  playlist loading on right-click
- `channel-tile.component.html` — Added "Playlists" submenu in right-click 
  context menu

### Design decisions

- Playlists are **source-agnostic**: any channel from any provider can be 
  added to any playlist
- Uses a join table (`playlist_channels`) rather than tags or denormalized 
  columns, keeping the schema clean and extensible
- Existing `favorite` functionality is unchanged
- Database migration is non-destructive and uses `IF NOT EXISTS` guards

### How it works (user perspective)

1. Click **Playlists ▾** in the top navigation bar
2. Type a name and press Enter or click **+** to create a playlist
3. Right-click any channel → **Playlists** submenu → click a playlist to 
   add/remove (✓ indicates membership)
4. Click a playlist name in the dropdown to view its channels
5. Click **✕** next to a playlist name to delete it

### AI assistance note

These changes were developed with the assistance of Claude (claude.ai, 
Anthropic) using the Model Context Protocol (MCP) filesystem integration, 
which allowed Claude to read and edit source files directly. The architecture 
decisions, code review, and testing were performed by the human author.
