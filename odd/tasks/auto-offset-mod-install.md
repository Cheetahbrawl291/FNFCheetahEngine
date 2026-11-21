# Auto offset calibration + smarter mod installation

Branch: `feature/auto-offset-mod-install` (branched from `feature/modchart-editor-bridge`). Delivery: work-unit commits; tests and docs alongside behavior. Test runner: scratch `haxe -cp <scratch> -main <Test> -neko <scratch>/test.n && neko <scratch>/test.n`, plus a full `haxelib run lime build Project.xml linux` check.

## Specs

**S1** — User request (verbatim fragment): "eso de calibracion automatica de offset"
- Add automatic note-offset calibration. A pure helper computes a suggested offset from player taps against a known beat grid; the existing offset screen exposes it, applies the result, and shows the measured value.
- Manual offset adjustment and combo-offset behavior must keep working unchanged.
- Checks: deterministic helper test (RED before implementation, GREEN after); focused compile/build check.

**S2** — User request (verbatim fragment): "algunos mods al extraerlos traen otra carpeta dentro que esa si es el mod, quiero que detecte eso para ponerla bien y detecqute si no trea el mod (como los que no tienen el mod en gamebanana si no en google drive) y te diga que el mod se tiene que instalar a manos porque esta en google drive"
- Detect the real mod folder inside nested archive wrappers and install that folder at `mods/<name>/`.
- Detect archives with no Psych mod content and report that the mod must be installed manually.
- Detect GameBanana entries whose download is external (Google Drive and similar) and report that the mod must be downloaded and installed manually.
- Existing `mods/` prefix stripping, zip-slip rejection, junk skipping, unique folder naming and 400 MB cap must keep working unchanged.
- Checks: deterministic archive-inspector test (RED before implementation, GREEN after); focused compile/build check.

**S3** — User request (verbatim fragment): "que detecte si el mod de psych engine es compatible con la vercion de psych engine en la que se basa este motor"
- Read a mod's declared Psych Engine version from `pack.json` when present, compare it against this engine's Psych base version, and surface a clear compatible / incompatible / unknown result to the player.
- Base version is Psych Engine `1.0.4` (decision recorded in Log). Missing declaration means "unknown", never "incompatible".
- Incompatible is a warning, not a hard block: the mod still installs, because declarations can be stale.
- Checks: deterministic version-comparison test (RED before implementation, GREEN after); focused compile/build check.

## Tasks

- T1 | S1 | inline | tests GREEN, build passed | `OffsetCalibratorTest` RED (type not found) → GREEN (11 PASS); `NoteOffsetState` integration | Risk: none (new opt-in UI path, no shared scoring or persisted format change) | commit: `4f50af1`
- T2 | S2 | inline | tests GREEN, build passed | `ModArchiveInspectorTest` RED (type not found) → GREEN (21 PASS), `ModInstallTest` 7 PASS; `ModBrowser` integration | Risk: item 1 (existing install path selects the folder that becomes persisted mod data) | commit: `e82f6f7`
- T3 | S3 | inline | tests GREEN, build passed | version probes in `ModArchiveInspectorTest`; `ModBrowserState` notice | Risk: none (additive warning, no install behavior change) | commit: `e82f6f7`

## Log

**L1** — Original request (verbatim):
"si, estaria bueno eso de calibracion automatica de offset y algunos mods al extraerlos traen otra carpeta dentro que esa si es el mod, quiero que detecte eso para ponerla bien y detecqute si no trea el mod (como los que no tienen el mod en gamebanana si no en google drive) y te diga que el mod se tiene que instalar a manos porque esta en google drive, y que detecte si el mod de psych engine es compatible con la vercion de psych engine en la que se basa este motor"

**L2** — Base-version investigation. User answered "no se, revisala". Compared local `Project.xml` with upstream Psych tags: local matches `1.0.4` (hscript-iris 1.1.3, hxvlc 2.0.1, IRIS_DEBUG, TRANSLATIONS_ALLOWED, noteGroup/modern APIs); `0.7.3` uses SScript/hxCodec and library tags. `assets/meta/...metainfo.xml` release `0.7.3` is stale packaging metadata. Decision: base = Psych Engine 1.0.4. `MainMenuState.psychEngineVersion` stays `0.0.1` (Cheetah's own displayed version), so the new detector must use an explicit base constant, not that field.

**L3** — Route: all three tasks inline. No writer trigger (sequential, dependent work, one behavior at a time); no explorer needed after bounded reads of `ModBrowser.hx`, `Mods.hx`, `NoteOffsetState.hx` and the test files. High-risk item named in T2 because extraction chooses persisted mod data; T1/T3 additive. Delivery strategy `ask-on-risk`; no publishing in this scope.

**L4** — Implementation evidence. `OffsetCalibrator` is pure Haxe: median of tap-to-nearest-beat deltas, outlier rejection, clamp to ±500 ms; RED was missing type, GREEN ran 11 PASS. `NoteOffsetState` adds opt-in C/Y auto calibration with 8 taps and saves the applied offset through `ClientPrefs.saveSettings()`; manual left/right, combo offsets and Accept switch are guarded, not replaced. `ModArchiveInspector` chooses nested mod roots via `pack.json` or mod-marker folders, detects external hosts, and compares explicit Psych version declarations against base 1.0.4 by major.minor; RED was missing type, GREEN ran 21 PASS. `ModBrowser` now reports manual-install messages for external hosts and archives without mod content, and passes a compatibility notice through `ModTask` to `ModBrowserState`. Generic `version` in `pack.json` is deliberately not treated as a Psych version (mods use it for their own version). Incompatible is a warning; install still proceeds. Full Linux build (`haxelib run lime build Project.xml linux`) finished `EXIT=0`; the resulting `export/release/linux/bin/PsychEngine` was launched with the changes (PID 242679, clean startup log). Native risk assessment per work unit: `medium`, `review_due: false`, reason `under_budget` (untracked `.atl/` and `odd/` excluded by declared inventory). Independent verifier launched for T2's named high-risk item.
