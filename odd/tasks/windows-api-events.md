# Windows API song events + exit restore

Objective: expose chart song events backed by SL-Windows-API, gate the OS-level effects behind settings, and restore the desktop before the engine exits.
Branch: `feature/windows-song-events`. Test runner: no automated suite; `lime build linux -debug` locally, Windows runtime checks by the user's friend.
Risk items: 2 (security), 5 (dependency/environment), 6 (no local test catches Windows regressions).

## Specs

S1. Song events using the library. Verbatim from the request:
   > "cres que puedas añadir eventos de cancion que puedan usar la api de ventanas de windows de https://github.com/Slushi-Github/SL-Windows-API/"
   Required: chart events appear in `ChartingState.defaultEvents` and are handled in `PlayState.triggerEvent`. Safe window-cosmetic events need no setting. Events that touch the OS desktop are gated by S2. Non-Windows builds keep compiling and ignore the events.

S2. Settings gate for dangerous interactions. Verbatim from the request, naming the affected interactions:
   > "lo de ocultar taskbar/íconos, cambiar wallpaper, screenshots y efectos GDI derivados de código de malware. podemos hacer en la configuracion que se pueda activar o desactivar esas interacciones"
   Required: an options submenu with one boolean per category — taskbar/desktop icons, wallpaper, screenshots, GDI effects. All default `false`. A gated event with its switch off is refused and logged; it never calls the library.

S3. Restore before exit. Verbatim from the request:
   > "aparte podemos hacer que el motor al cerrarlo no se cierre y verifique primero si hay algo como la barra de tareas, fondo, screenshots y efectos GDI corriendolo y los detendra y quitara dejando todo a la normalidad y luego de eso se cerrara"
   Required: on window close and on the crash-handler exit path, restore taskbar visibility, desktop icons, desktop position/alpha, wallpaper, and stop/clear GDI effects before the process ends. Screenshot cleanup is opt-in because screenshots are user files, not OS state.

S4. Windows verification owner. Verbatim from the request:
   > "tranquilo, los test de windows los hace un amigo"
   Required: local work stops at compile/static checks; Windows build and runtime probes are the friend's. The handoff must name the exact events, toggles and cleanup probes.

S5. Assumption (not requested verbatim): non-Windows targets must keep their current behavior. The haxelib, imports, menu entry, event cases and cleanup hook are guarded with `#if windows`; prefs fields exist on every target so existing saves load unchanged.

## Tasks

- [x] T1 Dependency, prefs and settings menu. Spec: S1, S2, S5. Commit `a9412e3`.
- [x] T2 Chart events, gating and active-state tracking. Spec: S1, S2. Commit `509091d`.
- [x] T3 Exit restore hook and crash path. Spec: S3. Commit `509091d`.
- [x] T4 README documentation. Spec: S1-S3. In the working tree, left uncommitted: the README already carried the user's own rewrite and the `CheetahEngineLogo.png` path fix, so only the new "Windows API song events" section was appended, without sweeping the user's parallel doc edits into a feature commit.
- [ ] T5 Local compile/static checks + Windows test handoff. Spec: S4. Local checks done (see L8); Windows build/runtime probes remain with the user's friend.

## Log

L1. Original request, verbatim:
   > "cres que puedas añadir eventos de cancion que puedan usar la api de ventanas de windows de https://github.com/Slushi-Github/SL-Windows-API/"

L2. User authorization and constraints, verbatim:
   > "tranquilo, los test de windows los hace un amigo, lo de ocultar taskbar/íconos, cambiar wallpaper, screenshots y efectos GDI derivados de código de malware. podemos hacer en la configuracion que se pueda activar o desactivar esas interacciones y aparte podemos hacer que el motor al cerrarlo no se cierre y verifique primero si hay algo como la barra de tareas, fondo, screenshots y efectos GDI corriendolo y los detendra y quitara dejando todo a la normalidad y luego de eso se cerrara"

L3. Feasibility evidence (verified before writing): the library is hxcpp/Windows-only (`@:cppFileCode`, `@:functionCode`, `#if (HX_WINDOWS || windows)`, MSVC `/DelayLoad:ComCtl32.dll`); `BUILDING.md` already requires VS 2022 on Windows. `WindowsAPI.resetWindowsFuncs()` already restores taskbar, desktop icons, desktop position/alpha and wallpaper. `WindowsGDIThread.stopWindowsGDIThread()` stops the thread and clears every effect. `Application.current.onExit` exists in the installed Lime 8.x. `Main.hx:258` calls `Sys.exit(1)` in the crash handler; that path also needs cleanup.

L4. Event system evidence: `ChartingState.defaultEvents` (`ChartingState.hx:69`) is `[name, description]`; `PlayState.triggerEvent` (`PlayState.hx:2061`) switches on the name with `value1`/`value2` strings only, so RGB is encoded as `r,g,b` in `value1`.

L5. Exit-path evidence: no in-game quit action exists; the normal exit is the OS window close, dispatched through Lime's `Application.onExit`. Cleanup must be synchronous there.

L6. Parallel user change observed at task creation: `docs/img/*.png` deleted and `docs/img/CheetahEngineLogo.png` added in the worktree. Not part of this feature; the README logo path was already correct by the time T4 ran, so no logo edit was needed.

L7. Route declaration: small-by-resume test fails (multi-file feature, Windows target unverifiable locally), so the feature is tracked; all tasks ran INLINE. No Writer trigger (one bounded behavior, no parallel units, context backstop not reached). No independent verifier from the native tier: RDD assess over the committed range with `--untracked-scope=exclude` returned `risk: medium`, `review_due: false` (`under_budget`), so no native review cycle. A separate read-only verification worker is still dispatched because the diff names high-risk items 2 (security guards), 5 (dependency) and 6 (no local Windows test).

L8. Local evidence (observed): `lime build linux -debug` exit 0 twice, no errors/warnings, binary produced. Windows helper typechecked against the REAL installed lib with `-D windows -cpp ... --no-output` and minimal flixel/ClientPrefs/Application stubs: exit 0. Both stub and real-lib typechecks passed. A naive `lime build windows -debug` on Linux fails earlier in `linc_luajit` (`cpp.RawPointer` not available on neko) — pre-existing environment limitation, not this diff. Two real-lib bugs found and fixed during review: SL-Windows-API joins paths as `Path.directory(programPath) + path` (needs a leading slash), and `prepareGDIEffect` silently ignores unknown names, so the helper now verifies registration before tracking/starting the thread.

L9. Two work-unit commits on `feature/windows-song-events`: `a9412e3` (dependency/prefs/menu), `509091d` (events/helper/exit). README and `docs/img` changes left uncommitted because they are the user's parallel work.
