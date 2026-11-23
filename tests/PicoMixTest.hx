import backend.PicoMix;

/**
 * Pure name-resolution probes for Pico Mix charts.
 * Copy this file plus source/backend/PicoMix.hx into a scratch dir with stub
 * `backend.Paths` and `openfl.utils.AssetType`, then:
 *   haxe -cp <scratch> -main PicoMixTest -neko <scratch>/picotest.n
 *   neko <scratch>/picotest.n
 */
class PicoMixTest
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
		eq(PicoMix.isPicoName('Bopeebo (Pico Mix)'), true, 'pico display name detected');
		eq(PicoMix.isPicoName('Bopeebo'), false, 'base name is not pico');
		eq(PicoMix.isPicoName(null), false, 'null name is not pico');

		eq(PicoMix.baseName('Bopeebo (Pico Mix)'), 'bopeebo', 'pico name maps to base path');
		eq(PicoMix.baseName('Bopeebo'), 'Bopeebo', 'non-pico name unchanged');

		eq(PicoMix.folderFor('Bopeebo'), 'bopeebo-(pico-mix)', 'folder suffix');
		eq(PicoMix.folderFor('Dad Battle!'), 'dad-battle-(pico-mix)', 'folder suffix normalizes');

		eq(PicoMix.isWeekendSong('Darnell'), true, 'Darnell is weekend');
		eq(PicoMix.isWeekendSong('Lit Up'), true, 'Lit Up is weekend');
		eq(PicoMix.isWeekendSong('2Hot'), true, '2Hot is weekend');
		eq(PicoMix.isWeekendSong('Blazin'), true, 'Blazin is weekend');
		eq(PicoMix.isWeekendSong('Bopeebo'), false, 'Bopeebo is not weekend');
		eq(PicoMix.isWeekendSong(null), false, 'null is not weekend');

		backend.Paths.chartExists = true;
		eq(PicoMix.chartExists('Bopeebo', '-hard'), true, 'chart found when installed');
		eq(backend.Paths.lastKey, 'data/bopeebo-(pico-mix)/bopeebo-(pico-mix)-hard.json', 'chart path format');
		backend.Paths.chartExists = false;
		eq(PicoMix.chartExists('Bopeebo'), false, 'chart missing falls back to base');

		if(fails > 0) throw 'PicoMixTest failures=' + fails;
		trace('ALL PicoMixTest PASSED');
	}
}
