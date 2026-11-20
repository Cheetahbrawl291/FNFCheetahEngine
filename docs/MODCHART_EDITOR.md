# Use the external LUA Modchart Editor

The editor menu no longer launches a separate `.exe`. It now guides you through the [LUA Modchart Editor](https://gamebanana.com/scripts/12931) v1.2.2 by .bakugo / CommanderVideo, which runs inside a song. The script is **not included** in this repository: its license is CC BY-NC-ND 4.0, so you download it yourself and the engine never ships a modified copy.

## Quick path

1. Download `LUA Modchart Editor` v1.2.2 from GameBanana and keep the `.lua` file unchanged.
2. Copy it into `assets/shared/scripts/` or into `mods/<your-mod>/scripts/`.
3. Open **Options → Modchart Editor → Lua Compatibility** and turn it on.
4. Enter **Editors → Modchart Editor**. The screen must report `editor script FOUND`.
5. Start any song and press **5**. The song restarts with the editor active.
6. While testing a modchart, press **BACKSPACE** to return to the editing UI.

## Details

| Topic | Decision |
|-------|----------|
| Compatibility switch | Off by default. No script gets a different Lua version until you enable it. |
| Scope of the switch | Only a `.lua` whose own header contains `LUA Modchart Editor v` and `.bakugo` receives the Psych version string. Every other script keeps the engine version. |
| Why a version shim | The editor branches on Psych versions (`> 0.6.3`, `> 0.7.1h`, `> 0.7.3`). This engine reports `0.0.1`, which would send the script down its legacy path. The bridge exposes `1.0.4` to that script only. |
| Existing Lua APIs | `runHaxeCode` and `addHaxeLibrary` already reach Lua through `HScript.implement(this)`; no new execution API was added. Safe Mode is unchanged. |
| Detection | The editor menu scans `assets/shared/scripts/` and enabled mod script folders for the script header. It never executes a script while scanning. |
| License | CC BY-NC-ND 4.0. The engine does not redistribute or modify the script; you are responsible for following its license when you download it. |

## Checklist

- [ ] The `.lua` file is in a scripts folder and its header is intact.
- [ ] **Lua Compatibility** is enabled and the editor menu reports `FOUND`.
- [ ] Pressing **5** in a song opens the editor after a restart.
- [ ] Exported modcharts appear under `mods/savedModcharts/`.
- [ ] Turning the switch off restores the normal engine version for all scripts.

## Windows handoff

Local verification covers the detector test, static checks and a Linux build only. Windows runtime checks belong to the user's friend:

1. `lime build windows -debug`.
2. Enable **Options → Modchart Editor → Lua Compatibility**.
3. Open **Editors → Modchart Editor** and confirm the script is detected.
4. Start a song, press **5**, confirm the editor UI opens after restart.
5. Create one strum action, use **Test**, then press **BACKSPACE** to return.
6. Save a modchart and confirm the generated file in `mods/savedModcharts/`.
7. Disable the switch, restart the game and confirm the script either reports a version problem or is not loaded; other Lua scripts must still work.

## Next step

If the script reports an incompatibility after these steps, record the exact error text and the engine build target before changing the shim version.
