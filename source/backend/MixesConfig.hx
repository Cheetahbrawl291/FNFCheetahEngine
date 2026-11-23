package backend;

import haxe.Json;
import haxe.io.Path;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

/**
 * Persistent normal/erect song marking and pairing used by the Mixes Editor.
 *
 * Stored as `mods/<mod>/data/mixes.json`. Keys are formatted song paths so the
 * data survives display-name changes. This is pure data: all Freeplay behavior
 * keeps working from ErectRemix's name rules when no explicit link exists.
 */
typedef MixesConfigData = {
	var marks:Dynamic; // formatted song path -> 'normal' | 'erect'
	var links:Dynamic; // normal formatted path -> erect formatted path
}

class MixesConfig
{
	public static inline var NORMAL:String = 'normal';
	public static inline var ERECT:String = 'erect';
	public static inline var PICO:String = 'pico';

	static var current:MixesConfigData = null;
	static var cachedPath:String = null;

	public static function getDefault():MixesConfigData
	{
		return {marks: {}, links: {}};
	}

	public static function path():String
	{
		var mod:String = Mods.currentModDirectory;
		if(mod != null && mod.length > 0) return 'mods/$mod/data/mixes.json';
		return 'mods/data/mixes.json';
	}

	public static function load(?force:Bool = false):MixesConfigData
	{
		var thisPath:String = path();
		// Invalidate when the selected mod directory changes, so a mod switch
		// never reuses another mod's marks or links.
		if(current != null && !force && cachedPath == thisPath) return current;

		var config:MixesConfigData = getDefault();
		var raw:String = read();
		if(raw != null)
		{
			try
			{
				var parsed:Dynamic = Json.parse(raw);
				if(parsed.marks != null && Std.isOfType(parsed.marks, String))
					parsed.marks = Json.parse(Std.string(parsed.marks));
				if(parsed.links != null && Std.isOfType(parsed.links, String))
					parsed.links = Json.parse(Std.string(parsed.links));

				if(parsed.marks != null && !Std.isOfType(parsed.marks, String))
					config.marks = parsed.marks;
				if(parsed.links != null && !Std.isOfType(parsed.links, String))
					config.links = parsed.links;
			}
			catch(e:Dynamic)
				trace('MixesConfig: could not parse ${path()} ($e)');
		}

		sanitize(config);
		current = config;
		cachedPath = thisPath;
		return config;
	}

	public static function save():Bool
	{
		var config:MixesConfigData = load();
		sanitize(config);

		#if sys
		try
		{
			var file:String = path();
			var folder:String = Path.directory(file);
			if(folder.length > 0 && !FileSystem.exists(folder))
				FileSystem.createDirectory(folder);

			File.saveContent(file, Json.stringify(config, '\t'));
			return true;
		}
		catch(e:Dynamic)
			trace('MixesConfig: could not save ${path()} ($e)');
		#end

		return false;
	}

	public static function forget():Void
	{
		current = null;
		cachedPath = null;
	}

	/** 'normal', 'erect', 'pico' or null when the song has not been marked. */
	public static function kind(?name:String):Null<String>
	{
		if(name == null || name.length < 1) return null;
		var value:Dynamic = Reflect.field(load().marks, Paths.formatToSongPath(name));
		if(value != null) return Std.string(value);

		// Weekend 1 songs are Pico-sung in the base game. An explicit mark
		// always wins, so the user can still override this default.
		if(PicoMix.isWeekendSong(name)) return PICO;
		return null;
	}

	/** True when a song has no BF vocals: a Pico mark or a Weekend 1 default. */
	public static inline function isPicoOnly(?name:String):Bool
		return kind(name) == PICO;

	public static function setKind(name:String, newKind:Null<String>):Void
	{
		var key:String = Paths.formatToSongPath(name);
		if(newKind == null || newKind.length < 1) Reflect.deleteField(load().marks, key);
		else Reflect.setField(load().marks, key, newKind);
	}

	/** Pair a normal song with its erect mix. Also applies both marks. */
	public static function link(normal:String, erect:String):Void
	{
		var a:String = Paths.formatToSongPath(normal);
		var b:String = Paths.formatToSongPath(erect);
		if(a.length < 1 || b.length < 1 || a == b) return;

		// A song can belong to only one pair. Marks that came from a dissolved
		// pair are cleared; explicit marks set with 1/2 are never touched here.
		var oldPartnerA:Null<String> = linkedErect(a);
		var oldPartnerB:Null<String> = linkedNormal(b);
		unlink(a);
		unlink(b);
		if(oldPartnerA != null && oldPartnerA != b && linkedNormal(oldPartnerA) == null)
			setKind(oldPartnerA, null);
		if(oldPartnerB != null && oldPartnerB != a && linkedErect(oldPartnerB) == null)
			setKind(oldPartnerB, null);

		var config:MixesConfigData = load();
		Reflect.setField(config.marks, a, NORMAL);
		Reflect.setField(config.marks, b, ERECT);
		Reflect.setField(config.links, a, b);
	}

	public static function unlink(name:String):Void
	{
		var key:String = Paths.formatToSongPath(name);
		var config:MixesConfigData = load();

		Reflect.deleteField(config.links, key);
		for(normal in Reflect.fields(config.links))
		{
			if(Std.string(Reflect.field(config.links, normal)) == key)
				Reflect.deleteField(config.links, normal);
		}
	}

	public static function linkedErect(?normal:String):Null<String>
	{
		if(normal == null) return null;
		var value:Dynamic = Reflect.field(load().links, Paths.formatToSongPath(normal));
		return value == null ? null : Std.string(value);
	}

	public static function linkedNormal(?erect:String):Null<String>
	{
		if(erect == null) return null;
		var target:String = Paths.formatToSongPath(erect);
		for(normal in Reflect.fields(load().links))
			if(Std.string(Reflect.field(load().links, normal)) == target) return normal;
		return null;
	}

	/** Every explicit pair, as [normalPath, erectPath]. */
	public static function pairs():Array<Array<String>>
	{
		var result:Array<Array<String>> = [];
		for(normal in Reflect.fields(load().links))
			result.push([normal, Std.string(Reflect.field(load().links, normal))]);
		return result;
	}

	static function read():String
	{
		#if sys
		try
		{
			var file:String = path();
			if(FileSystem.exists(file)) return File.getContent(file);
		}
		catch(e:Dynamic)
			trace('MixesConfig: could not read ${path()} ($e)');
		#end
		return null;
	}

	static function sanitize(config:MixesConfigData):Void
	{
		if(config.marks == null || Std.isOfType(config.marks, String)) config.marks = {};
		if(config.links == null || Std.isOfType(config.links, String)) config.links = {};

		for(key in Reflect.fields(config.marks))
		{
			var value:String = Std.string(Reflect.field(config.marks, key));
			if(value != NORMAL && value != ERECT && value != PICO) Reflect.deleteField(config.marks, key);
		}

		for(normal in Reflect.fields(config.links))
		{
			var erect:String = Std.string(Reflect.field(config.links, normal));
			if(normal.length < 1 || erect.length < 1 || normal == erect)
				Reflect.deleteField(config.links, normal);
		}
	}
}
