import backend.ErectRemix;

/**
 * Regression probe from independent verification (S6): with the option at its
 * default the gate must be indistinguishable from the baseline isErectName()
 * check, and with unification off no erect name may be hidden.
 * Copy this file, `source/backend/ErectRemix.hx` and
 * `tests/erect-remix/backend/Paths.hx` into a scratch directory:
 *   haxe -D MODS_ALLOWED -cp <scratch> -main ErectGateDifferentialTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class ErectGateDifferentialTest
{
	static function main():Void
	{
		var names:Array<String> = [
			'Bopeebo Erect', 'bopeebo-erect', 'Dad Battle Erect', 'Bopeebo',
			'', 'Bopeebo Erecto', 'Erect', 'bopeebo_erect', 'BOP ERECT',
			'  Bopeebo Erect  '
		];

		for(n in names)
		{
			if(ErectRemix.hideFromFreeplay(true, n) != ErectRemix.isErectName(n))
				throw 'FAIL default differential: $n';
			if(ErectRemix.hideFromFreeplay(false, n))
				throw 'FAIL off must stay visible: $n';
		}

		if(ErectRemix.hideFromFreeplay(true, null) || ErectRemix.hideFromFreeplay(false, null))
			throw 'FAIL null';
		if(ErectRemix.hideFromFreeplay(true, ''))
			throw 'FAIL empty';

		trace('ErectGateDifferentialTest PASSED');
	}
}
