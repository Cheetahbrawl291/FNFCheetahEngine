# Editor updates (menu hub trim + achievement editor)

Objective: trim the Menu Customization Hub to the Main Menu editor, and add a custom achievement editor reachable from debug key 7.
Branch: `main` (uncommitted work, same tree as the accessibility feature).
Test runner: `lime build linux -debug` (no automated test suite in this repo); checks are compile + manual runtime probes.

## Specs

S1. Menu hub trim. Verbatim from the request:
   > "puedes en el menu de edicion de menus quitar todos y solo dejar el de main menu"
   Required: `MenuHubEditorState` lists only `Main Menu`; the Story Mode / Freeplay / Options / Credits entries and their `MainMenuEditorState.currentMenu` assignments are removed.

S2. Achievement editor reachable from debug key 7. Verbatim from the request:
   > "tambien quiero que añadas en la tecla 7 la opcion de edicion de logros"
   Required: `MasterEditorMenu` (opened by `debug_1`, key 7, from the main menu) offers an `Achievement Editor` entry that opens the new editor state.

S3. Create custom achievements. Verbatim from the request:
   > "que te permita crear, modificar y/o quitar logros custom"
   Required: a form with save key, display name, description, hidden flag, max score and max decimals. The save key must be unique and limited to `[A-Za-z0-9_-]`; built-in achievements must not be overwritten.

S4. Modify and remove custom achievements. Same verbatim request as S3.
   Required: selecting a custom achievement loads it into the form; saving updates it in place (keeping its ID, unlocked state and score); renaming a save key carries the score/unlock state over; deleting asks for confirmation. Built-in achievements are never listed, so they can never be modified or deleted from this editor.

S5. Persistence. Custom achievements must survive a restart while leaving mod `data/achievements.json` files untouched. They are stored in the save file (`FlxG.save.data.customAchievementsData`) and reloaded by `Achievements.load()`; `Achievements.reloadList()` keeps them and does not reuse their IDs.

S6. Custom icon. Verbatim from the request:
   > "en el menu de achievment editor uno le pueda poner una imagen al logro"
   Required: the editor takes an image path under `images/` (`.png` optional, `images/` prefix optional), shows a live preview, and stores it in `Achievement.image`. When empty, the icon stays `achievements/<save>`. `Achievements.getImagePath()` is the single resolver used by the achievements menu and the unlock popup, and still prefers the `-pixel` variant when present.

S7. Chart Editor event. Verbatim from the request:
   > "tambien añadir un evento en el chart editor que te permita conseguir un logro al pasar ese evento"
   Required: a new `Unlock Achievement` entry in `ChartingState.defaultEvents`; `Value 1` is the achievement save key. When playback reaches the event, `PlayState.triggerEvent` unlocks that achievement through `Achievements.unlock()` (idempotent) and warns on an unknown key.

## Tasks

- [x] T1 Remove every non-Main-Menu entry from `MenuHubEditorState`. Spec: S1.
- [x] T2 Add the custom-achievement API to `Achievements.hx` (`customAchievements`, `isValidSaveKey`, `getCustomList`, `createCustom`, `removeCustom`, `saveCustomAchievements`, `loadCustomAchievements`). Spec: S3, S4, S5.
- [x] T3 Add `states/editors/AchievementEditorState.hx` (list + form + new/save/delete). Spec: S3, S4.
- [x] T4 Register `Achievement Editor` in `MasterEditorMenu` (debug key 7 entry point). Spec: S2.
- [x] T5 Compile check `lime build linux -debug`: Haxe compile and link succeeded; the final copy to `export/debug/linux/bin/PsychEngine` failed only because the game was already running (PID in use). Spec: all.
- [x] T6 Custom icon: `Achievement.image`, `normalizeImagePath`, `getImagePath`, resolver wired into `AchievementsMenuState` + `AchievementPopup`, editor image field + live preview. Spec: S6.
- [x] T7 `Unlock Achievement` chart event: `defaultEvents` entry + `PlayState.triggerEvent` case. Spec: S7.
- [x] T8 Compile check after T6/T7 (`lime build linux -debug`, binary copied at 15:12). Spec: all.

## Log

L1 (user, verbatim, 2026-10-25):

> puedes en el menu de edicion de menus quitar todos y solo dejar el de main menu, tambien quiero que añadas en la tecla 7 la opcion de edicion de logros que te permita crear, modificar y/o quitar logros custom

L2 (assistant, 2026-10-25): build evidence. `lime build linux -debug` compiled `AchievementEditorState.cpp` and linked `ApplicationMain-debug`; only the binary copy step failed with `Cannot copy to "export/debug/linux/bin/PsychEngine", is the file in use?` because a game instance (PID 801210) was running. No source error.

L3 (user, verbatim, 2026-10-25):

> me gustaria que en el menu de achievment editor uno le pueda poner una imagen al logro, y tambien añadir un evento en el chart editor que te permita conseguir un logro al pasar ese evento

L4 (assistant, 2026-10-25): build evidence after T6/T7. `lime build linux -debug` linked and the binary copied successfully (game closed by the user). Note: `Achievement.image` also lets a mod `achievements.json` entry pick its own icon.

