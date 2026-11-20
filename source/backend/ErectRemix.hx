package backend;

using StringTools;

/**
 * Name resolution for erect remixes shipped as separate songs.
 *
 * The Erect Mode mod names entries like "Bopeebo Erect", stores their charts in
 * `data/bopeebo-erect/bopeebo-erect-erect.json` and their audio in
 * `songs/bopeebo-erect/`. Freeplay merges those entries into the base song as
 * Erect/Nightmare difficulties; this class owns only the name mapping.
 */
class ErectRemix
{
	static inline var SUFFIX:String = '-erect';

	public static inline function isErectName(?name:String):Bool
	{
		if(name == null || name.length < 1) return false;
		return Paths.formatToSongPath(name).endsWith(SUFFIX);
	}

	/** "Bopeebo Erect" -> "Bopeebo". Non-erect names are returned unchanged. */
	public static function baseName(?name:String):String
	{
		if(!isErectName(name)) return name;

		var idx:Int = name.toLowerCase().lastIndexOf('erect');
		if(idx < 0) return name;

		var base:String = name.substring(0, idx);
		while(base.length > 0)
		{
			var last:String = base.charAt(base.length - 1);
			if(last != ' ' && last != '-' && last != '_') break;
			base = base.substring(0, base.length - 1);
		}
		return base;
	}

	/** "Bopeebo" -> "bopeebo-erect". */
	public static inline function folderFor(baseName:String):String
	{
		return Paths.formatToSongPath(baseName) + SUFFIX;
	}

	/** "bopeebo-erect", "Erect" -> "bopeebo-erect-erect". */
	public static inline function chartId(folder:String, diffName:String):String
	{
		return folder + '-' + Paths.formatToSongPath(diffName);
	}

	/** Only these two difficulties use the erect remix assets. */
	public static inline function usesErectAssets(diffName:String):Bool
	{
		return diffName == 'Erect' || diffName == 'Nightmare';
	}

	/**
	 * Resolve the erect stage for a base stage name, if one exists.
	 * Erect Mode ships `stages/<stage>Erect.json` + `.lua` beside every base stage
	 * it overrides, e.g. `stage` -> `stageErect`. Returns null when no erect
	 * stage exists, so the base stage is kept.
	 */
	public static function erectStage(?baseStage:String):String
	{
		if(baseStage == null || baseStage.length < 1) return null;

		var candidate:String = baseStage + 'Erect';
		var path:String = Paths.getSharedPath('stages/$candidate.json');
		#if MODS_ALLOWED
		if(sys.FileSystem.exists(path)) return candidate;
		#else
		if(openfl.utils.Assets.exists(path)) return candidate;
		#end
		return null;
	}

	/** Characters get a `-dark` variant for the spookyErect stage. */
	public static inline function isSpookyErect(stage:String):Bool
	{
		return stage == 'spookyErect';
	}
}
