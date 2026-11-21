import backend.CalibrationScroll;

/**
 * Deterministic checks for the gameplay-style arrow geometry used by the
 * offset calibration screen. Copy this file and
 * `source/backend/CalibrationScroll.hx` into a scratch directory, then run:
 *   haxe -cp <scratch> -main CalibrationScrollTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class CalibrationScrollTest
{
	static function check(ok:Bool, label:String):Void
	{
		if(!ok) throw 'FAIL: $label';
		trace('PASS: $label');
	}

	static function main():Void
	{
		check(CalibrationScroll.beatTime(0, 500) == 0, 'beat zero starts at zero');
		check(CalibrationScroll.beatTime(4, 500) == 2000, 'beat time is index times interval');

		check(CalibrationScroll.currentBeatIndex(0, 500) == 0, 'song start is beat zero');
		check(CalibrationScroll.currentBeatIndex(499, 500) == 0, 'just before a beat stays on previous index');
		check(CalibrationScroll.currentBeatIndex(500, 500) == 1, 'exact beat advances index');
		check(CalibrationScroll.currentBeatIndex(1250, 500) == 2, 'index tracks elapsed beats');
		check(CalibrationScroll.currentBeatIndex(1000, 0) == 0, 'invalid interval is defensive');

		check(CalibrationScroll.arrowY(360, 1000, 1000) == 360, 'arrow sits on receptor at its beat');
		check(CalibrationScroll.arrowY(360, 1000, 900) > 360, 'future arrow is below receptor');
		check(CalibrationScroll.arrowY(360, 1000, 1100) < 360, 'past arrow is above receptor');

		var rising:Bool = CalibrationScroll.arrowY(360, 1000, 500) >
			CalibrationScroll.arrowY(360, 1000, 600);
		check(rising, 'arrow rises as song position advances');
		check(CalibrationScroll.arrowY(360, 1000, 500) - CalibrationScroll.arrowY(360, 1000, 600) == 55,
			'default speed is 0.55 px per ms');
		check(CalibrationScroll.arrowY(360, 1000, 500, 1) - CalibrationScroll.arrowY(360, 1000, 600, 1) == 100,
			'custom speed is respected');

		trace('ALL CalibrationScrollTest CHECKS PASSED');
	}
}
