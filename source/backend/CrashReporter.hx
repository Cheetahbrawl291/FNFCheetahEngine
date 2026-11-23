package backend;

#if CRASH_HANDLER

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.app.Application;
import openfl.Lib;

/**
 * Turns recoverable crashes into a small in-game panel instead of a modal OS
 * alert that kills the process. Startup failures, fatal-looking errors and
 * crash loops still use the blocking alert and exit.
 */
class CrashReporter
{
	static var overlay:FlxGroup = null;
	static var overlayState:Dynamic = null;
	static var messageText:FlxText = null;
	static var closeButton:FlxText = null;
	static var timer:Float = 0;
	static var active:Bool = false;

	static var crashCount:Int = 0;
	static var windowStart:Float = 0;

	/** Registers the per-frame hooks. The crash event itself stays in Main. */
	public static function initSignals():Void
	{
		FlxG.signals.postUpdate.add(update);
		FlxG.signals.postStateSwitch.add(onStateSwitch);
	}

	/** Called by Main.onCrash after the log file has been written. */
	public static function report(errMsg:String):Void
	{
		if (isCritical(errMsg))
			showBlocking(errMsg);
		else
			showNonBlocking(errMsg);
	}

	static function isCritical(errMsg:String):Bool
	{
		// No state means the crash happened before the game was running.
		if (FlxG.state == null)
			return true;

		var low = errMsg.toLowerCase();
		for (fatal in ['stack overflow', 'out of memory', 'segmentation fault', 'access violation'])
			if (low.indexOf(fatal) >= 0)
				return true;

		var now = Lib.getTimer() / 1000;
		if (windowStart == 0 || now - windowStart > 8)
		{
			windowStart = now;
			crashCount = 0;
		}
		crashCount++;

		// A crash loop means continuing would leave the game in a broken state.
		return crashCount >= 3;
	}

	static function showNonBlocking(errMsg:String):Void
	{
		if (FlxG.state == null)
		{
			showBlocking(errMsg);
			return;
		}

		if (overlay == null || overlayState != FlxG.state)
			createOverlay();

		var lines = errMsg.split('\n');
		var summary = lines.length > 6 ? lines.slice(lines.length - 6).join('\n') : errMsg;
		if (summary.length > 460)
			summary = '...' + summary.substr(summary.length - 457);

		messageText.text = summary;
		timer = 12;
		active = true;
		overlay.visible = true;
	}

	static function createOverlay():Void
	{
		var w = 430;
		var h = 116;
		var x = FlxG.width - w - 10;
		var y = 10;

		var group = new FlxGroup();

		var panel = new FlxSprite(x, y).makeGraphic(w, h, FlxColor.fromRGB(18, 18, 24, 230));
		panel.scrollFactor.set();
		group.add(panel);

		var title = new FlxText(x + 10, y + 8, w - 20, 'RECOVERABLE CRASH');
		title.setFormat(null, 15, 0xFFFF8080, 'left');
		title.scrollFactor.set();
		group.add(title);

		messageText = new FlxText(x + 10, y + 30, w - 20, '');
		messageText.setFormat(null, 11, FlxColor.WHITE, 'left');
		messageText.scrollFactor.set();
		group.add(messageText);

		var hint = new FlxText(x + 10, y + h - 20, w - 44, 'Saved to crash/. Click X or wait to dismiss.');
		hint.setFormat(null, 10, 0xFFAAAAAA, 'left');
		hint.scrollFactor.set();
		group.add(hint);

		closeButton = new FlxText(x + w - 28, y + 6, 22, 'X');
		closeButton.setFormat(null, 16, FlxColor.WHITE, 'center');
		closeButton.scrollFactor.set();
		group.add(closeButton);

		FlxG.state.add(group);
		overlay = group;
		overlayState = FlxG.state;
	}

	static function onStateSwitch():Void
	{
		if (!active || FlxG.state == null)
			return;

		// The old group died with the previous state.
		overlay = null;
		overlayState = null;
		createOverlay();
		timer = 6;
	}

	static function update():Void
	{
		if (!active || overlay == null)
			return;

		timer -= FlxG.elapsed;
		if (timer <= 0)
		{
			dismiss();
			return;
		}

		if (FlxG.mouse.justPressed && closeButton != null && FlxG.mouse.overlaps(closeButton))
			dismiss();
	}

	static function dismiss():Void
	{
		active = false;
		if (overlay != null)
			overlay.kill();
		overlay = null;
		overlayState = null;
		messageText = null;
		closeButton = null;
	}

	static function showBlocking(errMsg:String):Void
	{
		Application.current.window.alert(errMsg, 'Error!');
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		#if windows
		backend.WindowsIntegrations.restoreAll();
		#end
		Sys.exit(1);
	}
}

#end
