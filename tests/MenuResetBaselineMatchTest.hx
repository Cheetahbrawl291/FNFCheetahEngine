import backend.MenuReset;

/**
 * Regression probe from independent verification (S4): the reset helper's path
 * formula must stay identical to MainMenuConfig.path()/MenuCustomization.path()
 * for every realistic mod directory. Pure, no filesystem writes.
 * Copy this file and `source/backend/MenuReset.hx` into a scratch directory:
 *   haxe -cp <scratch> -main MenuResetBaselineMatchTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class MenuResetBaselineMatchTest
{
	static var fails = 0;

	static function eq(a:Dynamic, b:Dynamic, label:String):Void
	{
		if(Std.string(a) == Std.string(b))
			trace('PASS ' + label);
		else
		{
			fails++;
			trace('FAIL ' + label + ' expected=' + Std.string(b) + ' actual=' + Std.string(a));
		}
	}

	static function base(?mod:String):String
	{
		return (mod != null && mod.length > 0) ? 'mods/$mod/data' : 'mods/data';
	}

	static function main():Void
	{
		for(m in [null, '', 'myMod', 'mod with space', 'a/b', '..', 'Ünïcøde'])
		{
			var p:Array<String> = MenuReset.configPaths(m);
			eq(p.length, 2, 'count ' + m);
			eq(p[0], base(m) + '/mainmenu.json', 'mainmenu ' + m);
			eq(p[1], base(m) + '/menu_custom.json', 'menu_custom ' + m);
		}

		if(fails > 0) throw 'MenuResetBaselineMatchTest fails=' + fails;
		trace('ALL MenuResetBaselineMatchTest PASSED');
	}
}
