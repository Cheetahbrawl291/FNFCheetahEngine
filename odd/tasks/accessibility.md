# Accessibility settings (item 6)

Objective: give the engine real accessibility options instead of only `flashing`.
Branch: `main` (feature work committed as work units).
Test runner: `lime build linux -debug` (no automated test suite in this repo); checks are compile + manual runtime probes.
Scope owner: item 6 of the wishlist only. Items 1-5, 7-12 stay out of this document.

## Specs

S1. A dedicated `Accessibility` submenu must exist in Options, next to Graphics / Visuals / Gameplay.

S2. Colorblind-safe palette. Verbatim from the request:
   > "colorblind-safe palette"
   Required: a `colorblindMode` preference with `Off` plus presets, applied to lane colors so arrows, strums and note splashes stay distinguishable for the supported deficiencies. `Off` must keep today's behaviour (`arrowRGB` / `arrowRGBPixel`, user-customizable via Note Colors).

S3. Reduced camera shake. Verbatim from the request:
   > "reduced camera shake"
   Required: a `reduceMotion` preference. While enabled, every gameplay camera shake (event `Camera Shake`, Lua `cameraShake`, stage-specific shakes) is damped instead of played at full intensity. Stage scripts must not be able to bypass it.

S4. Text size. Verbatim from the request:
   > "text size"
   Required: a `textScale` preference that grows the sprite-font (`Alphabet`) text used by menus and dialogue. Default `1.0`. Explicit per-instance `setScale` calls still win.

S5. Dialogue subtitles. Verbatim from the request:
   > "dialogue subtitles"
   Status: BLOCKED on a product decision. The song dialogue box (`DialogueBoxPsych`) already renders every line as text, so "subtitles" only adds value for cutscene videos (`.mp4` via hxvlc). Open question for the user before any write.

S6. Every new preference must persist through `ClientPrefs.saveSettings()` / `loadPrefs()` without touching existing saves.

## Tasks

- [x] T1 `ClientPrefs` fields + `backend/Accessibility.hx` helper (palettes, shake, text scale). Spec: S1, S2, S3, S4, S6.
- [x] T2 Apply palette at every lane-color read site (`Note`, `StrumNote`, `NoteSplash`). Spec: S2.
- [x] T3 Route every shake call through the helper (`PlayState`, `FunkinLua`, stage handlers). Spec: S3.
- [x] T4 Text scale in `Alphabet` construction. Spec: S4.
- [x] T5 `options/AccessibilitySubState.hx` + register in `OptionsState`. Spec: S1, S2, S3, S4.
- [ ] T6 Dialogue subtitles for cutscene videos. Spec: S5. Blocked on decision.
- [x] T7 Compile check `lime build linux -debug`. Spec: all.

## Log

L1 (user, verbatim, 2026-10-25):

> me gustaria añadir todo esto al motor: Hey <@1496675995271561236>, I have a couple of ideas for the engine:
>
> 1. Search function in FreePlay (being able to search by name, week, etc.)
>
> 2. Assisted offset calibration: we only have manual noteOffset in preferences. But something like Rift of the NecroDancer, which calibrates the screen and input.
>
> 3. Note/splash pooling + atlas cache — recycle sprites instead of creating/destroying them per note. Dense charts improve. Measurable with FPS.
>
> 4. Results screen: not much to say here, it's just a results screen.
>
> 5. Hit error bar (timing meter)
>
> 6. Real accessibility. colorblind, accessibility, reduceMotion → (it took me a while to find that arrow XD) all empty grep. We only have toggle flashing. Missing features: colorblind-safe palette, reduced camera shake, text size, and dialogue subtitles. This sets us apart because almost no other fork does it, or at least not that I can see in the engine.
>
> 7. Song preview in Freeplay. The preview only exists in editors. The ability to listen for 10 seconds on hover without entering the song.
>
> 8. Practice loop A/B — `loopStart`/`loopEnd` is empty. Pause → mark start/end → loop the section without restarting the song. With `Skip Time`, we've already done half the work.
>
> 9. Achievements per mod — `Achievements.hx` hardcodes them. No `registerAchievement`. A mod cannot add achievements even if `ACHIEVEMENTS_ALLOWED` is enabled.
>
> 10. Import of external charts — doesn't exist: custom lua/json and nothing else. .osu, StepMania .sm, or the V-Slice .json file. It would turn your engine into a receiver for external charts.
>
> 11. DANGEROUS! Script sandbox — Lua/HScript have full access to the filesystem. A GameBanana mod can delete your files. No sandbox, no allowlist, no user warning.
>
> 12. Improved volume system: We could improve the game's volume system to be like osu!, where the wheel lowers the overall volume and appears on the left, and from the left, you use the wheel to control whether you lower the volume of sound effects, music, and/or the overall volume.

L2 (user decision, 2026-10-25): starting order is item 6, accessibility.

L3 (evidence, 2026-10-25): verified claims against the code before writing.
- `grep -ri "colorblind|reduceMotion|accessibility"` over `source/` returns nothing; only `ClientPrefs.data.flashing` exists.
- Lane colors are read in 5 places: `objects/Note.hx:176` and `:334`, `objects/StrumNote.hx:35`, `objects/NoteSplash.hx:238`. All read `ClientPrefs.data.arrowRGB` / `arrowRGBPixel` directly, so a single helper can centralize the palette.
- 12 `.shake(` call sites: `states/PlayState.hx:2181`, `psychlua/FunkinLua.hx:838`, and 10 across `DarnellBlazinHandler.hx` / `PicoBlazinHandler.hx`.
- `Alphabet` (sprite font) is what menus and dialogue use; `AttachedText` calls `setScale` explicitly after construction, so it must keep winning over the global scale.
- `Note.globalRgbShaders` is a static cache keyed by lane; it must be invalidated when the palette changes.

L4 (assumption, 2026-10-25): S5 is ambiguous — the dialogue box already renders text. Assumed it means subtitles for video cutscenes; blocked pending confirmation instead of guessing.
