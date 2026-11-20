Objective: restore the base game weeks and songs in the debug (source) build.
Branch: main (uncommitted). Test runner: lime build linux -debug (no automated test suite).
File locator: odd/tasks/base-game-content.md

## Specs

S1. `BASE_GAME_FILES` is active in a normal `lime build linux -debug` (debug builds included), without turning on `officialBuild`. Verbatim from the request:
   > "puedes traer de vuelta las caciones del jego base?"
   Required: the define lives outside `<section if="officialBuild">`, so `assets/base_game` is copied into the export and every `#if BASE_GAME_FILES` code path is compiled.

S2. Base weeks load. `assets/base_game/shared/weeks/*.json` plus `assets/shared/weeks/weekList.txt` (`tutorial`, `week1`..`week7`, `weekend1`) resolve to 9 weeks, and every song listed in them has `assets/songs/<song>/Inst.ogg`, its voices, and chart JSONs under `assets/shared/data/<song>/`.

S3. No regression from the restore:
   - `TITLE_SCREEN_EASTER_EGG` and `VIDEOS_ALLOWED` stay inside `officialBuild` (`hxvlc` is not installed).
   - The build must not depend on `funkin.vis` / `grig.audio`; the installed `funkin.vis` git build calls a newer `grig.audio` API than the installed `grig.audio` (`makeLogGraph` with `minFreq`/`maxFreq`), which does not compile.
   - `ABotSpeaker` still compiles and degrades gracefully (all its visualization code is `#if funkin.vis`).

S4. Freeplay and Story Mode list the base weeks and their songs once assets are in the export.

## Tasks

- [x] T1 Move `<define name="BASE_GAME_FILES" />` out of the `officialBuild` section in `Project.xml`. Spec: S1.
- [x] T2 Fix the dependency failure: drop `grig.audio`/`funkin.vis` from the `BASE_GAME_FILES` section (unused outside `ABotSpeaker`'s optional viz). Spec: S3.
- [x] T3 `lime build linux -debug`: linked and `export/debug/linux/bin/PsychEngine` written at 15:48. Spec: S1, S3.
- [x] T4 Verify the export: `assets/{week1..week7,weekend1,songs,shared/weeks}` present; 26 base week songs checked for folder + `Inst` audio + charts → all OK. Spec: S2.
- [x] T5 Launch the build and check the log: no asset/week errors at startup (PID 840032). Spec: S4 (visual confirmation by the user).

## Log

L1 (user, verbatim, 2026-10-25):

> puedes traer de vuelta las caciones del jego base?

L2 (assistant, 2026-10-25): root cause. `BASE_GAME_FILES` was only defined inside `<section if="officialBuild">`, so debug builds never copied `assets/base_game` (weeks, songs, characters, stages) and never compiled the base-week code paths. `assets/shared/weeks/` only holds `weekList.txt`; the week JSONs live in `assets/base_game/shared/weeks/`, so nothing resolved without the define.

L3 (assistant, 2026-10-25): first rebuild failed in the haxelib, not in our code:

```
/home/dante/haxelib/funkin,vis/git/src/funkin/vis/dsp/SpectralAnalyzer.hx:232: levels.resize(bars.length-1);
Float should be Int
```

`funkin.vis` (git) calls `vis.makeLogGraph(freqs, barCount + 1, dbRange, range, fftN, sampleRate, minFreq, maxFreq)` with 8 arguments, while the installed `grig.audio` 0.0.5 (git) only exposes `makeLogGraph(freq, bands, dbRange, intRange)`, so `bars` is inferred as `Float`-valued and `.length-1` fails. Both libraries were pulled in only because `BASE_GAME_FILES` added them.

L4 (assistant, 2026-10-25): decision. Drop the two haxelibs instead of patching installed global haxelibs. Grep showed `grig.audio` is not imported anywhere in `source/`, and `funkin.vis` only in `ABotSpeaker.hx` (weekend1 speaker animation), fully guarded by `#if funkin.vis`. Base game content does not need them.

L5 (assistant, 2026-10-25): build evidence. `lime build linux -debug` compiled and linked `ApplicationMain-debug`; binary written at 15:48:04. Export assets now contain `week1`..`week7`, `weekend1`, `songs/` (28 entries), and `shared/weeks/` with the 9 JSONs plus `weekList.txt`. Chart/audio check over all 26 base-week songs passed.

L6 (assistant, 2026-10-25): the build was launched (`export/debug/linux/bin/PsychEngine`, PID 840032); the startup log shows no asset or week errors. Visual confirmation in Freeplay/Story is the user's.
