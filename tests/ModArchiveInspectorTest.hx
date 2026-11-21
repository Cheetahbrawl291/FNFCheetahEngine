import backend.ModArchiveInspector;

/**
 * Deterministic checks for mod archive inspection and Psych version matching.
 * Copy this file and `source/backend/ModArchiveInspector.hx` into a scratch
 * directory, then run:
 *   haxe -cp <scratch> -main ModArchiveInspectorTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class ModArchiveInspectorTest
{
	static function check(ok:Bool, label:String):Void
	{
		if(!ok) throw 'FAIL: $label';
		trace('PASS: $label');
	}

	static function main():Void
	{
		var flat = ['data/song.json', 'images/characters/bf.png', 'readme.txt'];
		check(ModArchiveInspector.findModRoot(flat) == '', 'flat mod uses archive root');

		var nested = ['Wrapper/readme.txt', 'Wrapper/MyMod/data/song.json', 'Wrapper/MyMod/images/characters/bf.png'];
		check(ModArchiveInspector.findModRoot(nested) == 'Wrapper/MyMod/', 'nested wrapper is skipped');

		var packed = ['Wrapper/readme.txt', 'Wrapper/MyMod/pack.json', 'Wrapper/MyMod/data/song.json'];
		check(ModArchiveInspector.findModRoot(packed) == 'Wrapper/MyMod/', 'pack.json identifies nested mod');

		var prefixed = ['mods/MyMod/pack.json', 'mods/MyMod/data/song.json'];
		check(ModArchiveInspector.findModRoot(prefixed) == 'mods/MyMod/', 'mods prefix is preserved for caller');

		check(ModArchiveInspector.findModRoot(['Outer/pack.json', 'Outer/Inner/pack.json']) == 'Outer/', 'shallowest pack.json wins');
		check(ModArchiveInspector.findModRoot(['readme.txt', 'license.txt', 'preview.png']) == null, 'archive without mod content is rejected');
		check(ModArchiveInspector.findModRoot([]) == null, 'empty archive is rejected');

		check(ModArchiveInspector.externalHostFromText('{"_sDownloadUrl":"https://drive.google.com/file/d/abc"}') == 'Google Drive', 'Google Drive link is detected');
		check(ModArchiveInspector.externalHostFromText('{"_sDownloadUrl":"https://www.dropbox.com/s/abc/mod.zip"}') == 'Dropbox', 'Dropbox link is detected');
		check(ModArchiveInspector.externalHostFromText('{"_sFile":"mod.zip"}') == null, 'normal GameBanana file has no external host');

		check(ModArchiveInspector.versionFromPack('{"psychVersion":"1.0.4"}') == '1.0.4', 'psychVersion is read');
		check(ModArchiveInspector.versionFromPack('{"requiredPsychVersion":"0.7.3"}') == '0.7.3', 'requiredPsychVersion is read');
		check(ModArchiveInspector.versionFromPack('{"version":"1.0"}') == null, 'mod version is not a Psych version');
		check(ModArchiveInspector.versionFromPack('not json') == null, 'invalid pack.json is ignored');

		check(ModArchiveInspector.compatibility(null) == ModArchiveInspector.UNKNOWN, 'missing version is unknown');
		check(ModArchiveInspector.compatibility('1.0.4') == ModArchiveInspector.COMPATIBLE, 'base version is compatible');
		check(ModArchiveInspector.compatibility('1.0') == ModArchiveInspector.COMPATIBLE, 'same major.minor is compatible');
		check(ModArchiveInspector.compatibility('v1.0.4-hotfix') == ModArchiveInspector.COMPATIBLE, 'suffixes are ignored');
		check(ModArchiveInspector.compatibility('0.7.3') == ModArchiveInspector.INCOMPATIBLE, 'older Psych line is incompatible');
		check(ModArchiveInspector.compatibility('garbage') == ModArchiveInspector.UNKNOWN, 'unparseable version is unknown');
	}
}
