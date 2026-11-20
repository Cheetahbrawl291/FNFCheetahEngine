package backend;

/**
 * Identifies the external LUA Modchart Editor script without shipping it.
 *
 * The script is licensed CC BY-NC-ND 4.0, so this engine only looks for its own
 * header in a file chosen by the player. It never embeds or rewrites the script.
 */
class ModchartEditorDetector
{
	public static inline var TITLE_MARKER:String = 'LUA Modchart Editor v';
	public static inline var AUTHOR_MARKER:String = '.bakugo';

	/** Psych Engine version understood by the editor's own compatibility branches. */
	public static inline var PSYCH_VERSION:String = '1.0.4';

	public static function isEditorSource(source:String):Bool
	{
		if(source == null) return false;
		return source.indexOf(TITLE_MARKER) >= 0 && source.indexOf(AUTHOR_MARKER) >= 0;
	}

	/**
	 * Returns the version string the editor expects, or null when this script is
	 * not the supported editor or the opt-in setting is off.
	 */
	public static function versionOverrideFor(source:String, compatEnabled:Bool):Null<String>
	{
		if(!compatEnabled || !isEditorSource(source)) return null;
		return PSYCH_VERSION;
	}
}
