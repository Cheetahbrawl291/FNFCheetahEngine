package states.editors;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxAxes;

import backend.ModchartEditorDetector;

/**
 * Entry point for the external LUA Modchart Editor by .bakugo / CommanderVideo.
 *
 * The script is CC BY-NC-ND 4.0, so it is downloaded by the player and never
 * bundled with the engine. This state only explains how to use it and reports
 * whether a recognized copy is installed.
 */
class ModChartEditorState extends MusicBeatState
{
	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("ModChart Editor", null);
		#end

		var txt:FlxText = new FlxText(0, 0, FlxG.width - 80,
			"MODCHART EDITOR (LUA)\n\n" +
			statusLine() + "\n\n" +
			"1. Download 'LUA Modchart Editor' v1.2.2 by .bakugo from GameBanana.\n" +
			"2. Put the .lua in assets/shared/scripts/ or mods/<mod>/scripts/.\n" +
			"3. Enable Options > Modchart Editor > Lua Compatibility.\n" +
			"4. Start a song and press 5 to open the editor.\n" +
			"5. While testing a modchart, press BACKSPACE to return to it.\n\n" +
			"Script not included: CC BY-NC-ND 4.0.\n\n" +
			"Press BACK to return to the Editor Menu",
			18);
		txt.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.screenCenter(FlxAxes.XY);
		txt.borderSize = 2;
		add(txt);

		super.create();
	}

	function statusLine():String
	{
		#if !LUA_ALLOWED
		return 'Status: Lua is disabled in this build.';
		#else
		if(!ClientPrefs.data.modchartEditorCompat)
			return 'Status: compatibility OFF. Enable Options > Modchart Editor > Lua Compatibility.';

		var path = findEditorScript();
		if(path == null)
			return 'Status: editor script NOT FOUND. Place the downloaded .lua in a scripts folder.';
		return 'Status: editor script FOUND\n' + path;
		#end
	}

	#if LUA_ALLOWED
	function findEditorScript():String
	{
		#if (sys && MODS_ALLOWED)
		for(folder in Mods.directoriesWithFile(Paths.getSharedPath(), 'scripts/'))
		{
			for(file in sys.FileSystem.readDirectory(folder))
			{
				if(!file.toLowerCase().endsWith('.lua')) continue;
				var path = folder + file;
				try
				{
					if(ModchartEditorDetector.isEditorSource(sys.io.File.getContent(path))) return path;
				}
				catch(e:Dynamic) {}
			}
		}
		#end
		return null;
	}
	#end

	override function update(elapsed:Float)
	{
		if(controls.BACK)
			MusicBeatState.switchState(new MasterEditorMenu());
		super.update(elapsed);
	}
}
