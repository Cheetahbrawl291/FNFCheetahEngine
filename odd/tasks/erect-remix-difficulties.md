# Erect remix difficulties in Freeplay

Objective: songs whose name ends in "erect" (the Erect Mode mod) become the Erect and Nightmare difficulties of the matching base song in Freeplay only, instead of separate songs. Story Mode is unchanged.
Branch: `feature/modchart-editor-bridge` (continues the local engine work). Test runner: no automated suite; structural checks and `lime build linux -debug` locally. Windows runtime checks by the user's friend.
Delivery strategy: `ask-on-risk` (local work-unit commits only; no publish).

## Specs

S1. Detect the erect suffix. Verbatim from the request:
   > "puedes hacer que si una cancion termina en "erect" se aplique a la cancion que no es erect con su difucultad erect y nightmare para poder añadir al motor los remix erect?"
   Required: a week song entry whose display name ends in "erect" is recognized as the remix of the base song with the suffix removed.

S2. Expose the difficulties in Freeplay. Verbatim from the clarification:
   > "quiero que si uno cambia la dificultad aparesca erect y nightmare, en el storymode no"
   Required: selecting the base song in Freeplay and cycling difficulty shows Erect and Nightmare as two additional difficulties.

S3. Do not change Story Mode. Same verbatim fragment as S2:
   > "en el storymode no"
   Required: the Erect/Nightmare additions must not be visible or selectable in Story Mode.

S4. Merge, do not duplicate. Verbatim from the clarification:
   > "el juego tiene las canciones base pero los remix erect estan en "/home/dante/Descargas/FNF-CheetahEngineDevbuildv1/export/debug/linux/bin/mods/Erect Mode" aparecen como canciones aparte"
   Required: the erect entries stop appearing as separate Freeplay songs; the base song loads the erect chart and audio from the mod when Erect or Nightmare is selected.

S5. Standing verification constraint, verbatim from earlier work:
   > "tranquilo, los test de windows los hace un amigo"
   Required: local work stops at structural checks and a Linux build; Windows build/runtime probes are documented for the friend.

S6. Scope boundary (assumption, not requested): the third-party `Erect Mode` mod under `export/debug/linux/bin/mods/` is input data only; its files must not be edited. Only engine source and docs change.

## Tasks

- [x] T1 Detect erect entries and merge them into base songs. Specs: S1, S4, S6. Route: inline.
- [x] T2 Add Erect/Nightmare to the Freeplay difficulty selector; keep Story Mode untouched. Specs: S2, S3. Route: inline.
- [x] T3 Route chart, audio and preview lookup to the erect mod for those difficulties. Specs: S4. Route: inline.
- [x] T4 Documentation, verification and Windows handoff (local proof observed; Windows probes delegated). Specs: S5. Route: inline.

## Log

L1. Original request, verbatim:
   > "puedes hacer que si una cancion termina en "erect" se aplique a la cancion que no es erect con su difucultad erect y nightmare para poder añadir al motor los remix erect?"

L2. Clarification, verbatim:
   > "quiero que se agrenen las dificultades nightmare y erect como si fueran una difucultad mas, para que veas a que me refiero el juego tiene las canciones base pero los remix erect estan en "/home/dante/Descargas/FNF-CheetahEngineDevbuildv1/export/debug/linux/bin/mods/Erect Mode" aparecen como canciones aparte, quiero que si uno cambia la dificultad aparesca erect y nightmare, en el storymode no"

L3. Pre-write evidence: `source/backend/Difficulty.hx` builds chart postfixes from `Difficulty.list`; `Highscore.formatSong` (`source/backend/Highscore.hx:80-83`) concatenates song path + `Difficulty.getFilePath(diff)`. Week files can declare `"difficulties": "Erect,Nightmare"`. The Erect Mode mod's `weeks/week1e.json` does exactly that and names entries "Bopeebo Erect"; charts are `data/bopeebo-erect/bopeebo-erect-erect.json` and `-nightmare.json`, audio in `songs/bopeebo-erect/`. No existing "erect" handling exists in engine source, docs or base charts.

L4. Route declaration: tracked task (cross-cutting song list, difficulty, and asset resolution; external mod data). All tasks run INLINE: no Writer trigger (one bounded behavior, no parallel units, context backstop not reached). A read-only explorer mapped the exact Freeplay/PlayState/Paths coupling before the first write. Risk line: none — changes are confined to FreeplayState plus one new pure name-mapping helper; Story Mode, shared Difficulty/Highscore/Song APIs and the third-party mod are untouched. RDD is on globally and native assess runs per work-unit commit.

L5. Explorer handoff: `SongMetadata.folder` comes from `Mods.currentModDirectory` (`FreeplayState.hx:649-666`); weeks get folder `"Erect Mode"` from `WeekData.reloadWeekFiles()` (`WeekData.hx:100,151`). `pack.json` has `runsGlobally: true`, so `Paths.modFolders()` resolves the mod's assets globally without switching mods. `PlayState` audio uses `SONG.song` (`PlayState.hx:1301-1320`), which the erect chart already sets to `"Bopeebo Erect"` → `songs/bopeebo-erect`, so no PlayState change was needed. `Highscore.saveScore` uses `Song.loadedSongName` (`PlayState.hx:2484`), while Freeplay read scores from the display name — that mismatch was fixed by exposing a separate `scoreName` in `currentChart()`. `Difficulty.loadFromWeek()` is shared with StoryMenuState, so Erect/Nightmare are appended in `changeSelection()` instead of changing shared code.

L6. Implementation: new `source/backend/ErectRemix.hx` maps display names (suffix detection, base name, erect folder, chart id). `FreeplayState` pre-scans all weeks to map base name → erect folder, skips erect entries in the song list, appends Erect/Nightmare only when a base song has a counterpart, and routes preview, ACCEPT, score display and reset through `currentChart()`. Two traces expose the merge in logs. `docs/ERECT_REMIXES.md` documents behavior and the Windows checklist. Initial isolated test failed on `String.trim`/`String.endsWith` under plain Haxe; `using StringTools;` fixed the helper and the stub now uses `StringTools.trim`.

L7. Verification, all observed locally: `lime build linux -debug` exit 0 (`BUILD_LINUX_OK`) after every source change; `ErectRemixTest` 18/18 PASS with exit 0 in an isolated scratch copy (`tests/ErectRemixTest.hx`, real helper, minimal `Paths.formatToSongPath` stub copied from `Paths.hx:416-421`); structural checks confirm the skip, append and routing markers exist and that `StoryMenuState.hx`/`Difficulty.hx` contain no erect references. Test-first note: the name-mapping probes were added after the helper because their isolated runner needed a `Paths` stub first; no pre-existing runnable test covered this behavior. Runtime interaction with the Freeplay UI is not scriptable locally; Windows probes are delegated in `docs/ERECT_REMIXES.md` per S5.

L8. Scope boundary: `README.md`, `docs/img/` and `.atl/` keep their pre-existing unrelated worktree changes and were left untouched. The `Erect Mode` mod under `export/debug/linux/bin/mods/` was read only, never edited. Work-unit commit: pending.
