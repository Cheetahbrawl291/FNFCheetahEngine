# V.Slice-style offset calibration — automatic note-offset + mod installation feature branch
Branch: feature/auto-offset-mod-install
Delivery: ask-on-risk (local work-unit commits only). Tests: scratch `haxe -cp <scratch> -main <Test> -neko ...` + `neko ...`; full check `haxelib run lime build Project.xml linux`.

## Specs
- S1: "podrias hacer que en el offset sea como el de v-slice? que aparece de fondo el del menu y en el offset sale una flecha en medio al cual cuando hay que precionar las flechas suben como si fueran de gameplay para tambien tener aplicable el offset de audio y de video"
- S2: Question "¿Querés que la calibración con flechas mida un SEGUNDO offset de video y lo aplique al render, o que siga siendo un solo offset con flechas visuales?" — answer "Dos offsets (recomendado)" / "Guardar audioOffset y videoOffset; el visual se aplica a las notas en pantalla. Cumple lo que pediste, pero toca ClientPrefs y PlayState: más alcance y riesgo."
- S3: Existing manual offset adjustment (left/right, hold, reset, ±500 ms) and combo-offset controls must keep working unchanged.
- S4: Automatic C/Y 8-tap audio calibration and `OffsetCalibrator` outlier rejection must keep working; add a separate video-offset calibration pass.
- S5: Deterministic tests for new pure timing math; README documentation; full Linux build exit 0.

## Tasks
- T1 — S2,S3 — Add `videoOffset` to `ClientPrefs.SaveVariables` and apply it only to visual note travel in `Note.followStrumNote` — route: inline — Risk: item 3 (shared note-rendering path used by all gameplay) — status: done — commit: pending
- T2 — S1,S2,S3,S4 — Rework `NoteOffsetState`: main-menu background, centered UP receptor arrow, user-colored rising notes only during calibration with one beat skipped between them, two-phase (audio then video) auto calibration, three manual modes, preserve combo UI — route: inline — Risk: none — status: done — commit: pending
- T3 — S1,S2,S4,S5 — Pure scroll-timing helper + 14 deterministic checks, README documentation, 36 focused checks total, full Linux build exit 0 — route: inline — Risk: none — status: done — commit: pending

## Log
- L1: "podrias hacer que en el offset sea como el de v-slice? que aparece de fondo el del menu y en el offset sale una flecha en medio al cual cuando hay que precionar las flechas suben como si fueran de gameplay para tambien tener aplicable el offset de audio y de video"
- L2: User selected "Dos offsets (recomendado)" for the offset-model question. Authorizes touching ClientPrefs and note rendering.
- L3: Evidence — `ClientPrefs.loadPrefs()` copies only fields present in the saved data, so adding `videoOffset` with default 0 is backward-compatible. `MainMenuConfig.load().bgImage` is the same background key `MainMenuState` uses. `Paths.getSparrowAtlas('noteSkins/NOTE_assets')` exposes `arrowUP0000` and `green0000`.
- L4: Calibration model — audio pass taps to the drum beat (measures output/perception latency → `noteOffset`); video pass taps when the rising arrow reaches the centered receptor (measures display latency → `videoOffset`). Both computed with `OffsetCalibrator.suggestOffset` against the same musical beat grid. Video pass mutes drums.
- L5: User added `assets/shared/music/offset/drumsLoop.ogg` and `offsetsLoop.ogg`. Both are 76.8 s = exactly 128 beats at 100 BPM (verified by onset autocorrelation and duration math), so `Conductor.bpm` is 100.0 and the loops are layered for calibration.
- L6: User feedback — receptor must be the UP arrow; rising notes must use the user's configured arrow colors (lane 2 via `Note.initializeGlobalRGBShader(2).shader`); notes appear only while calibrating; skip one beat between notes. Applied.
- L7: User reported `Invalid field:hudcustomization` crash when toggling Gameplay → Customization → "Enable?". Root cause: `options/CustomizationSubState.hx` references a pref that never existed since the initial commit. Fix: add `hudcustomization:Bool = false` to `SaveVariables`.
- L8: Verification — 14 CalibrationScroll checks + 10 OffsetCalibrator checks + 12 edge checks pass; `haxelib run lime build Project.xml linux` exit 0 after all edits. GUI verification was attempted locally but stopped at user request; the two GUI behaviors (offset screen visuals, Customization toggle) remain unverified at runtime.
- L9: The `odd/tasks/` directory was removed externally mid-session; this document was recreated with final status. The deletion of `odd/tasks/auto-offset-mod-install.md` is a pre-existing working-tree change and is intentionally not staged.
