import backend.ModBrowser;
import backend.Paths;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.zip.Entry;
import haxe.zip.Writer;
import sys.FileSystem;

/**
 * Extraction and compatibility edge probes derived from independent verification.
 * Needs `tests/mod-install/` scaffolding. Copy this file, `tests/mod-install/`,
 * `source/backend/ModBrowser.hx` and `source/backend/ModArchiveInspector.hx`
 * into a scratch directory, then run:
 *   haxe -cp <scratch> -main ModInstallEdgeTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class ModInstallEdgeTest
{
	static var fails = 0;
	static var tmp:String;
	static var roots:Array<String> = [];

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

	static function entry(name:String, content:String):Entry
	{
		var data:Bytes = Bytes.ofString(content);
		return {
			fileName: name,
			fileSize: data.length,
			dataSize: data.length,
			fileTime: Date.now(),
			data: data,
			compressed: false,
			crc32: null
		};
	}

	static function zipOf(entries:Array<Entry>):Bytes
	{
		var out:BytesOutput = new BytesOutput();
		var list:List<Entry> = new List();
		for(item in entries) list.add(item);
		new Writer(out).write(list);
		return out.getBytes();
	}

	static function newRoot(label:String):String
	{
		var root:String = tmp + '/miet-' + label + '-' + Date.now().getTime();
		FileSystem.createDirectory(root);
		roots.push(root);
		Paths.root = root;
		return root;
	}

	static function errorOf(bytes:Bytes, name:String):String
	{
		try
		{
			ModBrowser.extractZip(bytes, name);
			return 'NO_ERROR';
		}
		catch(e:Dynamic) return Std.string(e);
	}

	static function cleanup(path:String):Void
	{
		if(!FileSystem.exists(path)) return;
		for(name in FileSystem.readDirectory(path))
		{
			var child:String = path + '/' + name;
			if(FileSystem.isDirectory(child)) cleanup(child);
			else FileSystem.deleteFile(child);
		}
		FileSystem.deleteDirectory(path);
	}

	static function main():Void
	{
		tmp = Sys.getEnv('TMPDIR');
		if(tmp == null || tmp.length < 1) tmp = '/tmp';

		try
		{
			var rA:String = newRoot('A');
			var noticeA:Null<String> = null;
			var fA:String = ModBrowser.extractZip(zipOf([
				entry('Wrapper/readme.txt', 'notes'),
				entry('Wrapper/MyMod/data/song.json', '{}'),
				entry('Wrapper/MyMod/images/bf.png', 'png')
			]), 'Preferred', null, function(text:String) noticeA = text);
			eq(fA, 'MyMod', 'nested folder without pack.json');
			eq(FileSystem.exists(rA + '/MyMod/data/song.json'), true, 'mod files placed');
			eq(FileSystem.exists(rA + '/Wrapper'), false, 'wrapper not installed');
			eq(FileSystem.exists(rA + '/Preferred'), false, 'fallback not used');
			eq(noticeA != null && noticeA.indexOf('unknown') >= 0, true, 'unknown-version notice');

			var rB:String = newRoot('B');
			var fB:String = ModBrowser.extractZip(zipOf([
				entry('pack.json', '{}'),
				entry('data/song.json', '{}')
			]), 'Preferred');
			eq(fB, 'Preferred', 'flat folder uses preferred name');
			eq(FileSystem.exists(rB + '/Preferred/pack.json'), true, 'pack at mod root');

			var rC:String = newRoot('C');
			var fC:String = ModBrowser.extractZip(zipOf([
				entry('mods/MyMod/pack.json', '{}'),
				entry('mods/MyMod/data/song.json', '{}')
			]), 'Preferred');
			eq(fC, 'MyMod', 'mods prefix stripped');

			var rD:String = newRoot('D');
			var fD:String = ModBrowser.extractZip(zipOf([
				entry('../evil.txt', 'bad'),
				entry('C:/abs.txt', 'bad'),
				entry('MyMod/pack.json', '{}'),
				entry('MyMod/data/song.json', '{}')
			]), 'Preferred');
			eq(fD, 'MyMod', 'mod still installed with unsafe entries');
			eq(FileSystem.exists(rD + '/evil.txt') || FileSystem.exists(tmp + '/evil.txt'), false, 'no zip-slip write');
			eq(FileSystem.exists(rD + '/C:'), false, 'no absolute write');

			var rE:String = newRoot('E');
			var fE:String = ModBrowser.extractZip(zipOf([
				entry('__MACOSX/junk', 'j'),
				entry('MyMod/.DS_Store', 'd'),
				entry('MyMod/pack.json', '{}'),
				entry('MyMod/data/song.json', '{}')
			]), 'Preferred');
			eq(fE, 'MyMod', 'junk skipped');
			eq(FileSystem.exists(rE + '/MyMod/.DS_Store'), false, 'DS_Store not written');

			var rF:String = newRoot('F');
			var zf:Bytes = zipOf([
				entry('MyMod/pack.json', '{}'),
				entry('MyMod/data/song.json', '{}')
			]);
			eq(ModBrowser.extractZip(zf, 'Preferred') + ',' + ModBrowser.extractZip(zf, 'Preferred'), 'MyMod,MyMod-2', 'unique naming');

			var rG:String = newRoot('G');
			var noticeG:Null<String> = null;
			var fG:String = ModBrowser.extractZip(zipOf([
				entry('MyMod/pack.json', '{"psychVersion":"0.7.3"}'),
				entry('MyMod/data/song.json', '{}')
			]), 'Preferred', null, function(text:String) noticeG = text);
			eq(fG, 'MyMod', 'incompatible version still installs');
			eq(noticeG != null && noticeG.indexOf('warning') >= 0, true, 'warning notice');

			var rH:String = newRoot('H');
			sys.io.File.saveContent(rH + '/sentinel.txt', 'unchanged');
			var before:String = sys.io.File.getContent(rH + '/sentinel.txt');
			eq(errorOf(zipOf([entry('readme.txt', 'hello'), entry('license.txt', 'MIT')]), 'Preferred'),
				'This archive does not contain a Psych Engine mod. Download it and install it manually into mods/.',
				'exact rejection text');
			eq(sys.io.File.getContent(rH + '/sentinel.txt') == before, true, 'sentinel unchanged after rejection');
			eq(FileSystem.exists(rH + '/Preferred'), false, 'nothing written after rejection');

			newRoot('I');
			eq(errorOf(zipOf([]), 'Preferred'), 'The .zip archive is empty.', 'empty archive exact error');
		}
		catch(e:Dynamic)
		{
			for(root in roots) cleanup(root);
			throw e;
		}

		for(root in roots) cleanup(root);
		if(fails > 0) throw 'ModInstallEdgeTest failures=' + fails;
	}
}
