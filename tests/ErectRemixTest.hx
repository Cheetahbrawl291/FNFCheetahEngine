import backend.ErectRemix;

/**
 * Deterministic checks for erect remix name resolution. Copy this file,
 * `source/backend/ErectRemix.hx` and `tests/erect-remix/backend/Paths.hx`
 * into a scratch directory, then run:
 *   haxe -cp <scratch> -main ErectRemixTest -neko <scratch>/test.n
 *   neko <scratch>/test.n
 */
class ErectRemixTest
{
	static function check(ok:Bool, label:String):Void
	{
		if(!ok) throw 'FAIL: $label';
		trace('PASS: $label');
	}

	static function main():Void
	{
		check(!ErectRemix.isErectName(null), 'null is not erect');
		check(!ErectRemix.isErectName(''), 'empty is not erect');
		check(!ErectRemix.isErectName('Bopeebo'), 'base song is not erect');
		check(!ErectRemix.isErectName('Bopeebo Erecto'), 'similar word is not erect');
		check(ErectRemix.isErectName('Bopeebo Erect'), 'spaced erect name is erect');
		check(ErectRemix.isErectName('bopeebo-erect'), 'hyphenated erect name is erect');

		check(ErectRemix.baseName('Bopeebo') == 'Bopeebo', 'base name unchanged');
		check(ErectRemix.baseName('Bopeebo Erect') == 'Bopeebo', 'spaced suffix removed');
		check(ErectRemix.baseName('Dad Battle Erect') == 'Dad Battle', 'multiword suffix removed');
		check(ErectRemix.baseName('bopeebo-erect') == 'bopeebo', 'hyphen suffix removed');

		check(ErectRemix.folderFor('Bopeebo') == 'bopeebo-erect', 'erect folder resolved');
		check(ErectRemix.folderFor('Dad Battle') == 'dad-battle-erect', 'multiword folder resolved');
		check(ErectRemix.chartId('bopeebo-erect', 'Erect') == 'bopeebo-erect-erect', 'erect chart id');
		check(ErectRemix.chartId('bopeebo-erect', 'Nightmare') == 'bopeebo-erect-nightmare', 'nightmare chart id');

		check(ErectRemix.usesErectAssets('Erect'), 'erect uses remix assets');
		check(ErectRemix.usesErectAssets('Nightmare'), 'nightmare uses remix assets');
		check(!ErectRemix.usesErectAssets('Normal'), 'normal keeps base assets');
		check(!ErectRemix.usesErectAssets('Hard'), 'hard keeps base assets');

		check(ErectRemix.isSpookyErect('spookyErect'), 'spooky erect detected');
		check(!ErectRemix.isSpookyErect('spooky'), 'base spooky not erect');
		check(!ErectRemix.isSpookyErect('mallErect'), 'other erect stage not spooky');
	}
}
