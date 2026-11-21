![Cheetah Engine logo](docs/img/CheetahEngineLogo.png)

#### Customization

If you wish to disable things like *Lua Scripts* or *Video Cutscenes*, refer to the `Project.xml` file.

Inside `Project.xml` you will find several variables to customize the engine to your liking.

To start you off, disabling *Video Cutscenes* is simple: delete the `"VIDEOS_ALLOWED"` line or comment it out by wrapping it in XML-like comments, like this: `<!-- YOUR_LINE_HERE -->`.

The same goes for *Lua Scripts*: comment out or delete the line with `LUA_ALLOWED`. These and other customization options are all available in `Project.xml`.

## Modding and scripting

For scripting with `.lua` and `.hx`, head over to [the wiki](https://shadowmario.github.io/psychengine.lua).

There you can learn how to use the 212 PlayState functions in your mod.

## What Cheetah Engine adds

### Accessibility

Found in **Options → Accessibility**:

- **Colorblind-safe palettes** for lane colors, applied to arrows, strums and note splashes. `Off` keeps the original behavior and your custom Note Colors.
- **Reduced camera shake** damps every gameplay shake, including event, Lua and stage-scripted ones. Stage scripts cannot bypass it.
- **Text size** scales the sprite-font text used by menus and dialogue. Default is `1.0`.
- **Automatic offset calibration** is available in **Options → Note/Beat Delay**: press **C** (keyboard) or **Y** (gamepad), then tap along with the beat 8 times using the note keys. The measured offset is applied and saved. Manual adjustment still works as before.

### File Access sandbox

Found in **Options → File Access**. Lua/HScript mods otherwise have full filesystem access, so this sandbox limits what a downloaded mod can touch:

- **Safe Mode** (on by default) confines script writes and deletes to the mods folder. Reads may also reach the executable's folder. Paths containing `..` are always refused.
- With Safe Mode off, five switches decide access by file type: data (`txt`, `json`, `xml`, `csv`, `lang`, `ini`, `md`, `frag`, `vert`), scripts (`lua`, `hx`, `hscript`, `hxs`), images (`png`, `jpg`, `jpeg`, `webp`, `gif`), audio (`ogg`, `mp3`, `wav`, `flac`) and other. All default to `true`, so turning Safe Mode off restores the original behavior exactly.
- While Safe Mode is on, scripts cannot resolve filesystem, network, process or Lime system classes by name (`sys.io`, `sys.FileSystem`, `sys.net`, `sys.ssl`, `lime.system`, `sys.Process`, `sys.net.Socket`).
- Every denial is logged with the script name, operation, path and the rule that blocked it.

> **Note:** HScript is arbitrary Haxe compiled at runtime. The HScript gate is a speed bump for ordinary mods, not a security wall; determined code using constructed class names can still get through.

### Mod browser

**Mods → INSTALL MODS** opens an in-game browser for GameBanana's [Psych Mod Folders](https://gamebanana.com/mods/cats/28367) category. It shows 10 mods per page with name, author, category and views, and supports next/previous page.

Selecting a mod downloads the first non-archived `.zip` from its profile page and extracts it into `mods/`. The installer detects the mod folder inside the archive, strips a leading `mods/` prefix, rejects path traversal entries, skips `__MACOSX/`, `.DS_Store` and `Thumbs.db`, and never overwrites an existing folder (it appends a numeric suffix). The mod is then registered as enabled in `modsList.txt`; a game restart is required.

Downloads are capped at 400 MB because the archive is held in memory. Before the first install of a session, an in-state warning reminds you that mods are third-party code that can run Lua/HScript and to install only trusted mods.

### Editors

- The Menu Customization Hub is trimmed down to the Main Menu editor.
- **Achievement Editor** is available from debug key 7. It lets you create, modify and remove custom achievements, with a unique save key, display name, description, hidden flag, max score and max decimals. Built-in achievements cannot be overwritten.
- Custom achievements can have their own icon under `images/`, with a live preview in the editor.
- A new **Unlock Achievement** chart editor event unlocks an achievement by save key when playback reaches it.
- All other existing editors keep working as before.

### Base game content

The original weeks and songs are restored in debug builds, including their weeks, characters, stages, audio and charts.

### Windows API song events

Windows builds can drive the OS window and desktop from chart events. The Chart Editor lists every event with its value formats; the gates live in **Options → Windows API**:

- Always available: window border and title-bar text color, dark mode, corner style, opacity and centering.
- Disabled by default, one switch each: hiding the taskbar or desktop icons, changing the wallpaper, screen captures and GDI effects. A chart cannot use any of them until you enable the matching switch.
- On exit, including the crash path, the engine restores the taskbar, desktop icons, desktop position/alpha and wallpaper, and stops every GDI effect. Screenshots taken during the session are deleted only if you enable that option.
- Non-Windows builds keep compiling; these events are ignored there.

Requires `sl-windows-api` (`haxelib install sl-windows-api`) plus the Windows toolchain from the build instructions.

## Credits

### Cheetah Engine Team<br/>

[Cheetah](https://www.youtube.com/@CheetahTheGamer) - Owner<br/>[IamDanteDav](https://www.youtube.com/@IamDanteDev) - Coder<br/>[Commander Video](https://gamebanana.com/members/1787065) - [Modchart editor](https://gamebanana.com/scripts/12931)<br/>[Slushi](https://github.com/Slushi-Github) - [Windows API](https://github.com/Slushi-Github/SL-Windows-API/)<br/>


### Psych Engine Team<br/>

### The Funkin Crew Inc.
