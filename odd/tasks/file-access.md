# Script file access sandbox

Objective: stop a Lua/HScript mod from deleting or overwriting files outside its own mod folder, with a user-facing switch.
Branch: `main` (uncommitted work, same tree as the accessibility feature).
Test runner: `lime build linux -debug` (no automated test suite in this repo); checks are compile + manual runtime probes.

## Specs

S1. Options entry. Verbatim from the request:
   > "quiero que en el menu de opciones este la configuracion de acceso a archivos"
   Required: `Options` lists a `File Access` entry that opens `options.FileAccessSubState`, translated as `Acceso a archivos`.

S2. Safe Mode switch. Verbatim from the request:
   > "desde hay puedes permitir o desacrivar el safe mode"
   Required: a `Safe Mode` boolean in that submenu, persisted in `ClientPrefs.data.safeMode`, default `true`.
   Enforcement: with Safe Mode on, script writes and deletes are limited to the mods folder; reads may also reach the executable's folder. Nothing else is allowed.

S3. Per type switches. Verbatim from the request:
   > "si esta desactivado poder elejir a que tipo de archivos accede y a cuales no"
   Required: with Safe Mode off, five booleans decide by extension category — data (txt, json, xml, csv, lang, ini, md, frag, vert), scripts (lua, hx, hscript, hxs), images (png, jpg, jpeg, webp, gif), audio (ogg, mp3, wav, flac), other (everything else). All default `true`, so turning Safe Mode off restores vanilla behavior exactly.
   With Safe Mode on these switches are ignored, and their descriptions say so instead of hiding them.

S4. Lua enforcement. The five file callbacks in `psychlua/ExtraFunctions.hx` (`checkFileExists`, `saveFile`, `deleteFile`, `getTextFromFile`, `directoryFileList`) resolve the path first and then ask `FileAccess.check`, which logs the denial with the script name. Paths containing `..` are always refused.

S5. Lua class-resolution enforcement. `getPropertyFromClass`, `setPropertyFromClass`, `callMethodFromClass` and `createInstance` in `psychlua/ReflectionFunctions.hx` refuse `sys.io`, `sys.FileSystem`, `sys.net`, `sys.ssl`, `lime.system`, `sys.Process` and `sys.net.Socket` while Safe Mode is on. Without this, `callMethodFromClass('sys.io.File', 'saveContent', ...)` bypasses S4 entirely.

S6. HScript enforcement (partial, by design). While Safe Mode is on:
   - `HScript` refuses source containing `sys.io`, `sys.FileSystem`, `sys.net`, `sys.ssl`, `lime.system` or `process.`, both when loaded from disk and through `runHaxeCode`;
   - `addHaxeLibrary` refuses the same packages and the classes `File`, `FileSystem`, `Process`, `Socket`.
   Honest limitation: HScript is arbitrary Haxe compiled at runtime, and `Type.resolveClass` with a constructed string still reaches those classes. This is a speed bump for ordinary mods, not a wall. Closing it fully would require removing `Type`/`Reflect`/`import` from the interpreter, which breaks most HScript mods.

S7. Diagnostics. Every denial writes one warning to `FlxG.log` with the script name, the operation and the path, plus the active rule (`Safe Mode: outside the mods folder` or the list of disabled types).

## Tasks

| ID | Spec | Status | Evidence |
|----|------|--------|----------|
| T1 | S2, S3 | done | `ClientPrefs.SaveVariables` fields `safeMode`, `fileAccess*` (default `true`) |
| T2 | S1 | done | `options/FileAccessSubState.hx`, `OptionsState` list + `openSelectedSubstate` |
| T3 | S2, S3, S7 | done | `backend/FileAccess.hx` policy engine |
| T4 | S4 | done | `psychlua/ExtraFunctions.hx` five callbacks |
| T5 | S5 | done | `psychlua/ReflectionFunctions.hx` four callbacks |
| T6 | S6 | done | `psychlua/HScript.hx` constructor, `initHaxeModuleCode`, `addHaxeLibrary` (both), `runHaxeCode` |
| T7 | S1 | done | `es-ES.lang` keys `options_file_access`, `file_access_menu`, `setting_*`, `description_*` |

## Log

L1. Original request, verbatim:
   > "añadamos el sandbox. quiero que en el menu de opciones este la configuracion de acceso a archivos y desde hay puedes permitir o desacrivar el safe mode y si esta desactivado poder elejir a que tipo de archivos accede y a cuales no"

L2. Design: two layers instead of a flat allowlist. Safe Mode is the location rule; with it off, the per type switches are the rule. This keeps one switch that means "safe" and a fallback that is exactly vanilla behavior.

L3. Found while implementing (`ReflectionFunctions.hx`): Lua can resolve arbitrary classes by name, so gating only the `sys.io` calls in `ExtraFunctions` would have been decorative. Class resolution is gated too (S5).

L4. `Paths.mods()` returns a relative `mods/` path, so the first version of `FileAccess` compared relative against absolute and would have allowed everything. `FileAccess.absolute()` resolves through `FileSystem.absolutePath` before comparing (system: no test suite).

L5. Compile clean (`lime build linux -debug`, several times). Boot probe: 8s run, no crash.

L6. Functional verification: a temporary boot probe (`source/debug/FileAccessProbe.hx`, removed after the run) exercised the policy against a real game boot. 15/15 PASS:
   - Safe Mode on: write outside mods denied, write inside mods allowed, delete outside mods denied, read of `assets/shared/data/es-ES.lang` allowed, `..` traversal denied, read of `/etc/passwd` denied.
   - Safe Mode off: data off denied, all types on allowed, images off denied, other off denied.
   - HScript gates: `sys.io` source blocked, plain source allowed, `sys.io.File` and `sys.net.Socket` blocked, `FlxSprite` allowed.
   The probe log is the evidence for S2-S6; the menu itself (S1) was not clicked, because this session cannot display images.
