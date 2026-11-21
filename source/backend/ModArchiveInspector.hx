package backend;

import haxe.Json;

/**
 * Pure helpers for deciding what a mod archive contains and which Psych Engine
 * line it targets. No filesystem or network access, so this is testable alone.
 */
class ModArchiveInspector
{
	public static inline var BASE_PSYCH_VERSION:String = '1.0.4';
	public static inline var COMPATIBLE:String = 'compatible';
	public static inline var INCOMPATIBLE:String = 'incompatible';
	public static inline var UNKNOWN:String = 'unknown';

	static var MOD_MARKERS:Array<String> = [
		'data', 'images', 'characters', 'songs', 'scripts', 'stages', 'fonts', 'videos',
		'music', 'sounds', 'shaders', 'weeks', 'achievements', 'custom_events',
		'custom_notetypes', 'pack.json', 'pack.xml', 'mod.json'
	];

	static var EXTERNAL_HOSTS:Array<{needle:String, label:String}> = [
		{needle: 'drive.google.com', label: 'Google Drive'},
		{needle: 'docs.google.com', label: 'Google Drive'},
		{needle: 'goo.gl', label: 'Google Drive'},
		{needle: 'dropbox.com', label: 'Dropbox'},
		{needle: 'mega.nz', label: 'MEGA'},
		{needle: 'mediafire.com', label: 'MediaFire'},
		{needle: 'onedrive.live.com', label: 'OneDrive'},
		{needle: '1drv.ms', label: 'OneDrive'}
	];

	/**
	 * Returns a folder prefix ending in '/', '' when the archive root is the
	 * mod, or null when no Psych mod content was found.
	 */
	public static function findModRoot(paths:Array<String>):Null<String>
	{
		if(paths == null || paths.length < 1) return null;

		var packs:Array<String> = [];
		for(path in paths)
			if(fileName(path).toLowerCase() == 'pack.json') packs.push(path);

		if(packs.length > 0)
		{
			packs.sort(function(a, b) return segmentCount(a) - segmentCount(b));
			return dirPrefix(packs[0]);
		}

		var candidates:Array<{root:String, markers:Int, files:Int}> = [];
		for(path in paths)
		{
			var segments:Array<String> = path.split('/');
			for(i in 0...segments.length)
			{
				if(!isModMarker(segments[i])) continue;
				var root:String = i < 1 ? '' : segments.slice(0, i).join('/') + '/';
				var found:Bool = false;
				for(candidate in candidates)
					if(candidate.root == root)
					{
						candidate.markers++;
						found = true;
						break;
					}
				if(!found) candidates.push({root: root, markers: 1, files: 0});
			}
		}

		for(candidate in candidates)
			for(path in paths)
				if(candidate.root.length < 1 || StringTools.startsWith(path, candidate.root)) candidate.files++;

		if(candidates.length < 1) return null;
		candidates.sort(function(a, b)
		{
			if(a.markers != b.markers) return b.markers - a.markers;
			if(a.root.length != b.root.length) return b.root.length - a.root.length;
			return b.files - a.files;
		});
		return candidates[0].root;
	}

	/** Human-readable host name when a profile points at an external download. */
	public static function externalHostFromText(text:String):Null<String>
	{
		if(text == null) return null;
		var lower:String = text.toLowerCase();
		for(host in EXTERNAL_HOSTS)
			if(lower.indexOf(host.needle) >= 0) return host.label;
		return null;
	}

	/**
	 * Reads an explicit Psych version declaration. A generic `version` field
	 * is ignored because mods use it for their own version number.
	 */
	public static function versionFromPack(raw:String):Null<String>
	{
		if(raw == null || raw.length < 1) return null;

		var data:Dynamic = null;
		try data = Json.parse(raw) catch(e:Dynamic) return null;
		if(data == null) return null;

		var keys:Array<String> = ['psychVersion', 'psychEngineVersion', 'requiredPsychVersion', 'psychEngine', 'engineVersion', 'engine'];
		for(key in keys)
		{
			if(!Reflect.hasField(data, key)) continue;
			var value:Dynamic = Reflect.field(data, key);
			var text:String = Std.string(value);
			if(versionParts(text) == null) continue;
			return StringTools.trim(text);
		}
		return null;
	}

	/** COMPATIBLE / INCOMPATIBLE / UNKNOWN against the engine's Psych base. */
	public static function compatibility(modVersion:Null<String>):String
	{
		var declared:Array<Int> = versionParts(modVersion);
		var base:Array<Int> = versionParts(BASE_PSYCH_VERSION);
		if(declared == null || base == null) return UNKNOWN;
		if(part(declared, 0) != part(base, 0) || part(declared, 1) != part(base, 1)) return INCOMPATIBLE;
		return COMPATIBLE;
	}

	static function isModMarker(segment:String):Bool
	{
		var lower:String = segment == null ? '' : segment.toLowerCase();
		for(marker in MOD_MARKERS)
			if(lower == marker) return true;
		return false;
	}

	static function fileName(path:String):String
	{
		var slash:Int = path.lastIndexOf('/');
		return slash < 0 ? path : path.substr(slash + 1);
	}

	static function dirPrefix(path:String):String
	{
		var slash:Int = path.lastIndexOf('/');
		return slash < 0 ? '' : path.substr(0, slash + 1);
	}

	static function segmentCount(path:String):Int
	{
		var count:Int = 1;
		for(i in 0...path.length)
			if(path.charAt(i) == '/') count++;
		return count;
	}

	static function versionParts(version:String):Array<Int>
	{
		if(version == null) return null;
		var numbers:Array<Int> = [];
		var i:Int = 0;
		while(i < version.length && numbers.length < 3)
		{
			var c:String = version.charAt(i);
			if(c < '0' || c > '9')
			{
				i++;
				continue;
			}

			var end:Int = i;
			while(end < version.length && version.charAt(end) >= '0' && version.charAt(end) <= '9') end++;
			numbers.push(Std.parseInt(version.substr(i, end - i)));
			i = end;
		}
		return numbers.length > 0 ? numbers : null;
	}

	static inline function part(values:Array<Int>, index:Int):Int
	{
		return index < values.length ? values[index] : 0;
	}
}
