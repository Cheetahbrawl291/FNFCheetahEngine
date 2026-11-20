import backend.ModchartEditorDetector;

/**
 * Deterministic checks for the Lua editor detector. Copy this file and
 * `source/backend/ModchartEditorDetector.hx` into a scratch directory, then run:
 *   haxe -cp <scratch> -main ModchartEditorDetectorTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 * The scratch copy keeps the game's global `import.hx` out of the compile.
 */
class ModchartEditorDetectorTest
{
	static function check(ok:Bool, label:String):Void
	{
		if(!ok) throw 'FAIL: $label';
		trace('PASS: $label');
	}

	static function main():Void
	{
		check(!ModchartEditorDetector.isEditorSource(null), 'null source is not editor');
		check(!ModchartEditorDetector.isEditorSource(''), 'empty source is not editor');
		check(!ModchartEditorDetector.isEditorSource('--[[ LUA Modchart Editor v1.2.2 ]]'), 'title without author is not editor');
		check(!ModchartEditorDetector.isEditorSource('--[[ by .bakugo ]]'), 'author without title is not editor');

		var realHeader = '--[[\r\nLUA Modchart Editor v1.2.2 by .bakugo / CommanderVideo\r\n]]\r\nlocal x = 1';
		check(ModchartEditorDetector.isEditorSource(realHeader), 'real header is editor');

		check(ModchartEditorDetector.versionOverrideFor(realHeader, false) == null, 'disabled pref gives no override');
		check(ModchartEditorDetector.versionOverrideFor(realHeader, true) == '1.0.4', 'enabled pref gives Psych override');
		check(ModchartEditorDetector.versionOverrideFor('local x = 1', true) == null, 'other script gets no override');
	}
}
