package states.editors;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;

import backend.ModchartEditorDetector;
import backend.Song;
import backend.WeekData;

/**
 * Song picker for the bundled LUA Modchart Editor by .bakugo / CommanderVideo.
 *
 * The script ships verbatim in assets/shared/scripts/ and loads in every song.
 * Choosing a song starts it with the editor already active, so the player does
 * not have to press 5.
 */
class ModChartEditorState extends MusicBeatState
{
	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var songs:Array<String> = [];
	private var songWeeks:Array<WeekData> = [];
	private var curSelected:Int = 0;
	private var infoText:FlxText;

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("ModChart Editor", null);
		#end

		buildSongList();

		var title:FlxText = new FlxText(0, 20, FlxG.width - 40, 'MODCHART EDITOR - SELECT A SONG', 22);
		title.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2;
		add(title);

		infoText = new FlxText(0, 54, FlxG.width - 40, statusLine(), 14);
		infoText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.borderSize = 1;
		add(infoText);

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var item:Alphabet = new Alphabet(90, FlxG.height / 2, songs[i], true);
			item.isMenuItem = true;
			item.targetY = i;
			item.scaleX = Math.min(1, 980 / item.width);
			item.snapToPosition();
			grpSongs.add(item);
		}

		var hint:FlxText = new FlxText(0, FlxG.height - 52, FlxG.width - 40,
			'UP/DOWN: select   ENTER: edit song   BACK: Editor Menu\n' +
			'Script: LUA Modchart Editor v1.2.2 by .bakugo - CC BY-NC-ND 4.0 - exports to mods/savedModcharts/',
			14);
		hint.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hint.borderSize = 1;
		add(hint);

		refreshSelection(false);
		super.create();
	}

	function buildSongList()
	{
		songs = [];
		songWeeks = [];
		var seen:Map<String, Bool> = new Map<String, Bool>();

		WeekData.reloadWeekFiles(false);
		for (weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if (week == null || week.songs == null) continue;

			for (entry in week.songs)
			{
				if (entry == null || entry.length < 1) continue;
				var name:String = Std.string(entry[0]);
				if (name.length < 1 || seen.exists(name)) continue;
				seen.set(name, true);
				songs.push(name);
				songWeeks.push(week);
			}
		}
	}

	function statusLine():String
	{
		#if !LUA_ALLOWED
		return 'Status: Lua is disabled in this build.';
		#else
		if(!ClientPrefs.data.modchartEditorCompat)
			return 'Status: compatibility OFF. Enable Options > Modchart Editor > Lua Compatibility.';

		if(findEditorScript() == null)
			return 'Status: editor script NOT FOUND. Restore assets/shared/scripts/ModchartEditor.lua.';
		return 'Status: editor script FOUND - press ENTER on a song to open it in the editor.';
		#end
	}

	function refreshSelection(playSound:Bool)
	{
		if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		for (num => item in grpSongs.members)
		{
			item.targetY = num - curSelected;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}
	}

	#if LUA_ALLOWED
	function startEditor(songName:String, week:WeekData)
	{
		if(!ClientPrefs.data.modchartEditorCompat || findEditorScript() == null)
		{
			infoText.text = 'Compatibility is off or the editor script was not found. Check Options > Modchart Editor.';
			return;
		}

		var songId:String = Paths.formatToSongPath(songName);
		WeekData.setDirectoryFromWeek(week);

		@:privateAccess
		if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			Paths.freeGraphicsFromMemory();

		try
		{
			// Validate the Normal chart first: loadFromJson calls StageData.loadDirectory
			// unconditionally, which would crash on a missing chart.
			if (Song.getChart(songId, songId) == null)
			{
				infoText.text = 'No Normal chart found for "$songName".';
				return;
			}
			Song.loadFromJson(songId, songId);
		}
		catch(e:Dynamic)
		{
			infoText.text = 'Could not load the chart for "$songName".';
			return;
		}

		// The editor reads this field in initMemory() and opens without pressing 5.
		PlayState.SONG.modchartEditorMemory = {active: true, showedTooltip: true};
		PlayState.isStoryMode = false;
		PlayState.storyDifficulty = 0;

		FreeplayState.destroyFreeplayVocals();
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
	}
	#else
	function startEditor(songName:String, week:WeekData) {}
	#end

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
		if (songs.length > 0)
		{
			if (controls.UI_UP_P)
			{
				curSelected = FlxMath.wrap(curSelected - 1, 0, songs.length - 1);
				refreshSelection(true);
			}
			if (controls.UI_DOWN_P)
			{
				curSelected = FlxMath.wrap(curSelected + 1, 0, songs.length - 1);
				refreshSelection(true);
			}
			if (controls.ACCEPT)
				startEditor(songs[curSelected], songWeeks[curSelected]);
		}

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MasterEditorMenu());
		}
		super.update(elapsed);
	}
}
