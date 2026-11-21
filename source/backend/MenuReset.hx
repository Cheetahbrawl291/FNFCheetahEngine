package backend;

#if sys
import sys.FileSystem;
#end

/**
 * Pure helpers for the "reset custom main menu" action in Cheetah Options.
 * Kept free of Flixel and ClientPrefs so the path rules can be tested in isolation.
 */
class MenuReset
{
	public static inline var MAIN_MENU_FILE:String = 'mainmenu.json';
	public static inline var MENU_CUSTOM_FILE:String = 'menu_custom.json';

	/** The two config files whose presence overrides the built-in main menu. */
	public static function configPaths(?mod:String):Array<String>
	{
		var base:String = (mod != null && mod.length > 0) ? 'mods/$mod/data' : 'mods/data';
		return ['$base/$MAIN_MENU_FILE', '$base/$MENU_CUSTOM_FILE'];
	}

	/**
	 * Delete every existing config file. Missing files are ignored so the action
	 * is safe to repeat. Returns how many files were actually removed.
	 */
	public static function reset(?mod:String):Int
	{
		#if sys
		var removed:Int = 0;
		for (path in configPaths(mod))
		{
			try
			{
				if (FileSystem.exists(path))
				{
					FileSystem.deleteFile(path);
					removed++;
				}
			}
			catch (e:Dynamic)
			{
				trace('MenuReset: could not delete $path ($e)');
			}
		}
		return removed;
		#else
		return 0;
		#end
	}
}
