Objective: add an in-game mod installer to the Mods menu that browses and installs mods from GameBanana's "Psych Mod Folders" category.
Branch: main (uncommitted). Test runner: lime build linux -debug (no automated test suite); GameBanana API/HTTP checks with curl.

## Specs

S1. Mods menu button. `ModsMenuState` has an `INSTALL MODS` button that opens the browser state:
   - With mods installed: a 290x80 `MenuButton` at `bgButtons.x + 10` (free area left of the move/settings/on-off icons), first entry of the button row, reachable with UI left/right + ACCEPT and clickable with the mouse. It stays enabled even when there is only one mod (the move buttons disable themselves in that case).
   - With no mods installed: a 260x60 `PsychUIButton` at (400, 560) plus ACCEPT opens the browser.

S2. Browse category. The browser lists GameBanana category `28367` ("Psych Mod Folders"), API v11:
   `https://gamebanana.com/apiv11/Mod/Index?_nPage=<n>&_nPerpage=10&_csvModelInclusions=Mod&_aFilters%5BGeneric_Category%5D=28367`
   It shows the record count, current page, and per mod: name, author, category and view count. Next/previous page are available.
   (The index response does not expose like or download counts; see L4.)

S3. Install. For the selected mod the installer reads `https://gamebanana.com/apiv11/Mod/<id>/ProfilePage`, picks the first non-archived file whose name ends in `.zip`, downloads it following HTTP redirects (GameBanana answers `302` to `files.gamebanana.com`), and extracts it into `mods/<folder>`.
   - Zip paths are verified per segment; `..`, absolute paths and drive letters are rejected. `__MACOSX/`, `.DS_Store` and `Thumbs.db` are skipped.
   - Install folder detection: the shallowest `pack.json` folder, else a single shared top-level folder, else the archive root. A leading `mods/` (or `PsychEngine/mods/`) prefix is stripped.
   - An existing `mods/<folder>` is never overwritten; a numeric suffix is used instead.
   - After extraction the mod is registered in `modsList.txt` as enabled (existing entries keep their state).

S4. Feedback. While working, the browser shows the current stage (metadata, downloading, extracting with percentage, done/error) and blocks BACK so an install is not abandoned half-way. Success shows the install folder and that a game restart is required. Errors are shown in plain text: no `.zip` file, HTTP/redirect failure, network exception, invalid/corrupt zip, or no mod folder found inside the archive.

S5. Non-blocking. Index requests, metadata, download and extraction run on a background thread; the state polls progress in `update()` so the window keeps rendering. Downloads are capped at 400 MB (clear error above that) because the zip is held in memory.

S6. Safety warning. Before the first install of the session, an in-state overlay (not a mouse-only sub-prompt) warns that mods are third-party code that can run Lua/HScript and asks to install only trusted mods. ACCEPT installs the selected mod, BACK cancels; while it is open, navigation, page changes and install clicks are ignored.

S7. No behaviour change for the rest of the Mods menu: existing buttons, mod order, enable/disable and reload keep working.

## Tasks

- [x] T1 `backend/ModBrowser.hx`: API URLs/parsing, threaded HTTP with redirects, zip extraction with root detection and path validation, install registration. Spec: S2, S3, S5.
- [x] T2 `states/ModBrowserState.hx`: list/details UI, pagination, keyboard + mouse, status/progress, warning prompt. Spec: S2, S4, S6.
- [x] T3 `ModsMenuState`: `INSTALL MODS` button, layout shift, keyboard selection including the empty-mods case. Spec: S1, S7.
- [x] T4 Offline extraction check with the Haxe interpreter on a real GameBanana zip (root detection, file count, no path escapes). Spec: S3. Evidence: L5.
- [x] T5 `lime build linux -debug`. Spec: all. Evidence: `Link: ApplicationMain-debug` after fixing the `MAX_UNCOMPRESSED` overflow (L5).
- [ ] T6 Runtime check: open Mods → INSTALL MODS, list loads, install one small mod, verify `mods/<folder>` + `modsList.txt`. Spec: S1-S5.

