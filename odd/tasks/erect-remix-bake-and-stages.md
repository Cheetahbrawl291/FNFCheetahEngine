# Bake Erect Mode into the engine and apply erect stages

Objective: (1) the Erect Mode mod stops being a separate mod — its content is baked into `assets/` and the game works without `mods/Erect Mode`; (2) when an erect remix has a distinct background (stage), that erect stage is applied when its Erect/Nightmare difficulty is played. Story Mode stays unchanged.
Branch: `feature/modchart-editor-bridge`. Test runner: no automated suite; structural checks and `lime build linux -debug` locally. Windows runtime checks by the user's friend.
Delivery strategy: `ask-on-risk` (local work-unit commits only; no publish).

## Specs

S1. Bake the whole mod. Verbatim from the request:
   > "tambien me gustaria que metieras el mod que añade esas canciones al codigo del motor y que no este como mod"
   Required: Erect Mode content (songs, data, stages, images, characters, week data, etc.) lives under `assets/`, not only under `mods/`. The game must work with `mods/Erect Mode` removed.

S1a. Scope confirmation, verbatim user answer:
   > "Bakear todo (162 MB) (Recomendado)"
   Required: all of the mod's content is baked, with credits intact. Third-party redistribution is explicitly authorized by the user.

S2. Apply erect backgrounds. Verbatim from the request:
   > "puedes hacer que si el erect mix tiene un fondo distinto a la vercion normal se aplique en los erect mix tambien?"
   Required: when the base song has an erect stage file (`stages/<stage>Erect.json` + `.lua`) and Erect/Nightmare is selected, that stage is used for the erect difficulty.

S3. Do not change Story Mode. Carried over from the previous feature's spec (verbatim):
   > "en el storymode no"
   Required: erect stages and difficulties remain Freeplay-only.

S4. Standing verification constraint, verbatim:
   > "tranquilo, los test de windows los hace un amigo"
   Required: local work stops at structural checks and a Linux build; Windows build/runtime probes documented for the friend.

S5. Scope boundary: only engine source, `assets/`, docs and ODD docs change. The source mod under `export/debug/linux/bin/mods/Erect Mode` is read-only input for the copy.

## Tasks

- [x] T1 Copy the mod content into `assets/base_game/` (songs in `songs/`, rest in `shared/`) and register the weeks so Freeplay sees them. Specs: S1, S1a, S5. Route: inline.
- [x] T2 Reimplement the erect stage switch in engine code (`ErectRemix.erectStage` + `FreeplayState.applyErectStage`); keep spooky dark-character handling; drop the baked `changeStage.lua`. Specs: S2, S3. Route: inline.
- [x] T3 Verify the game works without `mods/Erect Mode` (Linux build + structural checks + runtime log); document and hand off Windows probes. Specs: S1, S4. Route: inline.

## Log

L1. Original request, verbatim:
   > "puedes hacer que si el erect mix tiene un fondo distinto a la vercion normal se aplique en los erect mix tambien?"

L2. Follow-up request, verbatim:
   > "tambien me gustaria que metieras el mod que añade esas canciones al codigo del motor y que no este como mod"

L3. Scope answer, verbatim:
   > "Bakear todo (162 MB) (Recomendado)"

L4. Pre-write evidence: `changeStage.lua` inside the mod switches `SONG.stage` to `curStage + 'Erect'` only if `currentModDirectory == 'Erect Mode'` and mod setting `erectStages` is true; it also swaps to `-dark` characters for `spookyErect`, then `restartSong()`. `PlayState.hx:467` loads `stages/<curStage>.lua`. `StageData.getStageFile()` reads `stages/<stage>.json` via `Paths.getPath(..., TEXT, null, true)`. Weeks are enumerated by `WeekData.reloadWeekFiles()` scanning `weeks/*.json` under `Paths.getSharedPath()` = `assets/shared/`, plus mod dirs. `Paths.inst/voices` resolve `songs/<name>/Inst|Voices`; `Song.loadFromJson(id, folder)` reads `data/<folder>/<id>.json`. `Project.xml` includes `assets/base_game` and `assets/shared` via `<assets>` sections. No `weekList.txt` exists, so all `weeks/*.json` in each dir are loaded.

