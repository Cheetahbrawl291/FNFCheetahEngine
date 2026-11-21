package backend;

/** Scratch stub: ModBrowser only needs Paths.mods() for this test. */
class Paths
{
	public static var root:String = '';

	public static function mods(?folder:String):String
	{
		return (folder == null || folder.length < 1) ? root : root + '/' + folder;
	}
}
