import backend.OffsetCalibrator;

/**
 * Deterministic checks for automatic offset calibration. Copy this file and
 * `source/backend/OffsetCalibrator.hx` into a scratch directory, then run:
 *   haxe -cp <scratch> -main OffsetCalibratorTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class OffsetCalibratorTest
{
	static function check(ok:Bool, label:String):Void
	{
		if(!ok) throw 'FAIL: $label';
		trace('PASS: $label');
	}

	static function main():Void
	{
		check(OffsetCalibrator.suggestOffset(null, 500) == null, 'null taps give no result');
		check(OffsetCalibrator.suggestOffset([], 500) == null, 'empty taps give no result');
		check(OffsetCalibrator.suggestOffset([0, 500, 1000], 500) == null, 'too few taps give no result');
		check(OffsetCalibrator.suggestOffset([0, 500, 1000, 1500], 0) == null, 'invalid interval gives no result');
		check(OffsetCalibrator.suggestOffset([0, 500, 1000, 1500], -500) == null, 'negative interval gives no result');

		check(OffsetCalibrator.suggestOffset([0, 500, 1000, 1500], 500) == 0, 'on-beat taps give zero');
		check(OffsetCalibrator.suggestOffset([30, 530, 1030, 1530], 500) == 30, 'late taps give positive offset');
		check(OffsetCalibrator.suggestOffset([470, 970, 1470, 1970], 500) == -30, 'early taps wrap to negative offset');

		// One missed/erratic tap must not move the result.
		check(OffsetCalibrator.suggestOffset([30, 530, 1030, 1530, 1240], 500) == 30, 'outlier tap is discarded');

		check(OffsetCalibrator.suggestOffset([510, 2010, 3510, 5010], 1500) == 500, 'offset is clamped to UI range');
	}
}
