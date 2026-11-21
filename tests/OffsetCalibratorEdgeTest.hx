import backend.OffsetCalibrator;

/**
 * Boundary probes derived from independent verification. Copy this file and
 * `source/backend/OffsetCalibrator.hx` into a scratch directory, then run:
 *   haxe -cp <scratch> -main OffsetCalibratorEdgeTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class OffsetCalibratorEdgeTest
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
		eq(OffsetCalibrator.MIN_TAPS, 4, 'MIN_TAPS');
		eq(OffsetCalibrator.MAX_OFFSET, 500, 'MAX_OFFSET');
		eq(OffsetCalibrator.suggestOffset([-30, 470, 970, 1470], 500), -30, 'negative timestamps');
		eq(OffsetCalibrator.suggestOffset([250, 750, 1250, 1750], 500), 250, 'exact half interval');
		eq(OffsetCalibrator.suggestOffset([0, 250, 500, 750], 500), 125, 'even-count median');
		eq(OffsetCalibrator.suggestOffset([501, 1701, 2901, 4101], 1200), 500, 'positive clamp');
		eq(OffsetCalibrator.suggestOffset([1, 501, 1001, 1501], 500), 1, 'near zero unclamped');
		eq(OffsetCalibrator.suggestOffset([699, 1899, 3099, 4299], 1200), -500, 'negative clamp');
		eq(OffsetCalibrator.suggestOffset([30, 530, 1030, 1530, 2030], 500), 30, 'odd tap count');
		eq(OffsetCalibrator.suggestOffset([30, 240, 240, 240, 240], 500), 240, 'majority wins over first outlier');
		eq(OffsetCalibrator.suggestOffset([30, 530, 1030], 500), null, 'three taps below MIN_TAPS');
		eq(OffsetCalibrator.suggestOffset([0, 1, 2, 3], 0.0001), 0, 'tiny positive interval');

		if(fails > 0) throw 'OffsetCalibratorEdgeTest failures=' + fails;
	}
}
