# Use the LUA Modchart Editor

The editor menu no longer launches a separate `.exe`. The [LUA Modchart Editor](https://gamebanana.com/scripts/12931) v1.2.2 by .bakugo / CommanderVideo is bundled verbatim in `assets/shared/scripts/ModchartEditor.lua` and loads in every song. Press **5** during a song to open it.

> The script is licensed CC BY-NC-ND 4.0. It ships unmodified, with its original header and author links intact. Source and credit: https://gamebanana.com/scripts/12931

## Quick path

1. Open **Editors → Modchart Editor**. The screen lists every freeplay song and its status.
2. Pick a song with **UP/DOWN** and press **ENTER**. The song starts with the editor already open — no need to press 5.
3. Build or edit a modchart. Exports go to `mods/savedModcharts/`.
4. While testing a modchart, press **BACKSPACE** to return to the editing UI.
5. Press **ESC** in the editor to exit.

Pressing **5** inside a song still opens the editor if you entered the song some other way. The picker reuses the engine's normal week list, so songs from enabled mods are included.

## Details

| Topic | Decision |
|-------|----------|
| Script location | `assets/shared/scripts/ModchartEditor.lua`, loaded for every song by `PlayState.hx:437-443`. |
| Compatibility switch | Options → Modchart Editor → Lua Compatibility, **on by default**. Turn it off to restore the engine version for all Lua scripts. |
| Scope of the switch | Only a `.lua` whose own header contains `LUA Modchart Editor v` and `.bakugo` receives the Psych version string. Every other script keeps the engine version. |
| Why a version shim | The editor branches on Psych versions (`> 0.6.3`, `> 0.7.1h`, `> 0.7.3`). This engine reports `0.0.1`, which would send the script down its legacy path. The bridge exposes `1.0.4` to that script only. |
| Existing Lua APIs | `runHaxeCode` and `addHaxeLibrary` already reach Lua through `HScript.implement(this)`; no new execution API was added. Safe Mode is unchanged. |
| Detection | The editor menu scans script folders for the script header. It never executes a script while scanning. |
| License | CC BY-NC-ND 4.0. The script is shipped as received, not as a derivative. Attribution and the GameBanana link stay in the file and in this doc. |

## Checklist

- [ ] The editor menu lists songs; choosing one starts that song with the editor open.
- [ ] Pressing **5** in a song started elsewhere still opens the editor after a restart.
- [ ] The editor menu reports `editor script FOUND` and `compatibility ON`.
- [ ] Exported modcharts appear under `mods/savedModcharts/`.
- [ ] Turning the switch off restores the normal engine version for all scripts.

## Windows handoff

Local verification covers the detector test, static checks and a Linux build only. Windows runtime checks belong to the user's friend:

1. `lime build windows -debug`.
2. Open **Editors → Modchart Editor** and confirm the song list is populated and the script is detected with compatibility on.
3. Select a song, press **ENTER**, confirm that song loads with the editor UI open immediately (no 5 press).
4. Create one strum action, use **Test**, then press **BACKSPACE** to return.
5. Save a modchart and confirm the generated file in `mods/savedModcharts/`.
6. Disable **Lua Compatibility**, restart the game and confirm other Lua scripts still work.

## Next step

If the script reports an incompatibility after these steps, record the exact error text and the engine build target before changing the shim version.
