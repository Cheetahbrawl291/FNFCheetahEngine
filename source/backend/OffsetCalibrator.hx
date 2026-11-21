package backend;

/**
 * Computes a suggested note offset from taps made against a regular beat grid.
 * Pure Haxe: no Flixel, filesystem or state dependencies, so it is testable in isolation.
 */
class OffsetCalibrator
{
	public static inline var MIN_TAPS:Int = 4;
	public static inline var MAX_OFFSET:Int = 500;

	/**
	 * Returns a millisecond offset in [-MAX_OFFSET, MAX_OFFSET], or null when
	 * there is not enough data. Positive means the taps arrived late.
	 */
	static public function suggestOffset(taps:Array<Float>, beatInterval:Float):Null<Int>
	{
		if(taps == null || taps.length < MIN_TAPS || beatInterval <= 0) return null;

		var deltas:Array<Float> = [];
		for(tap in taps)
			deltas.push(signedDelta(tap, beatInterval));

		var median:Float = medianOf(deltas);
		var tolerance:Float = beatInterval * 0.25;
		var kept:Array<Float> = [];
		for(delta in deltas)
			if(Math.abs(delta - median) <= tolerance) kept.push(delta);

		if(kept.length >= MIN_TAPS) median = medianOf(kept);

		var rounded:Int = Math.round(median);
		if(rounded > MAX_OFFSET) return MAX_OFFSET;
		if(rounded < -MAX_OFFSET) return -MAX_OFFSET;
		return rounded;
	}

	/** Distance from the tap to the closest beat, in (-interval/2, interval/2]. */
	static function signedDelta(tap:Float, interval:Float):Float
	{
		var phase:Float = tap % interval;
		if(phase < 0) phase += interval;
		if(phase > interval / 2) phase -= interval;
		return phase;
	}

	static function medianOf(values:Array<Float>):Float
	{
		var sorted:Array<Float> = values.copy();
		sorted.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		var mid:Int = Std.int(sorted.length / 2);
		return sorted.length % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid];
	}
}
