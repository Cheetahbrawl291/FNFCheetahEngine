# Cheetah Engine Options — new options submenu
Branch: feature/auto-offset-mod-install
Delivery: ask-on-risk (local work-unit commits only). Tests: scratch `haxe -cp <scratch> -main <Test> -neko ...` + `neko ...`; full check `haxelib run lime build Project.xml linux`.
Baseline for this feature: `a6ef51d`.

## Specs
- S1: "podrias añadie al menu de opciones un cheetah engine options que te permite reiniciar y quitar el main menu custom, desactivar eventos de windows api y que puedas activar la unificacion de erect mixes y canciones normales"
- S2: "puedes hacerlo tu" — user authorizes autonomous implementation without further questions.
- S3: New `Cheetah Engine Options` entry in OptionsState opens a substate with exactly three controls: (a) reset custom main menu, (b) master switch to disable Windows API events, (c) toggle erect-mix unification.
- S4: Reset custom main menu deletes both `mainmenu.json` and `menu_custom.json` for the current mod and the global mods folder (safe no-ops when absent); `load()` already falls back to defaults when files are missing. Destructive action needs on-screen confirmation before deleting.
- S5: Windows API master switch (`winApiEvents`, default true to preserve current behavior) gates every Windows API chart event at the PlayState dispatch choke point, covering both already-gated desktop effects and currently ungated cosmetic ones. Exit cleanup `restoreAll()` stays active regardless so the desktop is never left altered.
- S6: Erect unification toggle (`erectMixUnification`, default true to preserve current behavior) gates BOTH the `erectFolders` population and the `isErectName` skip in FreeplayState, so turning it off restores erect mixes as ordinary standalone songs instead of making them vanish.
- S7: No regression in existing options menus, event dispatch, or Freeplay behavior when both new prefs hold their defaults. Full Linux build exit 0.

## Tasks
- T1 — S1,S2,S3,S4 — New `CheetahOptionsSubState` + OptionsState wiring + main-menu reset helper with confirmation — route: inline — Risk: none — status: done — commit: `14590dd`
- T2 — S1,S5 — Windows API master gate in ClientPrefs + PlayState dispatch — route: inline — Risk: item 3 (shared event dispatch used by all charts) — status: done — commit: `fa4c17f`
- T3 — S1,S6 — Erect unification gate in ClientPrefs + FreeplayState — route: inline — Risk: item 3 (shared Freeplay song loading) — status: done — commit: `fe2dd8a`
- T4 — S7 — Pure tests for reset target resolution + erect gate decisions, focused suites, full build, README/docs — route: inline — Risk: none — status: done — commit: `6a246cf`

## Log
- L1: "podrias añadie al menu de opciones un cheetah engine options que te permite reiniciar y quitar el main menu custom, desactivar eventos de windows api y que puedas activar la unificacion de erect mixes y canciones normales"
- L2: "puedes hacerlo tu" — user explicitly authorizes autonomous implementation.
- L3: Evidence — `Option` has no ACTION type; `onChange` fires on BOOL ACCEPT and on INT/FLOAT/PERCENT change. `BaseOptionsMenu` draws a `CheckboxThingie` for BOOL and an `AttachedText` otherwise. Existing `onChange` callbacks are the established pattern for side effects.
- L4: Evidence — `MainMenuConfig.path()` → `mods/<mod>/data/mainmenu.json` or `mods/data/mainmenu.json`; `MenuCustomization.path()` → `mods/<mod>/data/menu_custom.json` or `mods/data/menu_custom.json`. Both `load()` start from `getDefault()` when the file is absent, so deletion is a clean reset. No delete helper exists in either class.
- L5: Evidence — `WindowsIntegrations.allowed()` gates only 5 desktop-touching event families; 6 cosmetic window events call `WindowsAPI.*` directly. PlayState `eventCalled` switch (lines ~2320-2343) is the single choke point for all of them. `restoreAll()` at exit calls `resetWindowsFuncs()` regardless of prefs.
- L6: Evidence — `FreeplayState` (lines ~96-113) fills `erectFolders` unconditionally; line ~132 skips erect names from the regular list unconditionally. Those two sites must be gated together or erect songs disappear entirely when unification is off.
- L7: User is on Linux; Windows API code is `#if windows`. The new menu entry stays visible on all platforms but the Windows API option is shown as unavailable/gated on non-Windows builds (no compile error).
- L8: Evidence — `SaveVariables` is `@:structInit` and both `data`/`defaultData` initialize as `{}`, so all declared field defaults apply. `loadPrefs()` only overwrites fields present in the save, so the three new prefs are backward-compatible and their defaults hold for old saves. Verified at `ClientPrefs.hx:10,114-115,204-210`.
- L9: Design — reset is a momentary BOOL whose `onChange` immediately restores the flag to false, then opens `states.editors.content.Prompt` for confirmation. `MenuReset.configPaths()` is a pure helper so the path rules are testable without Flixel.
- L10: Design — Windows gate uses Haxe `case ... if(ClientPrefs.data.winApiEvents):` guards on all 12 Windows event cases; no `default:` clause exists in that switch, so a false gate is a clean no-op. Guard semantics verified with a standalone probe (`off => called=false`, `on => called=true`). `#if windows` block is not compiled by the Linux build; this is a residual verification gap on this host.
- L11: Design — added pure `ErectRemix.hideFromFreeplay(unification, name)` used by FreeplayState so the two-site gate has one testable decision function.
- L12: Verification — `MenuResetTest` 9 PASS; `ErectRemixTest` 26 PASS (21 existing + 5 new gate checks, compiled with `-D MODS_ALLOWED`); `haxelib run lime build Project.xml linux` exit 0 with no errors. GUI/runtime behavior not verified (user declined remote/GUI access).
- L13: Fix — `ErectRemixTest` needed `-D MODS_ALLOWED` in its scratch compile header because the non-mods branch references `openfl.utils.Assets`, unavailable in the scratch classpath.
