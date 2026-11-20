package states.editors;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxAxes;

import backend.ModchartEditorDetector;

/**
 * Entry point for the bundled LUA Modchart Editor by .bakugo / CommanderVideo.
 *
 * The script ships verbatim in assets/shared/scripts/ and loads in every song.
 * This state explains the controls and reports whether it was detected.
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
			"Script included: 'LUA Modchart Editor' v1.2.2 by .bakugo.\n" +
			"Original source: https://gamebanana.com/scripts/12931\n" +
			"License: CC BY-NC-ND 4.0. Script is shipped unmodified.\n\n" +
			"1. Start a song and press 5 to open the editor.\n" +
			"2. While testing a modchart, press BACKSPACE to return to it.\n" +
			"3. Exports are saved under mods/savedModcharts/.\n\n" +
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
			return 'Status: compatibility OFF. Enable Options > Modchart Editor > Lua Compatibility to use the bundled editor.';

		var path = findEditorScript();
		if(path == null)
			return 'Status: editor script NOT FOUND. Restore assets/shared/scripts/ModchartEditor.lua.';
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
