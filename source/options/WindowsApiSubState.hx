#if windows
package options;

/**
 * Settings for the Windows API song events.
 *
 * Every switch here starts off. Chart events that hide the taskbar or desktop
 * icons, change the wallpaper, capture the screen or run GDI effects are refused
 * until the matching switch is enabled. The engine restores the desktop on exit
 * regardless of these values; the screenshot switch below only controls whether
 * files taken during this session are deleted before quitting.
 */
class WindowsApiSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('windows_api_menu', 'Windows API');
		rpcTitle = 'Windows API Settings';

		var option:Option = new Option('Taskbar & Desktop Icons',
			'Allows chart events to hide or show the Windows taskbar\nand the desktop icons. Off by default.',
			'winApiTaskbar',
			BOOL);
		addOption(option);

		var option:Option = new Option('Wallpaper Changes',
			'Allows chart events to change the Windows wallpaper.\nThe original wallpaper is saved before the first change\nand restored when the game closes.',
			'winApiWallpaper',
			BOOL);
		addOption(option);

		var option:Option = new Option('Screen Captures',
			'Allows chart events to write screenshots of the whole\nscreen into the game folder. Off by default.',
			'winApiScreenshots',
			BOOL);
		addOption(option);

		var option:Option = new Option('GDI Effects',
			'Allows chart events to start full-screen GDI effects.\nThese draw over the whole desktop and come from code\nderived from malware. The engine stops them on exit.',
			'winApiGdi',
			BOOL);
		addOption(option);

		var option:Option = new Option('Delete Session Screenshots',
			'When checked, screenshots taken by chart events during\nthis session are deleted on exit. Screenshots are files,\nnot system state, so nothing is removed unless you enable this.',
			'winApiCleanupScreenshots',
			BOOL);
		addOption(option);

		super();
	}
}
#end
