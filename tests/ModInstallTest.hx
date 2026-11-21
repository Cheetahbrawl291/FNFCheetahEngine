import backend.ModBrowser;
import backend.Paths;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.zip.Entry;
import haxe.zip.Writer;
import sys.FileSystem;

/**
 * End-to-end check for nested mod extraction. Copy this file, `source/backend/ModBrowser.hx`,
 * `source/backend/ModArchiveInspector.hx` and the `tests/mod-install/` scaffolding
 * into a scratch directory, then run:
 *   haxe -cp <scratch> -main ModInstallTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class ModInstallTest
{
	static function check(ok:Bool, label:String):Void
	{
		if(!ok) throw 'FAIL: $label';
		trace('PASS: $label');
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
		var output:BytesOutput = new BytesOutput();
		var list:List<Entry> = new List();
		for(item in entries) list.add(item);
		new Writer(output).write(list);
		return output.getBytes();
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
		var tempRoot:String = Sys.getEnv('TMPDIR');
		if(tempRoot == null || tempRoot.length < 1) tempRoot = '/tmp';
		var root:String = tempRoot + '/cheetah-mod-install-' + Date.now().getTime();
		FileSystem.createDirectory(root);
		Paths.root = root;

		try
		{
			var data:Bytes = zipOf([
				entry('Wrapper/readme.txt', 'wrapper notes'),
				entry('Wrapper/MyMod/pack.json', '{"psychVersion":"1.0.4"}'),
				entry('Wrapper/MyMod/data/song.json', '{}')
			]);

			var notice:Null<String> = null;
			var folder:String = ModBrowser.extractZip(data, 'Fallback', null, function(text:String) notice = text);

			check(folder == 'MyMod', 'nested mod folder is selected');
			check(FileSystem.exists(root + '/MyMod/pack.json'), 'mod files land in mods/MyMod');
			check(!FileSystem.exists(root + '/Fallback'), 'preferred fallback name is not used');
			check(!FileSystem.exists(root + '/MyMod/Wrapper'), 'wrapper is not copied inside the mod');
			check(notice != null && notice.indexOf('compatible') >= 0, 'compatibility notice is returned');

			var noMod:Bytes = zipOf([entry('readme.txt', 'hello'), entry('license.txt', 'MIT')]);
			var rejected:Bool = false;
			try ModBrowser.extractZip(noMod, 'Fallback') catch(e:Dynamic)
				rejected = Std.string(e).indexOf('does not contain a Psych Engine mod') >= 0;
			check(rejected, 'archive without mod content is rejected');
			check(!FileSystem.exists(root + '/Fallback'), 'rejected archive writes nothing');
		}
		catch(e:Dynamic)
		{
			cleanup(root);
			throw e;
		}
		cleanup(root);
	}
}