## Log

L1 (user, verbatim, 2026-10-25):

> ahora podrias hacer que puedas instalar mods desde el menu de mods al precinar un boton que diga instalar mods y permita descargar desde la parte de mods folder  de psych engine (https://gamebanana.com/mods/cats/28367)

L2 (assistant, 2026-10-25): feasibility checked before writing code.
- `haxe.Http` over HTTPS works in this build: `CoolUtil` already fetches the online version at boot.
- Category `28367` is "Psych Mod Folders" (8437 records). `Mod/Index` without `_sSort` works; `_sSort=default` is rejected as `UNKNOWN_SORT`.
- `Mod/<id>/ProfilePage` exposes `_aFiles[]._sDownloadUrl` (e.g. `https://gamebanana.com/dl/1863731`), and that URL answers `302` to `files.gamebanana.com`; a plain UA download returned a valid 2 MB zip with one `pack.json` folder.
- `haxe.zip.Reader` is pure Haxe on this target (no zlib haxelib), and `sys.thread` is already used by `Discord.hx`/`LoadingState.hx`.

L3 (assistant, 2026-10-25): implementation choices.
- `backend/ModBrowser.hx` owns API URLs, redirect-following `httpGet` (`onStatus` + `Location`), zip extraction and `ModTask` (Mutex-guarded snapshots; the state polls it from `update()`).
- `states/ModBrowserState.hx` owns the UI (10 rows/page, details panel, status line, warning overlay). Threads: `Thread.create(function() ModBrowser.fetchIndex/install(...))`.
- The warning is an in-state overlay instead of `states.editors.content.Prompt` so it is keyboard-friendly (ACCEPT/BACK); the Prompt is mouse-only.
- `ModsMenuState` got `buttonInstall` in the normal path and a `PsychUIButton` in the empty-mods path; `openBrowser()` saves `modsList.txt` before switching states.

L4 (assistant, 2026-10-25): GameBanana index records do not carry like/download counts (`_nLikeCount` and `_nDownloadCount` are null even with `_csvProperties`), so the browser shows views/category instead of fabricated zeros. Verified with `curl` against page 1 of category 28367.

L5 (assistant, 2026-10-25): offline extraction + HTTP evidence, run with `haxe --interp` on a scratch copy of `ModBrowser.hx` where only `Paths.mods(x)` was replaced by `'mods/' + x` (all algorithms unchanged):
- `MAX_UNCOMPRESSED` was `2 * 1024 * 1024 * 1024`, which Haxe evaluates as Int32 and overflows to -2147483648, so every install threw "Archive is too large when uncompressed." Fixed to `2.0 * 1024 * 1024 * 1024`; reproduced the overflow with a two-line Haxe program.
- flat zip (files at root): folder = preferred name, 2/2 files.
- `mods/MyMod/...` zip: prefix stripped, folder = `MyMod`.
- nested `wrapper/MyMod/pack.json`: shallowest `pack.json` wins, folder = `MyMod`.
- hostile zip (`../../escape.txt`, `/abs.txt`, `mod/../../../up.txt`, `__MACOSX/`, `.DS_Store`): only `pack.json` + `ok.txt` written; `find` confirmed no file escaped.
- real GameBanana zip 1863731 (`Zephyrus Shaggy`): full `ModBrowser.install` ran (metadata → download 2,029,052 bytes → extract) and produced `mods/Playable Zeph Shaggy Mystery Inc/` with exactly the 7 files listed by `unzip -l`; a second install produced `...-2` and kept the first folder.
- `ModBrowser.httpGet` followed the `302` to `files.gamebanana.com` and returned exactly 2,029,052 bytes; index JSON was 11,621 bytes and `fetchIndex` parsed `total = 8437` with correct titles/authors.
