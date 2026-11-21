import backend.CalibrationScroll;

/**
 * Boundary probes derived from independent verification. Copy this file and
 * `source/backend/CalibrationScroll.hx` into a scratch directory, then run:
 *   haxe -cp <scratch> -main CalibrationScrollBoundaryTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class CalibrationScrollBoundaryTest
{
	static var fails = 0;

	static function eq(actual:Dynamic, expected:Dynamic, label:String):Void
	{
		if(Std.string(actual) == Std.string(expected))
			trace('PASS ' + label + ' => ' + Std.string(actual));
		else
		{
			fails++;
			trace('FAIL ' + label + ' expected=' + Std.string(expected) + ' actual=' + Std.string(actual));
		}
	}

	static function main():Void
	{
		eq(CalibrationScroll.BEATS_BEHIND, 1, 'BEATS_BEHIND');
		eq(CalibrationScroll.BEATS_AHEAD, 1, 'BEATS_AHEAD');
		eq(CalibrationScroll.currentBeatIndex(-500, 500), -1, 'negative song position -> negative index (caller hides)');
		eq(CalibrationScroll.currentBeatIndex(-1, 500), -1, 'just before zero -> negative index');
		eq(CalibrationScroll.currentBeatIndex(1000, -500), 0, 'negative interval defensive');
		eq(CalibrationScroll.beatTime(-2, 500), -1000, 'negative beat index time');
		eq(CalibrationScroll.arrowY(360, 1000, 12345, 0), 360, 'zero pxPerMs keeps arrow at receptor');
		eq(CalibrationScroll.arrowY(360, 1000, 999.5), 360.275, 'fractional song position');

		if(fails > 0) throw 'CalibrationScrollBoundaryTest failures=' + fails;
		trace('ALL CalibrationScrollBoundaryTest PASSED');
	}
}