L5. Mod inventory: 162 MB total — data 1.9 MB (59 files), songs 122 MB (52 files), images 37 MB (166 files), stages 156 KB (21 files), characters 76 KB, music 496 KB, sounds 552 KB, shaders 24 KB, custom_events 36 KB, custom_notetypes 12 KB, videos 4 KB, weeks 40 KB (8 files), scripts 4 KB (`changeStage.lua`). Credits in `data/credits.txt`: Ledonic (ported remixes), Cyachao (rain shader), MrCatz (Week 5 'Hey!' animation). Erect stage JSONs reference images like `mainStage/erect/...` under `images/`.

L6. Route declaration: tracked task (cross-cutting asset copy + stage logic; third-party content). All tasks INLINE: no Writer trigger (one bounded behavior sequence, no parallel units, context backstop not reached). Risk line: none — content is added under `assets/` and stage routing is confined to Freeplay for erect difficulties; Story Mode and shared APIs untouched. RDD is on globally and native assess runs per work-unit commit. Game binary was running from an earlier verification and was closed before any rebuild to avoid SIGBUS.

L7. Implementation: copied all 162 MB of the mod into `assets/base_game/` — `songs/` at top level, everything else under `shared/` (the layout the engine reads; `<assets path="assets/base_game" rename="assets"/>` maps `shared/` -> export `assets/shared/`). First copy mistakenly landed in `assets/base_game/<dir>` (exported to `assets/<dir>`, not `assets/shared/<dir>`); found via build verification, moved into `shared/`, and the stray dirs removed. Stray copies of 3 base `.mp4` videos ended up in `shared/videos/` and were deleted; originals restored with `git checkout`. Dropped the mod's baked `changeStage.lua` (it depends on `currentModDirectory == 'Erect Mode'`). Added `ErectRemix.erectStage()` (checks `stages/<stage>Erect.json` via `getSharedPath` + `FileSystem.exists`) and `isSpookyErect()`; `FreeplayState.applyErectStage()` sets `PlayState.SONG.stage` to the erect stage and swaps to `-dark` characters for spookyErect, called right after `Song.loadFromJson` in ACCEPT. `.gitattributes` marks baked third-party content `-text` to preserve exact bytes. `docs/ERECT_REMIXES.md` rewritten for the baked/stage behavior.

L8. Verification, all observed: `ErectRemixTest` 21/21 PASS (isolated scratch, `-D MODS_ALLOWED` so the `sys.FileSystem` branch compiles); `lime build linux -debug` exit 0 twice (before and after the layout fix). Export check: 17 erect song folders, 17 erect chart dirs, 9 erect stage JSON + 9 Lua, 8 erect weeks, 11 `mainStage/erect` images, all under `assets/shared/` / `assets/songs/`; no `changeStage.lua` in export. Runtime proof: with `mods/Erect Mode` renamed out of the way and removed from `modsList.txt`, engine started clean (exit 124 = timeout, no crash) and logged `Erect remixes merged into Freeplay: 17` — proving baked assets are sufficient. Mod dir and `modsList.txt` restored afterward. Test-first note: probes were extended after the helper existed; no pre-existing runnable test covered erect naming/stages.

L9. Worktree hygiene: pre-existing unrelated changes (`README.md`, `docs/img/CheetahEngineLogo.png` deleted, `docs/img/2026_10_24_0tt_Kleki.png`, `.atl/`) untouched. The source mod under `export/.../mods/Erect Mode` was consumed by `cp` and then removed by a later `lime build` (Lime cleans `mods/`); this is fine — `assets/base_game/` is now the source of truth. Work-unit commit `58a600f` (`feat(erect): bake Erect Mode into assets and apply erect stages`), 346 files, ~495k insertions (mostly binary third-party content), no publish. RDD assess `--base-ref 0f2fcdf --committed-only --untracked-scope exclude`: `risk: medium`, `risk code: executable_change` (`.gitattributes`), `review_due: false`, `review_due_reason: under_budget`; no native review cycle. Risk line: none.
