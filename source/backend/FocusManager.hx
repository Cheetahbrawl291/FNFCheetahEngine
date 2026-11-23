package backend;

import flixel.FlxG;
import states.PlayState;

/**
 * Keeps the game responsive when the OS window loses focus.
 *
 * FlxGame.onFocusLost() dispatches `FlxG.signals.focusLost` BEFORE it checks
 * `FlxG.autoPause`. Clearing the flag in that signal makes Flixel skip its
 * framerate drop, "click to focus" overlay, sound pause and input reset.
 * Gameplay still pauses explicitly, so a song never plays on unattended.
 */
class FocusManager
{
	public static function init():Void
	{
		FlxG.signals.focusLost.add(onFocusLost);
	}

	static function onFocusLost():Void
	{
		FlxG.autoPause = false;

		var play:PlayState = PlayState.instance;
		if (play != null)
			play.pauseForFocusLoss();
	}
}
