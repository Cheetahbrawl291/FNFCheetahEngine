package states.editors;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;

import backend.MixesConfig;
import backend.WeekData;
import backend.Paths;

/**
 * Key-7 editor for marking songs as normal/erect mixes and pairing them.
 * Pairs are written to MixesConfig and honored by Freeplay when the
 * "Erect Mix Unification" option is enabled.
 */
class MixesEditorState extends MusicBeatState
{
	var songNames:Array<String> = [];
	var songPaths:Array<String> = [];
	var grpItems:FlxTypedGroup<Alphabet>;

	var curSelected:Int = 0;
	var infoText:FlxText;
	var bannerText:FlxText;
	var helpText:FlxText;

	var linking:Bool = false;
	var linkSource:String = null;
	var status:String = 'Mark a song, then press ENTER to link it with its mix.';

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;

		WeekData.reloadWeekFiles(false);
		MixesConfig.load(true); // reload for the currently selected mod directory
		buildSongList();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		grpItems = new FlxTypedGroup<Alphabet>();
		add(grpItems);

		for(i in 0...songNames.length)
		{
			var item:Alphabet = new Alphabet(60, 240, songNames[i], true);
			item.isMenuItem = true;
			item.targetY = i;
			grpItems.add(item);
			item.snapToPosition();
		}

		bannerText = new FlxText(0, 24, FlxG.width, '', 28);
		bannerText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.YELLOW, CENTER);
		bannerText.scrollFactor.set();
		add(bannerText);

		infoText = new FlxText(FlxG.width - 520, 200, 480, '', 22);
		infoText.setFormat(Paths.font('vcr.ttf'), 22, FlxColor.WHITE, LEFT);
		infoText.scrollFactor.set();
		add(infoText);

		helpText = new FlxText(0, FlxG.height - 76, FlxG.width, '', 18);
		helpText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER);
		helpText.scrollFactor.set();
		helpText.text = 'UP/DOWN select   1 normal   2 erect   0 clear   ENTER link   DEL unlink   S save   BACK exit';
		add(helpText);

		refreshText();
		super.create();
	}

	function buildSongList():Void
	{
		songNames = [];
		songPaths = [];
		var seen:Map<String, Bool> = new Map();

		for(weekName in WeekData.weeksList)
		{
			var week:WeekData = WeekData.weeksLoaded.get(weekName);
			if(week == null || week.songs == null) continue;
			for(song in week.songs)
			{
				if(song == null || song.length < 1) continue;
				var name:String = Std.string(song[0]);
				var path:String = Paths.formatToSongPath(name);
				if(path.length < 1 || seen.exists(path)) continue;
				seen.set(path, true);
				songNames.push(name);
				songPaths.push(path);
			}
		}

		// Stable alphabetical order makes finding a pair much easier.
		var indices:Array<Int> = [];
		for(i in 0...songNames.length) indices.push(i);
		indices.sort(function(a:Int, b:Int)
			return songNames[a].toLowerCase() < songNames[b].toLowerCase() ? -1 :
				(songNames[a].toLowerCase() > songNames[b].toLowerCase() ? 1 : 0));

		var sortedNames:Array<String> = [];
		var sortedPaths:Array<String> = [];
		for(i in indices)
		{
			sortedNames.push(songNames[i]);
			sortedPaths.push(songPaths[i]);
		}
		songNames = sortedNames;
		songPaths = sortedPaths;
	}

	override function update(elapsed:Float)
	{
		if(songNames.length > 0)
		{
			if(controls.UI_UP_P) changeSelection(-1);
			if(controls.UI_DOWN_P) changeSelection(1);

			if(FlxG.keys.justPressed.ONE)
			{
				MixesConfig.setKind(songPaths[curSelected], MixesConfig.NORMAL);
				status = 'Marked NORMAL: ' + songNames[curSelected];
				refreshText();
			}
			if(FlxG.keys.justPressed.TWO)
			{
				MixesConfig.setKind(songPaths[curSelected], MixesConfig.ERECT);
				status = 'Marked ERECT: ' + songNames[curSelected];
				refreshText();
			}
			if(FlxG.keys.justPressed.ZERO)
			{
				MixesConfig.unlink(songPaths[curSelected]);
				MixesConfig.setKind(songPaths[curSelected], null);
				if(linking && linkSource == songPaths[curSelected]) cancelLink();
				status = 'Cleared: ' + songNames[curSelected];
				refreshText();
			}
			if(FlxG.keys.justPressed.ENTER) handleEnter();
			if(FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE)
			{
				MixesConfig.unlink(songPaths[curSelected]);
				status = 'Unlinked: ' + songNames[curSelected];
				refreshText();
			}
		}

		if(FlxG.keys.justPressed.S)
		{
			var ok:Bool = MixesConfig.save();
			status = ok ? 'Saved ' + MixesConfig.path() : 'Save failed (desktop only)';
			refreshText();
		}

		if(controls.BACK)
		{
			if(linking) cancelLink();
			else
			{
				MixesConfig.save();
				MixesConfig.forget();
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}

		for(num => item in grpItems.members)
		{
			item.targetY = num - curSelected;
			item.alpha = item.targetY == 0 ? 1 : 0.6;
		}

		super.update(elapsed);
	}

	function handleEnter():Void
	{
		var selected:String = songPaths[curSelected];

		if(!linking)
		{
			var kind:Null<String> = MixesConfig.kind(selected);
			if(kind == null)
			{
				status = 'Set type first with 1 (normal) or 2 (erect).';
				refreshText();
				return;
			}
			linking = true;
			linkSource = selected;
			status = 'Pick the ' + (kind == MixesConfig.NORMAL ? 'erect' : 'normal') + ' partner, then ENTER.';
			refreshText();
			return;
		}

		if(selected == linkSource)
		{
			cancelLink();
			status = 'Link cancelled.';
			refreshText();
			return;
		}

		var sourceKind:Null<String> = MixesConfig.kind(linkSource);
		var targetKind:Null<String> = MixesConfig.kind(selected);
		if(sourceKind == targetKind)
		{
			status = 'Pair one NORMAL song with one ERECT song.';
			refreshText();
			return;
		}

		if(sourceKind == MixesConfig.NORMAL) MixesConfig.link(linkSource, selected);
		else MixesConfig.link(selected, linkSource);

		status = 'Linked: ' + songNames[curSelected] + ' <-> ' + nameFor(linkSource);
		linking = false;
		linkSource = null;
		refreshText();
	}

	function cancelLink():Void
	{
		linking = false;
		linkSource = null;
	}

	function changeSelection(change:Int = 0):Void
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, songNames.length - 1);
		refreshText();
	}

	function nameFor(path:String):String
	{
		var idx:Int = songPaths.indexOf(path);
		return idx < 0 ? path : songNames[idx];
	}

	function refreshText():Void
	{
		if(bannerText != null)
			bannerText.text = linking ? 'MIXES EDITOR - PICK PARTNER' : 'MIXES EDITOR';

		if(infoText == null || songNames.length < 1) return;

		var path:String = songPaths[curSelected];
		var kind:Null<String> = MixesConfig.kind(path);
		var linked:Null<String> = MixesConfig.linkedErect(path);
		if(linked == null) linked = MixesConfig.linkedNormal(path);

		var lines:Array<String> = [
			status,
			'',
			'SONG: ' + songNames[curSelected],
			'TYPE: ' + (kind == null ? 'UNSET' : kind.toUpperCase()),
			'LINK: ' + (linked == null ? 'none' : nameFor(linked)),
			'',
			'PAIRS: ' + MixesConfig.pairs().length
		];
		infoText.text = lines.join('\n');
	}
}
