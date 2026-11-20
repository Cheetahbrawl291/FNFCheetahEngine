#if windows
package backend;

import flixel.FlxG;
import haxe.io.Path;
import lime.app.Application;
import sys.FileSystem;
import winapi.WindowsAPI;
import winapi.gdi.WindowsGDI;
import winapi.gdi.WindowsGDIThread;

/**
 * Bridges chart events to SL-Windows-API and owns the exit cleanup.
 *
 * Only cosmetic window effects are always allowed. Events that touch the real
 * desktop check the matching ClientPrefs switch before calling the library, so
 * a chart from a mod cannot hide the taskbar or repaint the wallpaper unless the
 * player explicitly enabled that interaction.
 */
class WindowsIntegrations
{
	static var initialized:Bool = false;
	static var restored:Bool = false;
	static var screenshotPaths:Array<String> = [];
	static var gdiEffects:Array<String> = [];

	public static function init():Void
	{
		if (initialized)
			return;

		initialized = true;
		restored = false;

		// The library finds the target window by title, so it needs the real one.
		WindowsAPI.reDefineMainWindowTitle(Application.current.window.title);
	}

	static function log(message:String):Void
	{
		FlxG.log.add('[Windows API] $message');
	}

	static function allowed(setting:Bool, event:String, settingName:String):Bool
	{
		if (setting)
			return true;

		log('$event refused: enable "$settingName" in Options > Windows API');
		return false;
	}

	static function boolValue(value:String, fallback:Bool):Bool
	{
		if (value == null || StringTools.trim(value) == '')
			return fallback;

		return switch (StringTools.trim(value).toLowerCase())
		{
			case 'true' | '1' | 'on' | 'yes': true;
			case 'false' | '0' | 'off' | 'no': false;
			default: fallback;
		};
	}

	static function rgb(value:String):Null<Array<Int>>
	{
		if (value == null)
			return null;

		final parts:Array<String> = value.split(',');
		if (parts.length != 3)
			return null;

		final r:Null<Int> = Std.parseInt(StringTools.trim(parts[0]));
		final g:Null<Int> = Std.parseInt(StringTools.trim(parts[1]));
		final b:Null<Int> = Std.parseInt(StringTools.trim(parts[2]));
		if (r == null || g == null || b == null)
			return null;
		if (r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255)
			return null;

		return [r, g, b];
	}

	/**
	 * Chart paths are relative to the game folder. SL-Windows-API joins them as
	 * `Path.directory(programPath) + path`, so it needs a leading slash; the
	 * returned string here is that library argument, never a filesystem path.
	 * Anything that escapes the game folder is refused.
	 */
	static function safeChartPath(value:String):Null<String>
	{
		if (value == null)
			return null;

		final path:String = StringTools.replace(StringTools.trim(value), '\\', '/');
		if (path == '' || path.indexOf('..') != -1 || path.charAt(0) == '/')
			return null;
		if (~/^[A-Za-z]:/.match(path))
			return null;

		return '/' + path;
	}

	static function absoluteChartPath(libraryPath:String):String
	{
		// libraryPath already starts with '/'; Path.directory has no trailing slash.
		return StringTools.replace(Path.directory(Sys.programPath()), '\\', '/') + libraryPath;
	}

	public static function setBorderColor(value:String):Void
	{
		final color = rgb(value);
		if (color == null)
		{
			log('Set Window Border Color needs R,G,B (0-255)');
			return;
		}
		WindowsAPI.setWindowBorderColor(color[0], color[1], color[2]);
	}

	public static function setTextColor(value:String):Void
	{
		final color = rgb(value);
		if (color == null)
		{
			log('Set Window Text Color needs R,G,B (0-255)');
			return;
		}
		WindowsAPI.setWindowTextColor(color[0], color[1], color[2]);
	}

	public static function setDarkMode(value:String):Void
	{
		WindowsAPI.windowDarkMode(boolValue(value, true));
	}

	public static function setCorner(value:String):Void
	{
		final corner:Null<Int> = Std.parseInt(StringTools.trim(value));
		if (corner == null || corner < 0 || corner > 3)
		{
			log('Set Window Corner needs 0 (default), 1 (none), 2 (round) or 3 (small)');
			return;
		}
		WindowsAPI.setWindowRound(cast corner);
	}

	public static function setOpacity(value:String):Void
	{
		final opacity:Null<Float> = Std.parseFloat(StringTools.trim(value));
		if (opacity == null || Math.isNaN(opacity))
		{
			log('Set Window Opacity needs a number between 0 and 1');
			return;
		}
		WindowsAPI.setWindowOppacity(Math.max(0, Math.min(1, opacity)));
	}

	public static function centerWindow():Void
	{
		WindowsAPI.centerWindow();
	}

	public static function hideTaskbar(value:String):Void
	{
		if (!allowed(ClientPrefs.data.winApiTaskbar, 'Hide Taskbar', 'Taskbar & Desktop Icons'))
			return;
		WindowsAPI.hideTaskbar(boolValue(value, true));
	}

