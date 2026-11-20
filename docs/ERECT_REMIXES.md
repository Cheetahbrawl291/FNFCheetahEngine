# Erect remixes as Freeplay difficulties

The **Erect Mode** mod ships its remixes as separate songs ("Bopeebo Erect", "Fresh Erect", ...), each with its own week, chart folder and audio folder. The engine now folds those entries into the matching base song in **Freeplay only**.

## What changed

- Freeplay no longer lists songs whose name ends in `Erect`.
- A base song that has an erect counterpart shows two extra difficulties: **Erect** and **Nightmare**.
- Selecting either one loads the chart and audio from the erect song's folder, for example `data/bopeebo-erect/bopeebo-erect-erect.json` and `songs/bopeebo-erect/`.
- Scores are stored under the erect chart's own key, so the personal best shown in Freeplay matches the one saved after playing.
- **Story Mode is unchanged.** It never sees these difficulties.

Detection is by display name: a week entry ending in `Erect` (space or hyphen, case-insensitive via `Paths.formatToSongPath`) is treated as the remix of the same name without that suffix. The mod's `pack.json` uses `runsGlobally: true`, so its assets resolve without switching mods.

## Files

- `source/backend/ErectRemix.hx` — name mapping only (suffix detection, base name, chart id).
- `source/states/FreeplayState.hx` — merge into the song list, difficulty list, chart/audio lookup and score keys.
- `tests/ErectRemixTest.hx` — 18 deterministic name-resolution probes.

## Local verification

```sh
# name mapping
SCRATCH=$(mktemp -d)
mkdir -p "$SCRATCH/backend"
cp tests/ErectRemixTest.hx "$SCRATCH"/
cp source/backend/ErectRemix.hx "$SCRATCH/backend"/
cp tests/erect-remix/backend/Paths.hx "$SCRATCH/backend"/
haxe -cp "$SCRATCH" -main ErectRemixTest -neko "$SCRATCH/test.n" && neko "$SCRATCH/test.n"
rm -rf "$SCRATCH"

# engine
lime build linux -debug
```

The engine log prints `Erect remixes merged into Freeplay: 17` on entering Freeplay, and `Erect chart: Bopeebo / Erect -> bopeebo-erect` when that difficulty is resolved.

## Windows handoff

- [ ] Build with the Erect Mode mod installed under `mods/Erect Mode`.
- [ ] Enter Freeplay: no `Bopeebo Erect` / `Fresh Erect` entries appear.
- [ ] Select `Bopeebo`: difficulty cycling shows Easy, Normal, Hard, **Erect**, Nightmare.
- [ ] Pick **Erect**: the erect remix plays with its own audio; the chart is `bopeebo-erect-erect.json`.
- [ ] Pick **Nightmare**: the `bopeebo-erect-nightmare.json` chart plays with the same erect audio.
- [ ] Finish a song: the personal best shown in Freeplay updates for Erect and Nightmare.
- [ ] Story Mode does not show Erect or Nightmare and still shows only the base songs.
- [ ] Without the mod installed, Freeplay is unchanged.
