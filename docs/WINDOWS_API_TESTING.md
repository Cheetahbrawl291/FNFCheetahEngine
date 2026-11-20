# Windows API song events — Windows test handoff

This feature is compiled and gated in `source/backend/WindowsIntegrations.hx`; the runtime evidence has to come from a Windows machine. Local Linux checks cover only the guards and the Haxe typecheck, never the OS effects.

## Build

Requires VS 2022 (see `docs/BUILDING.md`) and the haxelib:

```sh
haxelib install sl-windows-api
lime build windows -debug
```

## Toggles — Options → Windows API

All five start `false`. A gated event with its switch off is refused and logged; it never calls the library.

| Option | Pref field | Gates |
| --- | --- | --- |
| Taskbar & Desktop Icons | `winApiTaskbar` | Hide Taskbar, Hide Desktop Icons, Move Desktop Icons |
| Wallpaper Changes | `winApiWallpaper` | Change Wallpaper |
| Screen Captures | `winApiScreenshots` | Screen Capture |
| GDI Effects | `winApiGdi` | GDI Effect |
| Delete Session Screenshots | `winApiCleanupScreenshots` | Deletes only screenshots created this session on exit |

The first six events below are cosmetic and need no switch.

## Chart events

| Event | Value 1 | Value 2 | Gate |
| --- | --- | --- | --- |
| Window Border Color | `R,G,B` (0-255), e.g. `255,0,0` | unused | none (Windows 11) |
| Window Text Color | `R,G,B` (0-255) | unused | none (Windows 11) |
| Window Dark Mode | `true`/`false`/`1`/`0`, blank = `true` | unused | none |
| Window Corner | `0` default, `1` none, `2` round, `3` small | unused | none |
| Window Opacity | `0`–`1`, e.g. `0.75` | unused | none |
| Center Window | unused | unused | none |
| Hide Taskbar | `true`/`false`/`1`/`0`, blank = `true` | unused | `winApiTaskbar` |
| Hide Desktop Icons | `true`/`false`/`1`/`0`, blank = `true` | unused | `winApiTaskbar` |
| Move Desktop Icons | X | Y | `winApiTaskbar` |
| Change Wallpaper | image path relative to the game folder, e.g. `images/wall.png` | unused | `winApiWallpaper` |
| Screen Capture | output path relative to the game folder, e.g. `shots/a.png` | unused | `winApiScreenshots` |
| GDI Effect | `DrawIcons`, `ScreenBlink`, `ScreenGlitches`, `ScreenShake`, `ScreenTunnel`, `SetTitleTextToWindows` | `on`/`off`, optionally `on:waitMs` e.g. `on:50` | `winApiGdi` |

Malformed RGB, coordinates, out-of-range opacity/corner, unknown GDI names, and paths with `..`, a leading `/`, or a drive letter are refused and logged.

## Probe checklist

1. Fresh profile: all five toggles are off. Fire all six gated events from a chart. Expected: nothing changes on the desktop; the log shows one refusal per event.
2. Enable **Taskbar & Desktop Icons**: `Hide Taskbar true`, `Hide Desktop Icons true`, `Move Desktop Icons 80,120`. Expected: taskbar/icons hide and icons move. `Hide Taskbar false` / `Hide Desktop Icons false` / `Move Desktop Icons 0,0` restore them immediately.
3. Enable **Wallpaper Changes**: `Change Wallpaper images/wall.png` with a real PNG inside the game folder. Expected: wallpaper changes.
4. Enable **Screen Captures**: `Screen Capture shots/a.png`. Expected: a full-screen screenshot appears at `<game folder>/shots/a.png`.
5. Enable **GDI Effects**: `GDI Effect ScreenBlink on:50`. Expected: the effect draws over the desktop. `GDI Effect ScreenBlink off` stops it. An unknown name logs an error and starts nothing.
6. Close the window with effects still active and the wallpaper changed. Expected: taskbar/icons visible, icons at `0,0`, original wallpaper restored, all GDI effects gone, then the process exits. Repeat with `Delete Session Screenshots` off (screenshot stays) and on (only screenshots from this session are deleted; any pre-existing file at the same path is preserved).
7. Trigger a crash while effects are active (if the crash handler is enabled). Expected: same restore, then `Sys.exit(1)`.
8. Cosmetic events (border/text color, dark mode, corners, opacity, center) work with every toggle off, on Windows 11 where applicable.
9. Run the same chart on a non-Windows build: events are ignored, no errors.

Report any deviation with the event name, toggle states and log output.
