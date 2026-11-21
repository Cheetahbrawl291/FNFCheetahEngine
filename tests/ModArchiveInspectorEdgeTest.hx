import backend.ModArchiveInspector;

/**
 * Boundary probes derived from independent verification. Copy this file and
 * `source/backend/ModArchiveInspector.hx` into a scratch directory, then run:
 *   haxe -cp <scratch> -main ModArchiveInspectorEdgeTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class ModArchiveInspectorEdgeTest
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
		eq(ModArchiveInspector.BASE_PSYCH_VERSION, '1.0.4', 'base version constant');
		eq(ModArchiveInspector.findModRoot(['pack.json']), '', 'pack at root');
		eq(ModArchiveInspector.findModRoot(['Mod/pack.json', 'Mod/data/x']), 'Mod/', 'pack in one folder');
		eq(ModArchiveInspector.findModRoot(['A/x.txt', 'B/pack.json']), 'B/', 'pack picks correct folder');
		eq(ModArchiveInspector.findModRoot(['Wrapper/data/song.json', 'Wrapper/images/bf.png']), 'Wrapper/', 'marker scoring no pack');
		eq(ModArchiveInspector.findModRoot(['Wrapper/MyMod/data/a', 'Wrapper/MyMod/images/b', 'Other/readme']), 'Wrapper/MyMod/', 'deepest 2-marker folder wins');
		eq(ModArchiveInspector.findModRoot(['readme.txt']), null, 'single text file rejected');
		eq(ModArchiveInspector.findModRoot(['__MACOSX/foo']), null, 'junk-only rejected');
		eq(ModArchiveInspector.findModRoot([]), null, 'empty rejected');
		eq(ModArchiveInspector.findModRoot(null), null, 'null rejected');
		eq(ModArchiveInspector.externalHostFromText('https://mega.nz/file/x'), 'MEGA', 'mega');
		eq(ModArchiveInspector.externalHostFromText('https://1drv.ms/u/s!abc'), 'OneDrive', 'onedrive short');
		eq(ModArchiveInspector.externalHostFromText('https://www.mediafire.com/file/x/y.zip'), 'MediaFire', 'mediafire');
		eq(ModArchiveInspector.externalHostFromText('https://example.com/mod.zip'), null, 'normal host');
		eq(ModArchiveInspector.externalHostFromText('dropbox.com then drive.google.com'), 'Google Drive', 'first matching host order');
		eq(ModArchiveInspector.externalHostFromText(null), null, 'null text');
		eq(ModArchiveInspector.versionFromPack('{"psychEngineVersion":"1.1.0"}'), '1.1.0', 'psychEngineVersion');
		eq(ModArchiveInspector.versionFromPack('{"engine":"2.0"}'), '2.0', 'engine key');
		eq(ModArchiveInspector.versionFromPack('{"engineVersion":"v0.7.3-hotfix"}'), 'v0.7.3-hotfix', 'suffixed version');
		eq(ModArchiveInspector.versionFromPack('{"version":"1.0","psychVersion":"1.0.4"}'), '1.0.4', 'psych over generic');
		eq(ModArchiveInspector.versionFromPack('{"psychVersion":"abc"}'), null, 'non-numeric declaration');
		eq(ModArchiveInspector.versionFromPack('{}'), null, 'empty object');
		eq(ModArchiveInspector.versionFromPack('[]'), null, 'json array');
		eq(ModArchiveInspector.versionFromPack('null'), null, 'json null');
		eq(ModArchiveInspector.compatibility('1.0.99'), ModArchiveInspector.COMPATIBLE, 'patch ignored');
		eq(ModArchiveInspector.compatibility('1.1.0'), ModArchiveInspector.INCOMPATIBLE, 'newer minor');
		eq(ModArchiveInspector.compatibility('2.0.0'), ModArchiveInspector.INCOMPATIBLE, 'newer major');
		eq(ModArchiveInspector.compatibility('v1.0.4'), ModArchiveInspector.COMPATIBLE, 'v prefix');
		eq(ModArchiveInspector.compatibility(''), ModArchiveInspector.UNKNOWN, 'empty version');

		if(fails > 0) throw 'ModArchiveInspectorEdgeTest failures=' + fails;
	}
}
