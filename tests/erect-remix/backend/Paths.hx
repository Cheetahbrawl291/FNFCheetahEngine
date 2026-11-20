package backend;

/**
 * Isolated stub for ErectRemixTest. `formatToSongPath` is copied verbatim from
 * source/backend/Paths.hx so the test can compile without Flixel/OpenFL.
 */
class Paths
{
	inline static public function formatToSongPath(path:String)
	{
		final invalidChars = ~/[~&;:<>#\s]/g;
		final hideChars = ~/[.,'"%?!]/g;

		return StringTools.trim(hideChars.replace(invalidChars.replace(path, '-'), '')).toLowerCase();
	}

	inline static public function getSharedPath(file:String = '')
		return 'assets/shared/$file';
}
