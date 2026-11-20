# Erect remixes: baked content, Freeplay difficulties and erect stages

The **Erect Mode** content (songs, charts, weeks, stages, images, characters) is now baked into the engine under `assets/`. It no longer needs to be installed as a mod. The old standalone mod is still supported if present, but is not required.

The remixes ("Bopeebo Erect", "Fresh Erect", ...) are folded into their base song as two extra difficulties, **Erect** and **Nightmare**, in **Freeplay only**.

## What changed

- Erect Mode content lives under `assets/base_game/` (songs in `songs/`, everything else in `shared/`). The game works with `mods/Erect Mode` removed.
- Freeplay no longer lists songs whose name ends in `Erect`.
- A base song that has an erect counterpart shows two extra difficulties: **Erect** and **Nightmare**.
- Selecting either one loads the chart, audio **and stage** from the erect remix's assets, e.g. `data/bopeebo-erect/bopeebo-erect-erect.json`, `songs/bopeebo-erect/` and `stages/stageErect.lua`.
- If the erect chart's stage has an erect variant (`stages/<stage>Erect.json`), that stage is applied. For `spookyErect`, the `-dark` character variants are used.
- Scores are stored under the erect chart's own key, so the personal best shown in Freeplay matches the one saved after playing.
- **Story Mode is unchanged.** It never sees these difficulties or stages.

Detection is by display name: a week entry ending in `Erect` (space or hyphen, case-insensitive via `Paths.formatToSongPath`) is treated as the remix of the same name without that suffix. The stage switch that Erect Mode used to do in `scripts/changeStage.lua` (which depended on `currentModDirectory == 'Erect Mode'`) is now handled by the engine in `FreeplayState.applyErectStage()`.

Content credits (preserved from the mod's `data/credits.txt`): Ledonic (remix ports), Cyachao (rain shader), MrCatz (Week 5 `Hey!` animation).

## Files

- `source/backend/ErectRemix.hx` — name mapping and erect-stage resolution (pure helpers).
- `source/states/FreeplayState.hx` — merge into the song list, difficulty list, chart/audio lookup, score keys and erect stage switching.
- `tests/ErectRemixTest.hx` — 21 deterministic name/stage-resolution probes.
- `assets/base_game/` — baked Erect Mode content.

## Local verification

```sh
# name + stage mapping
SCRATCH=$(mktemp -d)
mkdir -p "$SCRATCH/backend"
cp tests/ErectRemixTest.hx "$SCRATCH"/
cp source/backend/ErectRemix.hx "$SCRATCH/backend"/
cp tests/erect-remix/backend/Paths.hx "$SCRATCH/backend"/
haxe -D MODS_ALLOWED -cp "$SCRATCH" -main ErectRemixTest -neko "$SCRATCH/test.n" && neko "$SCRATCH/test.n"
rm -rf "$SCRATCH"

# engine
lime build linux -debug
```

The engine log prints `Erect remixes merged into Freeplay: 17` on entering Freeplay (verified with `mods/Erect Mode` renamed out of the way, proving the baked assets are sufficient), and `Erect chart: Bopeebo / Erect -> bopeebo-erect` plus `Erect stage: stage -> stageErect` when that difficulty is resolved.

## Windows handoff

- [ ] Build without `mods/Erect Mode` installed; the game still has the erect songs.
- [ ] Enter Freeplay: no `Bopeebo Erect` / `Fresh Erect` entries appear.
- [ ] Select `Bopeebo`: difficulty cycling shows Easy, Normal, Hard, **Erect**, Nightmare.
- [ ] Pick **Erect**: the erect remix plays with its own audio and the erect background (`stageErect`).
- [ ] Pick **Nightmare**: the `bopeebo-erect-nightmare.json` chart plays with erect audio and background.
- [ ] Pick an erect difficulty for a spooky song: the `-dark` character variants appear.
- [ ] Finish a song: the personal best shown in Freeplay updates for Erect and Nightmare.
- [ ] Story Mode shows neither the erect difficulties nor the erect stages.
