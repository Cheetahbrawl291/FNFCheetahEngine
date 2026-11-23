package backend;

import haxe.io.Path;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

/**
 * Data behind the char-select grid. Stored at mods/<mod>/data/charselect.json
 * so custom characters load at runtime without recompiling the engine.
 *
 * Slots are indices of the 3x3 grid (0..8). Cells 3 and 4 are reserved for the
 * built-in Pico and BF icons; custom characters may occupy any padlock cell.
 */
typedef CharSelectMix =
{
	id:String,
	name:String,
	/** Map of cue name -> Paths sound key: change / confirm / locked. */
	sounds:Dynamic
}

typedef CharSelectCharacter =
{
	id:String,
	name:String,
	slot:Int,
	/** Full Paths key, e.g. 'CharSelect/titles/mychar'. */
	title:String,
	/** Full Paths key for the grid icon atlas. */
	icon:String,
	iconPrefix:String,
	/** Id of a CharSelectMix entry. */
	mix:String,
	/** Full Paths key for the Sparrow atlas holding idle/intro/confirm. */
	atlas:String,
	fps:Float,
	/** Per-state anchors: {intro:[x,y], idle:[x,y], confirm:[x,y]}. */
	anchors:Dynamic,
	/** Original GIF/still source paths, kept so states can be re-baked. */
	?introSrc:String,
	?idleSrc:String,
	?confirmSrc:String
}

typedef CharSelectConfigData =
{
	version:Int,
	mixes:Array<CharSelectMix>,
	characters:Array<CharSelectCharacter>
}

class CharSelectConfig
{
	public static final VERSION:Int = 1;
	public static final RESERVED_CELLS:Array<Int> = [3, 4];

	static var current:CharSelectConfigData = null;
	static var cachedPath:String = null;

	public static function path():String
	{
		var mod:String = Mods.currentModDirectory;
		if(mod != null && mod.length > 0) return 'mods/$mod/data/charselect.json';
		return 'mods/data/charselect.json';
	}

	public static function getDefault():CharSelectConfigData
	{
		return {
			version: VERSION,
			mixes: [
				{id: 'bf', name: 'BF', sounds: {}},
				{id: 'pico', name: 'Pico', sounds: {}}
			],
			characters: []
		};
	}

	public static function isReservedSlot(slot:Int):Bool
		return slot < 0 || slot > 8 || RESERVED_CELLS.indexOf(slot) >= 0;

	public static function load(?force:Bool = false):CharSelectConfigData
	{
		var thisPath:String = path();
		if(current != null && !force && cachedPath == thisPath) return current;

		var config:CharSelectConfigData = getDefault();
		var raw:String = Paths.getTextFromFile('data/charselect.json');
		if(raw != null)
		{
			try
			{
				var parsed:Dynamic = haxe.Json.parse(raw);
				if(Std.isOfType(parsed.mixes, Array)) config.mixes = parsed.mixes;
				if(Std.isOfType(parsed.characters, Array)) config.characters = parsed.characters;
			}
			catch(e:Dynamic)
				trace('CharSelectConfig: could not parse ${path()} ($e)');
		}

		sanitize(config);
		current = config;
		cachedPath = thisPath;
		return config;
	}

	/** Drops invalid entries, deduplicates ids and guarantees default mixes. */
	public static function sanitize(config:CharSelectConfigData):Void
	{
		if(config == null) return;
		config.version = VERSION;

		if(config.mixes == null) config.mixes = [];
		var mixIds:Array<String> = [];
		var mixes:Array<CharSelectMix> = [];
		for(m in config.mixes)
		{
			if(m == null) continue;
			var id:String = clean(m.id);
			if(id.length == 0 || mixIds.indexOf(id) >= 0) continue;
			mixIds.push(id);
			if(clean(m.name).length == 0) m.name = id;
			if(m.sounds == null) m.sounds = {};
			mixes.push(m);
		}
		for(id in ['bf', 'pico'])
			if(mixIds.indexOf(id) < 0)
			{
				mixIds.push(id);
				mixes.push({id: id, name: id.toUpperCase(), sounds: {}});
			}
		config.mixes = mixes;

		if(config.characters == null) config.characters = [];
		var charIds:Array<String> = [];
		var slots:Array<Int> = [];
		var chars:Array<CharSelectCharacter> = [];
		for(c in config.characters)
		{
			if(c == null) continue;
			var id:String = clean(c.id);
			if(id.length == 0 || charIds.indexOf(id) >= 0) continue;
			// An empty atlas is allowed: the editor can save a character before
			// its states are baked; the selector then simply shows no preview.
			if(isReservedSlot(c.slot) || slots.indexOf(c.slot) >= 0) continue;

			charIds.push(id);
			slots.push(c.slot);
			c.id = id;
			if(clean(c.name).length == 0) c.name = id;
			if(clean(c.title).length == 0) c.title = null;
			if(clean(c.icon).length == 0) c.icon = null;
			if(clean(c.iconPrefix).length == 0) c.iconPrefix = id + ' icon instance';
			if(mixIds.indexOf(c.mix) < 0) c.mix = 'bf';
			if(!Math.isFinite(c.fps) || c.fps < 1 || c.fps > 60) c.fps = 25;
			if(c.anchors == null) c.anchors = {};
			chars.push(c);
		}
		config.characters = chars;
	}

	static inline function clean(value:String):String
		return value == null ? '' : StringTools.trim(value);

	public static function mix(config:CharSelectConfigData, id:String):CharSelectMix
	{
		if(config == null || config.mixes == null) return null;
		for(m in config.mixes)
			if(m.id == id) return m;
		return null;
	}

	public static function save(config:CharSelectConfigData):Bool
	{
		if(config == null) return false;
		sanitize(config);

		#if sys
		try
		{
			var file:String = path();
			var folder:String = Path.directory(file);
			if(folder.length > 0 && !FileSystem.exists(folder))
				FileSystem.createDirectory(folder);

			File.saveContent(file, haxe.Json.stringify(config, '\t'));
			current = config;
			cachedPath = file;
			return true;
		}
		catch(e:Dynamic)
			trace('CharSelectConfig: could not save ${path()} ($e)');
		#end

		return false;
	}

	public static function forget():Void
	{
		current = null;
		cachedPath = null;
	}
}