	public static function hideDesktopIcons(value:String):Void
	{
		if (!allowed(ClientPrefs.data.winApiTaskbar, 'Hide Desktop Icons', 'Taskbar & Desktop Icons'))
			return;
		WindowsAPI.hideDesktopIcons(boolValue(value, true));
	}

	public static function moveDesktop(value1:String, value2:String):Void
	{
		if (!allowed(ClientPrefs.data.winApiTaskbar, 'Move Desktop Icons', 'Taskbar & Desktop Icons'))
			return;

		final x:Null<Int> = Std.parseInt(StringTools.trim(value1));
		final y:Null<Int> = Std.parseInt(StringTools.trim(value2));
		if (x == null || y == null)
		{
			log('Move Desktop Icons needs Value 1: X and Value 2: Y');
			return;
		}
		WindowsAPI.moveDesktopWindowsInXY(x, y);
	}

	public static function changeWallpaper(value:String):Void
	{
		if (!allowed(ClientPrefs.data.winApiWallpaper, 'Change Wallpaper', 'Wallpaper Changes'))
			return;

		final path = safeChartPath(value);
		if (path == null)
		{
			log('Change Wallpaper needs a path inside the game folder');
			return;
		}
		// changeWindowsWallpaper saves the original the first time it runs.
		WindowsAPI.changeWindowsWallpaper(path);
	}

	public static function screenCapture(value:String):Void
	{
		if (!allowed(ClientPrefs.data.winApiScreenshots, 'Screen Capture', 'Screen Captures'))
			return;

		final path = safeChartPath(value);
		if (path == null)
		{
			log('Screen Capture needs a path inside the game folder');
			return;
		}
		// Only track screenshots this session creates. If the target already
		// held a user file, never mark it for deletion on exit.
		final full:String = absoluteChartPath(path);
		final existed:Bool = FileSystem.exists(full);
		WindowsAPI.screenCapture(path);
		if (!existed && !FileSystem.exists(full))
		{
			log('Screen Capture wrote no file at $path');
			return;
		}
		if (!existed && !screenshotPaths.contains(path))
			screenshotPaths.push(path);
	}

	public static function gdiEffect(value1:String, value2:String):Void
	{
		if (!allowed(ClientPrefs.data.winApiGdi, 'GDI Effect', 'GDI Effects'))
			return;

		final name:String = StringTools.trim(value1);
		final parts:Array<String> = StringTools.trim(value2).toLowerCase().split(':');
		final enabled:Bool = boolValue(parts[0], true);
		final wait:Float = parts.length > 1 ? Std.parseFloat(parts[1]) : 0;
		final safeWait:Float = (wait > 0 && !Math.isNaN(wait)) ? wait : 0;

		if (name == '')
		{
			log('GDI Effect needs an effect name in Value 1');
			return;
		}

		if (enabled)
		{
			if (!WindowsGDIThread.gdiEffects.exists(name))
				WindowsGDI.prepareGDIEffect(name, safeWait);

			// prepareGDIEffect silently ignores unknown names, so verify it
			// actually registered before starting the thread or tracking it.
			if (!WindowsGDIThread.gdiEffects.exists(name))
			{
				log('Unknown GDI effect "$name" (see Options help for valid names)');
				return;
			}

			WindowsGDI.enableGDIEffect(name, true);
			WindowsGDIThread.initWindowsGDIThread();
			if (!gdiEffects.contains(name))
				gdiEffects.push(name);
			log('GDI effect started: $name');
		}
		else
		{
			WindowsGDI.enableGDIEffect(name, false);
			gdiEffects.remove(name);
			log('GDI effect stopped: $name');
		}
	}

	/**
	 * Restore every OS-level change this process made, then let the caller quit.
	 * Safe to call twice; the crash handler and the window-close hook may both fire.
	 */
	public static function restoreAll():Void
	{
		if (!initialized || restored)
			return;
		restored = true;

		final active:Array<String> = [];
		if (gdiEffects.length > 0)
			active.push('GDI effects: ' + gdiEffects.join(', '));
		if (screenshotPaths.length > 0)
			active.push('screenshots: ' + screenshotPaths.length);
		active.push('taskbar/icons/desktop/wallpaper: reset');
		log('Restoring before exit - ' + active.join('; '));

		try
		{
			for (name in gdiEffects.copy())
				WindowsGDI.enableGDIEffect(name, false);
			WindowsGDIThread.stopWindowsGDIThread();
			gdiEffects = [];
		}
		catch (e:Dynamic)
		{
			log('GDI cleanup failed: $e');
		}

		// Idempotent in the library: shows taskbar/icons, resets desktop position
		// and alpha, and restores the wallpaper only when it was changed.
		try
		{
			WindowsAPI.resetWindowsFuncs();
		}
		catch (e:Dynamic)
		{
			log('Desktop restore failed: $e');
		}

		if (ClientPrefs.data.winApiCleanupScreenshots)
		{
			for (path in screenshotPaths)
			{
				try
				{
					final full:String = absoluteChartPath(path);
					if (FileSystem.exists(full))
						FileSystem.deleteFile(full);
				}
				catch (e:Dynamic)
				{
					log('Could not delete screenshot $path: $e');
				}
			}
		}
		screenshotPaths = [];

		log('Desktop state restored');
	}
}
#end
