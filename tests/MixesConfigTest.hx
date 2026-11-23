import backend.MixesConfig;

/**
 * Pure data probes for the Mixes Editor config.
 * Copy this file plus source/backend/MixesConfig.hx into a scratch dir with
 * stub `backend.Mods` and `backend.Paths` (formatToSongPath), then:
 *   cd <scratch> && haxe -cp <scratch> -main MixesConfigTest --interp
 *
 * Run with the scratch dir as CWD: this probe calls save() and would otherwise
 * write test-only marks into the real mods/data/mixes.json.
 */
class MixesConfigTest
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
		MixesConfig.forget();
		eq(MixesConfig.pairs().length, 0, 'fresh config has no pairs');
		eq(MixesConfig.kind('Bopeebo'), null, 'unmarked song has no kind');

		MixesConfig.setKind('Bopeebo Erect', MixesConfig.ERECT);
		eq(MixesConfig.kind('Bopeebo Erect'), 'erect', 'mark normalizes name');
		MixesConfig.setKind('Bopeebo Erect', null);
		eq(MixesConfig.kind('Bopeebo Erect'), null, 'clearing mark removes it');

		MixesConfig.link('Bopeebo Erect', 'Bopeebo');
		eq(MixesConfig.kind('Bopeebo'), 'erect', 'link marks second arg erect');
		eq(MixesConfig.kind('Bopeebo Erect'), 'normal', 'link marks first arg normal');
		eq(MixesConfig.linkedErect('Bopeebo Erect'), 'bopeebo', 'linkedErect resolves target');
		eq(MixesConfig.linkedNormal('Bopeebo'), 'bopeebo-erect', 'linkedNormal reverses');
		eq(MixesConfig.pairs().length, 1, 'one pair stored');

		MixesConfig.link('Bopeebo Erect', 'FRESH!');
		eq(MixesConfig.pairs().length, 1, 'pair count stays one after relink');
		eq(MixesConfig.kind('Bopeebo'), null, 'old partner mark removed');
		eq(MixesConfig.linkedErect('Bopeebo Erect'), 'fresh', 'new partner stored');

		MixesConfig.unlink('Bopeebo Erect');
		eq(MixesConfig.pairs().length, 0, 'unlink removes pair');
		eq(MixesConfig.kind('FRESH!'), 'erect', 'unlink keeps explicit marks');

		MixesConfig.link('Song A', 'Song A Erect');
		eq(MixesConfig.save(), true, 'save writes config');
		MixesConfig.forget();
		eq(MixesConfig.pairs().length, 1, 'reload restores pair');
		eq(MixesConfig.kind('song-a'), 'normal', 'reload restores mark');
		eq(MixesConfig.linkedErect('Song A'), 'song-a-erect', 'reload restores link');

		// Switching the selected mod must not reuse another mod's cached config.
		MixesConfig.forget();
		backend.Mods.currentModDirectory = null;
		MixesConfig.setKind('Global Only', MixesConfig.NORMAL);
		eq(MixesConfig.save(), true, 'global config save');
		backend.Mods.currentModDirectory = 'otherMod';
		eq(MixesConfig.kind('Global Only'), null, 'mod switch isolates marks');
		MixesConfig.setKind('Mod Only', MixesConfig.ERECT);
		eq(MixesConfig.kind('Mod Only'), 'erect', 'mod config independent');
		backend.Mods.currentModDirectory = null;
		eq(MixesConfig.kind('Global Only'), 'normal', 'switch back restores global config');

		// Weekend 1 songs are Pico-sung in the base game.
		eq(MixesConfig.kind('Darnell'), 'pico', 'weekend Darnell defaults to pico');
		eq(MixesConfig.kind('Lit Up'), 'pico', 'weekend Lit Up defaults to pico');
		eq(MixesConfig.kind('2Hot'), 'pico', 'weekend 2Hot defaults to pico');
		eq(MixesConfig.kind('Blazin'), 'pico', 'weekend Blazin defaults to pico');
		eq(MixesConfig.kind('Bopeebo'), null, 'non-weekend song stays unmarked');
		eq(MixesConfig.isPicoOnly('Darnell'), true, 'weekend song is pico-only');
		eq(MixesConfig.isPicoOnly('Bopeebo'), false, 'base song is not pico-only');
		MixesConfig.setKind('Bopeebo', MixesConfig.PICO);
		eq(MixesConfig.isPicoOnly('Bopeebo'), true, 'explicit pico mark is pico-only');
		MixesConfig.setKind('Bopeebo', null);
		MixesConfig.setKind('Darnell', MixesConfig.NORMAL);
		eq(MixesConfig.kind('Darnell'), 'normal', 'explicit mark overrides weekend default');
		MixesConfig.setKind('Darnell', MixesConfig.PICO);
		eq(MixesConfig.kind('Darnell'), 'pico', 'pico mark accepted by sanitize');
		MixesConfig.setKind('Darnell', null);
		eq(MixesConfig.kind('Darnell'), 'pico', 'clearing mark restores weekend default');

		if(fails > 0) throw 'MixesConfigTest failures=' + fails;
		trace('ALL MixesConfigTest PASSED');
	}
}
