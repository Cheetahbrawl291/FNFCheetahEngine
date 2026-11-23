package backend;

import openfl.utils.AssetType;

using StringTools;

/**
 * Name resolution for Pico Mix songs shipped as separate charts.
 *
 * The Pico Mix mod names entries "Bopeebo (Pico Mix)" and stores their
 * charts/audio in `bopeebo-(pico-mix)`. This class owns that mapping and the
 * list of Weekend 1 songs that are Pico-sung in their base chart.
 */
class PicoMix
{
	static inline var SUFFIX:String = '-(pico-mix)';

	/** Weekend 1 songs are sung by Pico in the base game, not by BF. */
	public static final WEEKEND_SONGS:Array<String> = [
		'darnell',
		'lit-up',
		'2hot',
		'blazin'
	];

	public static inline function isPicoName(?name:String):Bool
	{
		if(name == null || name.length < 1) return false;
		return Paths.formatToSongPath(name).endsWith(SUFFIX);
	}

	/** "Bopeebo (Pico Mix)" -> "bopeebo". Non-pico names are unchanged. */
	public static function baseName(?name:String):String
	{
		if(!isPicoName(name)) return name;

		var path:String = Paths.formatToSongPath(name);
		return path.substring(0, path.length - SUFFIX.length);
	}

	/** "Bopeebo" -> "bopeebo-(pico-mix)". */
	public static inline function folderFor(baseName:String):String
	{
		return Paths.formatToSongPath(baseName) + SUFFIX;
	}

	public static inline function isWeekendSong(?name:String):Bool
	{
		if(name == null) return false;
		var path:String = Paths.formatToSongPath(name);
		return WEEKEND_SONGS.indexOf(path) >= 0;
	}

	/** True when a `(Pico Mix)` chart is installed for this song/difficulty. */
	public static function chartExists(baseName:String, diffPostfix:String = ''):Bool
	{
		var folder:String = folderFor(baseName);
		return Paths.fileExists('data/$folder/$folder$diffPostfix.json', TEXT);
	}
}
