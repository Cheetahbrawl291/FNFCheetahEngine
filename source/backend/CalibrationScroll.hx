package backend;

/**
 * Pure geometry for the offset calibration screen: gameplay-style arrows that
 * rise toward a fixed receptor in step with a regular beat grid.
 * No Flixel or state dependencies, so the timing can be tested in isolation.
 */
class CalibrationScroll
{
	public static inline var DEFAULT_PX_PER_MS:Float = 0.55;
	public static inline var BEATS_BEHIND:Int = 1;
	public static inline var BEATS_AHEAD:Int = 1;

	/** Game-clock time of a beat index on a beat grid. */
	public static function beatTime(index:Int, beatInterval:Float):Float
	{
		return index * beatInterval;
	}

	/** Beat index whose note is currently closest to the receptor. */
	public static function currentBeatIndex(songPosition:Float, beatInterval:Float):Int
	{
		if(beatInterval <= 0) return 0;
		return Math.floor(songPosition / beatInterval);
	}

	/**
	 * Screen Y of a rising arrow. Below the receptor before its beat, exactly
	 * at the receptor on the beat, above it afterwards.
	 */
	public static function arrowY(receptorY:Float, beatTime:Float, songPosition:Float, ?pxPerMs:Null<Float>):Float
	{
		var speed:Float = pxPerMs == null ? DEFAULT_PX_PER_MS : pxPerMs;
		return receptorY + (beatTime - songPosition) * speed;
	}
}
