# Modchart editor bridge for the external Lua script

Objective: replace the external-EXE stub with an opt-in Lua compatibility bridge so the GameBanana script can be used from this engine without bundling or modifying it.
Branch: `feature/modchart-editor-bridge`. Test runner: no automated suite; Haxe detector test in a scratch dir, structural checks and `lime build linux -debug` locally. Windows runtime checks by the user's friend.
Delivery strategy: `ask-on-risk` (local work-unit commits only; no publish).

## Specs

S1. Replace the current editor. Verbatim from the request:
   > "podrias cambiar el modchart editor actual por este: https://gamebanana.com/scripts/12931"
   Required: `ModChartEditorState` stops trying to launch an external `.exe` and becomes the entry point for the GameBanana "LUA Modchart Editor" v1.2.2 script. The original external-only constraint was superseded by L12; the script is now bundled verbatim.

S2. Chosen route, superseded by L12. Verbatim from the selected answer:
   > "Bridge, script externo"
   Verbatim from the option description:
   > "Agrego compatibilidad Lua controlada (runHaxeCode, addHaxeLibrary, game, version) y cambio el menú para usar el .lua que tú descargas de GameBanana. No redistribuyo el script ni lo modifico; respeta ND. Toca Safe Mode y necesita prueba en Windows."
   Required: only a Lua file whose own source identifies it as the `.bakugo` / CommanderVideo LUA Modchart Editor gets the compatibility version override. L12 grants permission to bundle it and asks to "just add it", so the bundled copy is shipped byte-for-byte and the shim is on by default (still user-disableable). Safe Mode and other scripts stay unchanged.

S3. Verification owner. Verbatim from the request:
   > "tranquilo, los test de windows los hace un amigo"
   Required: local work stops at detector test, structural checks and Linux build. Windows build/runtime probes are the friend's and are documented in a handoff.

S4. Assumption (not requested verbatim): the engine is a Psych fork with `version = '0.0.1'`, while the script branches on Psych versions `> 0.6.3`, `> 0.7.1h`, `> 0.7.2`, `> 0.7.3`. The bridge must expose `'1.0.4'` to that script only. Lua already receives `runHaxeCode`/`addHaxeLibrary` through `HScript.implement(this)` (`FunkinLua.hx:1561`), so no new execution API is needed.

S5. License note. The source page states CC BY-NC-ND 4.0. L12 asserts permission to use the editor in the game, so the script is vendored verbatim with its original header and author links intact. The docs keep the attribution and license note; no derivative of the script is created.

## Tasks

- [x] T1 Detector, pref and options UI. Specs: S1, S2, S4, S5. Route: inline. Commit `d8af7ff`.
- [x] T2 Editor menu state and SONG memory field. Specs: S1, S2. Route: inline. Commit `d037c6d`.
- [x] T3 Documentation and README link. Specs: S1-S3, S5. Route: inline. Commit `d037c6d`.
- [x] T4 Verification and Windows handoff. Specs: S3. Route: inline. Local checks observed in L9; Windows runtime checks remain with the friend.
- [x] T5 Bundle the script verbatim and enable the shim by default. Specs: S1, S2, S5. Route: inline. Reopened by L12. Commit `7566036`.

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

L9. T4 verification, all observed locally: detector test 8/8 PASS in an isolated scratch copy (`ModchartEditorDetectorTest.hx` at line 15); structural checks confirmed no EXE launcher or hard-coded developer path in the editor state, the new options entry and pref exist, and the handoff section exists; `lime build linux -debug` exited 0 with `BUILD_LINUX_OK`. The second work-unit commit is `d037c6d`. RDD assess over `ca9754c..d037c6d` with the canonical untracked inventory declared returned `risk: medium`, `review_due: false`, `review_due_reason: under_budget`; no native review cycle. Windows build/runtime probes are explicitly delegated to the friend in `docs/MODCHART_EDITOR.md` and remain pending.

L10. Outcome per spec: S1 met (EXE stub replaced), S2 met (opt-in, source-scoped, script not bundled), S3 deferred to the Windows owner with a written checklist, S4/S5 met (engine evidence and license constraint recorded). No push, PR or merge was requested. Evidence commit: `51ae8f5`.

L11. User request, verbatim: "puedes quitar el ejecutable ModChartEditor.exe". Verified a tracked 38 MB binary at `ModChartEditor/ModChartEditor.exe`, the only file in that folder, with no remaining code reference (only historical ODD log prose). Removed with `git rm` in `2638a53`. RDD assess over `ca9754c..2638a53` returned `risk: medium`, `review_due: false`, `review_due_reason: under_budget`; no native review cycle. No rebuild needed: the binary was not part of any build input.

L12. Requirement change, verbatim: "porsierto tengo permiso de usar el modchart editor al juego, solo añadelo". This supersedes the external-only route in S2/S5: the user grants permission to ship the editor with the game and asks to just add it. Affected specs S1, S2, S5 are rewritten above; T5 is opened. The script must be copied byte-for-byte from the earlier API extraction, with its header and author links intact, into `assets/shared/scripts/` so `PlayState.hx:437-443` loads it in every song. The version shim must be active by default or the bundled script sees `0.0.1` and takes the broken legacy path.

L13. T5 implementation and verification, all observed: copied the 118 KB script to `assets/shared/scripts/ModchartEditor.lua`; the user later supplied `/home/dante/Descargas/LUA Modchart Editor.text` and it is byte-identical (SHA256 `0a4035d2ee605556a409c3cc0994349006af717f5238020a95bff0a9cebe0d98`), confirming the API extraction was correct. The `.text` extension is only a download artifact; the engine loads `.lua`. `modchartEditorCompat` now defaults to `true`, the option text and both docs describe the bundled script, and the editor state reports FOUND with the install path. Detector test 8/8 PASS; structural checks PASS; `lime build linux -debug` exited 0; the exported copy has the exact SHA256 above. Script was not modified.

L14. Git normalization gotcha, non-obvious: the first bundle commit normalized the script's CRLF to LF because `.gitattributes` has `* text=auto`, producing blob `b034f569...` instead of the source hash. Added `assets/shared/scripts/ModchartEditor.lua -text` to `.gitattributes`, recopied the original bytes and amended the commit; the committed blob now matches SHA256 `0a4035d2...` exactly. This is required to keep the CC BY-NC-ND file unmodified in the repository.

L15. The Linux engine launched earlier (PID 146332) ended with `Exit code: 135 (SIGBUS)` after the rebuild replaced its running binary and assets. That is a rebuild-while-running artifact, not a game bug; the engine must be relaunched after the final build. Unrelated worktree changes observed after the build: `docs/img/CheetahEngineLogo.png` deleted and `docs/img/2026_10_24_0tt_Kleki.png` added, byte-identical (SHA256 `25be96c1...`), i.e. a rename by another actor. Left untouched and excluded from this feature's commits.
