# Modchart editor song selection

Objective: entering the Modchart Editor asks which song to edit and starts that song with the bundled Lua editor already active.
Branch: `feature/modchart-editor-bridge` (continues the bundled editor work). Test runner: no automated suite; structural checks and `lime build linux -debug` locally. Windows runtime checks by the user's friend.
Delivery strategy: `ask-on-risk` (local work-unit commits only; no publish).

## Specs

S1. Ask for a song. Verbatim from the request:
   > "puedes hacer que al entrar al modchart editor te pregunte que cancion quieres editar y luego te abre el modchart editor con esa cancion?"
   Required: `ModChartEditorState` presents a song choice instead of only showing instructions. Selection must be possible with the engine's normal keyboard controls.

S2. Open the editor on the chosen song. Verbatim from the same request:
   > "luego te abre el modchart editor con esa cancion"
   Required: choosing a song starts that song with the bundled script active immediately, without requiring the player to press 5.

S3. Assumption (not requested verbatim): the bundled script reads `PlayState.SONG.modchartEditorMemory.active` in `initMemory()` (`assets/shared/scripts/ModchartEditor.lua:649-660`) and skips the "press 5" tooltip branch when it is true (`:701-740`). The engine already has the optional `modchartEditorMemory:Dynamic` field on `SwagSong`. No script bytes are changed.

S4. Standing verification constraint, verbatim from the earlier task:
   > "tranquilo, los test de windows los hace un amigo"
   Required: local work stops at structural checks and a Linux build; Windows build/runtime probes are documented for the friend.

S5. License constraint carried over: the script stays verbatim and CC BY-NC-ND 4.0. This change touches only engine code around it.

## Tasks

- [x] T1 Song picker UI in `ModChartEditorState`. Specs: S1, S5. Route: inline. Commit: `47e7c75`.
- [x] T2 Launch the chosen song with the editor active. Specs: S2, S3. Route: inline. Commit: `47e7c75`.
- [x] T3 Documentation update. Specs: S1-S4. Route: inline. Commit: `47e7c75`.
- [x] T4 Verification and Windows handoff (local proof observed; Windows probes delegated). Specs: S4. Route: inline. Commit: `47e7c75`.

## Log

L1. Original request, verbatim:
   > "puedes hacer que al entrar al modchart editor te pregunte que cancion quieres editar y luego te abre el modchart editor con esa cancion?"

L2. Pre-write evidence: the bundled script stores `editor_memory` in `PlayState.SONG.modchartEditorMemory` via `flushMemory()` (`assets/shared/scripts/ModchartEditor.lua:660-663`) and reads it in `initMemory()` (`:649-657`). When `editor_memory.active` is false it installs an `onUpdate()` that waits for `keyboardJustPressed('FIVE')`, sets `active = true`, flushes and calls `restartSong()` (`:701-740`). Setting the field before `PlayState` loads should make the editor open on the first run of the chosen song.

L3. Route declaration: tracked task (new UI plus startup flow, external runtime not testable locally). All tasks run INLINE: no Writer trigger (one bounded behavior, no parallel units, context backstop not reached). Risk line: none — the change is confined to the editor entry state and an optional scratch field already present. A read-only explorer mapped the existing song-enumeration and play-start APIs before the first write. RDD is on globally; native assess runs per work-unit commit.

L4. Explorer handoff (read-only, `gentle-ai-explore`): song list from `WeekData.reloadWeekFiles(false)` → `weeksList` → `weeksLoaded.get(w).songs[i][0]` (`WeekData.hx:74-138`, `FreeplayState.hx:87-111`); canonical start sequence at `FreeplayState.hx:418-465` (`Song.loadFromJson`, `PlayState.isStoryMode=false`, `LoadingState.prepareToSong()`, `LoadingState.loadAndSwitchState(new PlayState())`, `FreeplayState.destroyFreeplayVocals()`); simplest picker pattern at `MasterEditorMenu.hx:48-58,141-155`. `PlayState.create()` reads but never overwrites `SONG`. The explorer was not frozen; it completed and returned this handoff after a follow-up nudge.

L5. Implementation: `ModChartEditorState` replaced its instruction-only screen with a `FlxTypedGroup<Alphabet>` song picker (UP/DOWN + ENTER, BACK to `MasterEditorMenu`). `buildSongList()` dedupes song names across all freeplay weeks and keeps each `WeekData` for mod-directory selection. `startEditor()` validates the Normal chart with `Song.getChart(songId, songId)` before `Song.loadFromJson` (which calls `StageData.loadDirectory` unconditionally), sets `PlayState.SONG.modchartEditorMemory = {active: true, showedTooltip: true}`, then starts `PlayState`. Initial compile failed with `Type not found : Song`; adding `import backend.Song` fixed it.

L6. Verification, all observed locally: `lime build linux -debug` exited 0 (`BUILD_LINUX_OK`); detector regression 8/8 PASS with exit 0 in an isolated scratch copy (`tests/ModchartEditorDetectorTest.hx`); structural checks found no EXE/dev-path/stale instruction references and confirmed every required marker (`reloadWeekFiles`, `modchartEditorMemory`, `active: true`, `loadFromJson`, `loadAndSwitchState`, controls); bundled script SHA256 still `0a4035d2ee605556a409c3cc0994349006af717f5238020a95bff0a9cebe0d98`, byte-identical to the user-supplied source. Script flow re-read: `active=true` skips the tooltip branch at `ModchartEditor.lua:708-741`; the `active=false` at `:783` is never read again for UI gating (only refs: 708, 734, 736, 783). Test-first exception: no runnable deterministic test exists for FlxState UI/startup flow and the change does not touch the detector, so RED→GREEN is not applicable here; the detector suite was run as regression, not as new coverage.

L7. Scope boundary: `README.md`, `docs/img/`, and `.atl/` contain pre-existing unrelated worktree changes and were left untouched. Windows build/runtime probes stay delegated to the user's friend per S4; the handoff checklist in `docs/MODCHART_EDITOR.md` was updated with the song-picker steps.

L8. Delivery: single work-unit commit `47e7c75` (`feat(modchart): pick song before opening Lua editor`), 3 files, 205 insertions / 31 deletions, no publish. RDD assess `--base-ref 0f2fcdf --committed-only --untracked-scope exclude --expected-untracked-inventory sha256:41e17cbe...`: `risk: medium`, `risk code: executable_change`, `review_due: false`, `review_due_reason: under_budget`. No native review cycle started. Feature complete locally; only the friend's Windows probes remain.

L9. Linux runtime evidence (interactive session on the freshly built binary, log `/tmp/opencode/engine-song-select.log`): the `dorito` run has NO `Modchart Editor: Press 5 to open` line but DOES show `initializing haxe interp for: assets/shared/scripts/ModchartEditor.lua` plus editor actions (`Test: You must select a strum to test the modchart!`, `Load: No .lua or data .txt for NewModchart...`, `Reset: Strum data in this modchart has been cleared`) — that is the picker path with `{active: true, showedTooltip: true}`. Songs entered later through Freeplay (`2hot`, `stress`, `milf`) still print `Modchart Editor: Press 5 to open`, so the original path is unchanged. No `checking for updates...` trace. The process exited cleanly (no SIGBUS, no crash). Runtime logs are ephemeral and were not committed.
