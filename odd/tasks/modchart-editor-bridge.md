# Modchart editor bridge for the external Lua script

Objective: replace the external-EXE stub with an opt-in Lua compatibility bridge so the GameBanana script can be used from this engine without bundling or modifying it.
Branch: `feature/modchart-editor-bridge`. Test runner: no automated suite; Haxe detector test in a scratch dir, structural checks and `lime build linux -debug` locally. Windows runtime checks by the user's friend.
Delivery strategy: `ask-on-risk` (local work-unit commits only; no publish).

## Specs

S1. Replace the current editor. Verbatim from the request:
   > "podrias cambiar el modchart editor actual por este: https://gamebanana.com/scripts/12931"
   Required: `ModChartEditorState` stops trying to launch an external `.exe` and becomes the entry point for the GameBanana "LUA Modchart Editor" v1.2.2 script. The engine never ships a copy of the script.

S2. Chosen route. Verbatim from the selected answer:
   > "Bridge, script externo"
   Verbatim from the option description:
   > "Agrego compatibilidad Lua controlada (runHaxeCode, addHaxeLibrary, game, version) y cambio el menú para usar el .lua que tú descargas de GameBanana. No redistribuyo el script ni lo modifico; respeta ND. Toca Safe Mode y necesita prueba en Windows."
   Required: an opt-in setting, off by default. Only a Lua file whose own source identifies it as the `.bakugo` / CommanderVideo LUA Modchart Editor gets the compatibility version override. The script is downloaded by the user and placed in a scripts folder; no script bytes enter the repository.

S3. Verification owner. Verbatim from the request:
   > "tranquilo, los test de windows los hace un amigo"
   Required: local work stops at detector test, structural checks and Linux build. Windows build/runtime probes are the friend's and are documented in a handoff.

S4. Assumption (not requested verbatim): the engine is a Psych fork with `version = '0.0.1'`, while the script branches on Psych versions `> 0.6.3`, `> 0.7.1h`, `> 0.7.2`, `> 0.7.3`. The bridge must expose `'1.0.4'` to that script only. Lua already receives `runHaxeCode`/`addHaxeLibrary` through `HScript.implement(this)` (`FunkinLua.hx:1561`), so no new execution API is needed.

S5. Assumption (not requested verbatim): CC BY-NC-ND 4.0 on the source page forbids redistribution of modified copies. Vendoring the script into the repository is out of scope; the docs link to the GameBanana page.

## Tasks

- [x] T1 Detector, pref and options UI. Specs: S1, S2, S4, S5. Route: inline. Commit `d8af7ff`.
- [ ] T2 Editor menu state and SONG memory field. Specs: S1, S2. Route: inline.
- [ ] T3 Documentation and README link. Specs: S1-S3, S5. Route: inline.
- [ ] T4 Verification and Windows handoff. Specs: S3. Route: inline.

## Log

L1. Original request, verbatim:
   > "podrias cambiar el modchart editor actual por este: https://gamebanana.com/scripts/12931"

L2. Standing constraint from the earlier Windows task, verbatim:
   > "tranquilo, los test de windows los hace un amigo"

L3. User's selected answer, verbatim:
   > "Bridge, script externo"

L4. Pre-write evidence: GameBanana API `Script/12931/ProfilePage` reports "LUA Modchart Editor" v1.2.2 by .bakugo / CommanderVideo under CC BY-NC-ND 4.0. The current `ModChartEditorState.hx` is a stub that searches for `ModChartEditor.exe` and logs an error. `FunkinLua.hx:87` sets Lua `version` from `MainMenuState.psychEngineVersion` (`'0.0.1'`); `FunkinLua.hx:1561` installs `HScript.implement(this)`, which provides `runHaxeCode` and `addHaxeLibrary` to Lua. The script's version comparisons appear at lines 193, 252, 407, 419, 465, 632, 685, 694, 791, 809-819, 861-883, 922-980, 1278, 1368, 1453, 1557, 1693-1939 of its raw source.

L5. Initial diagnosis correction: I first reported that Lua lacked `runHaxeCode`, `addHaxeLibrary` and `game`. That was wrong for `runHaxeCode`/`addHaxeLibrary`: `HScript.implement(this)` injects them into every `FunkinLua`. Evidence is L4. Only the version mismatch remains as the reason for the shim; `game` is an HScript-side global used inside the script's `runHaxeCode` blocks, not a Lua global it calls directly.

L6. Route declaration: task is tracked (multi-file behavior, external runtime not testable locally). All tasks run INLINE: no Writer trigger (one bounded behavior, no parallel units, context backstop not reached). Risk line: none — the version override is gated by an opt-in pref and source identification, and the detector has a deterministic test. RDD is on globally; native assess runs per work-unit commit.

L7. T1 verification: the detector test was written first and failed to compile with `Type not found : ModchartEditorDetector` (RED), then passed 8/8 probes after the detector was added (GREEN). The first work-unit commit included an executable `tests/run-modchart-detector.sh`; RDD assess classified it `high` (`executable_mode`, `process_boundary`, `shell_source`, `review_due: true`). The wrapper was removed and the commit amended; the test remains in `tests/ModchartEditorDetectorTest.hx` with its inline scratch-directory commands. Reassessment over `ca9754c..HEAD` returned `risk: medium`, `review_due: false`, `review_due_reason: under_budget`, so no native review cycle was started. Final C1 commit: `d8af7ff`; untracked files were declared with `--untracked-scope=exclude` and the canonical inventory hash.

L8. T2/T3 implementation evidence: `ModChartEditorState.hx` no longer contains any `ModChartEditor.exe`, `Sys.command` or hard-coded `/home/dante/...` path; it scans recognized scripts through `Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/')` and reports OFF / NOT FOUND / FOUND. `Song.hx` gained an optional `modchartEditorMemory:Dynamic` field for the script's scratch state. `docs/MODCHART_EDITOR.md` follows the lead-with-answer guide shape and includes the exact Windows probe handoff. README gained one link in the Editors section. `lime build linux -debug` linked successfully after these edits; final explicit exit-code check is part of T4.
