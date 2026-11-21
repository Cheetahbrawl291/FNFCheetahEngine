import backend.MenuReset;

/**
 * Pure path-resolution probes for the Cheetah Options main-menu reset.
 * Copy this file and `source/backend/MenuReset.hx` into a scratch directory:
 *   haxe -cp <scratch> -main MenuResetTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class MenuResetTest
{
	static var fails = 0;

	static function eq(actual:Dynamic, expected:Dynamic, label:String):Void
	{
		if(Std.string(actual) == Std.string(expected))
			trace('PASS ' + label + ' => ' + Std.string(actual));
		else
		{
			fails++;
			trace('FAIL ' + label + ' expected=' + Std.string(expected) + ' actual=' + Std.string(actual));
		}
	}

	static function main():Void
	{
		var global:Array<String> = MenuReset.configPaths();
		eq(global.length, 2, 'global config file count');
		eq(global[0], 'mods/data/mainmenu.json', 'global mainmenu path');
		eq(global[1], 'mods/data/menu_custom.json', 'global menu_custom path');

		var modPaths:Array<String> = MenuReset.configPaths('myMod');
		eq(modPaths.length, 2, 'mod config file count');
		eq(modPaths[0], 'mods/myMod/data/mainmenu.json', 'mod mainmenu path');
		eq(modPaths[1], 'mods/myMod/data/menu_custom.json', 'mod menu_custom path');

		eq(MenuReset.configPaths('')[0], 'mods/data/mainmenu.json', 'empty mod falls back to global');
		eq(MenuReset.configPaths(null)[0], 'mods/data/mainmenu.json', 'null mod falls back to global');

		if(fails > 0) throw 'MenuResetTest failures=' + fails;
		trace('ALL MenuResetTest PASSED');
	}
}
