package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.ErectRemix;
import backend.PicoMix;
import backend.MixesConfig;
import backend.MenuCustomization;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import substates.VocalistSelectSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;

import haxe.Json;

typedef ChartTarget =
{
	var id:String;
	var folder:String;
	var scoreName:String;
}

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];
	var erectFolders:Map<String, String> = new Map<String, String>();
	var linkedErectTargets:Map<String, Bool> = new Map<String, Bool>();
	var menuLayers:FlxTypedGroup<FlxSprite>;
	var menuCustom:MenuCustomizationData;
	var menuCustomCfg:backend.MenuCustomization.MenuConfig;

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var vocalText:FlxText;
	var pendingVocalistReload:Bool = false;

	var player:MusicPlayer;

	override function create()
	{
		//Paths.clearStoredMemory();
		//Paths.clearUnusedMemory();
		
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		menuCustom = MenuCustomization.load();
		menuCustomCfg = menuCustom.freeplay;
		applyCustomSoundsFreeplay();

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(#if desktop new states.editors.WeekEditorState() #else new states.MainMenuState() #end),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		erectFolders.clear();
		linkedErectTargets.clear();
		// Cheetah Options: when unification is off, erect mixes stay standalone.
		if(ClientPrefs.data.erectMixUnification)
		{
			MixesConfig.load();

			// Collect every song path so explicit pairs can be validated.
			var available:Map<String, Bool> = new Map();
			for(weekName in WeekData.weeksList)
			{
				var songWeek:WeekData = WeekData.weeksLoaded.get(weekName);
				if(songWeek == null || songWeek.songs == null) continue;
				for(song in songWeek.songs)
				{
					if(song == null || song.length < 1) continue;
					available.set(Paths.formatToSongPath(Std.string(song[0])), true);
				}
			}

			// Mixes Editor pairs take priority over the name-suffix convention.
			for(pair in MixesConfig.pairs())
			{
				if(!available.exists(pair[0]) || !available.exists(pair[1])) continue;
				erectFolders.set(pair[0], pair[1]);
				linkedErectTargets.set(pair[1], true);
			}

			for (weekName in WeekData.weeksList)
			{
				var remixWeek:WeekData = WeekData.weeksLoaded.get(weekName);
				if(remixWeek == null || remixWeek.songs == null) continue;
				for (remixSong in remixWeek.songs)
				{
					if(remixSong == null || remixSong.length < 1) continue;
					var remixName:String = Std.string(remixSong[0]);
					if(!ErectRemix.isErectName(remixName)) continue;
					var remixPath:String = Paths.formatToSongPath(remixName);
					var basePath:String = Paths.formatToSongPath(ErectRemix.baseName(remixName));
					// An explicit "normal" mark disables automatic merging.
					if(MixesConfig.kind(remixPath) == MixesConfig.NORMAL) continue;
					if(erectFolders.exists(basePath)) continue;
					erectFolders.set(basePath, remixPath);
					linkedErectTargets.set(remixPath, true);
				}
			}
		}

		if(Lambda.count(erectFolders) > 0)
			trace('Erect remixes merged into Freeplay: ' + Lambda.count(erectFolders));

		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				if(ClientPrefs.data.erectMixUnification &&
					linkedErectTargets.exists(Paths.formatToSongPath(Std.string(song[0])))) continue;
				if(ErectRemix.hideFromFreeplay(ClientPrefs.data.erectMixUnification, Std.string(song[0]))) continue;
				if(!vocalistMatches(Std.string(song[0]))) continue;

				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		trace('Freeplay songs for ${ClientPrefs.data.picoVocalMode ? "PICO" : "BF"}: ${songs.length}');
		Mods.loadTopMod();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		menuLayers = new FlxTypedGroup<FlxSprite>();
		add(menuLayers);
		addFreeplayLayers();

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			
			// too laggy with a lot of songs, so i had to recode the logic for it
			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			// using a FlxGroup is too much fuss!
			iconArray.push(icon);
			add(icon);

			// songText.x += 40;
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
			// songText.screenCenter(X);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		vocalText = new FlxText(10, 10, 320, '', 18);
		vocalText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.YELLOW, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		vocalText.scrollFactor.set();
		add(vocalText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		var leText:String = Language.getPhrase("freeplay_tip", "Press SPACE to listen to the Song / Press TAB to choose your character / Press CTRL to open the Gameplay Changers Menu / Press RESET to Reset your Score and Accuracy.");
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);
		
		changeSelection();
		updateTexts();
		updateVocalText();
		super.create();
	}

	function updateVocalText():Void
	{
		if(vocalText == null) return;
		var name:String = songs.length > 0 ? songs[curSelected].songName : '';
		var songId:String = Paths.formatToSongPath(name);
		var picoMode:Bool = ClientPrefs.data.picoVocalMode;

		var effective:String = 'BF';
		if(picoMode && PicoMix.chartExists(songId, Difficulty.getFilePath(curDifficulty)))
			effective = 'PICO MIX';
		else if(PicoMix.isWeekendSong(name))
			effective = 'PICO (weekend)';

		vocalText.text = 'VOCALS: $effective  [TAB: ${picoMode ? "PICO" : "BF"}]';
	}

	/**
	 * BF hides songs with no BF vocals (Weekend 1 / explicit Pico marks).
	 * Pico hides songs with neither Pico vocals nor an installed Pico Mix chart.
	 * Dual songs stay visible in both lists.
	 */
	function vocalistMatches(songName:String):Bool
	{
		var picoOnly:Bool = MixesConfig.isPicoOnly(songName) || PicoMix.isPicoName(songName);
		if(!ClientPrefs.data.picoVocalMode) return !picoOnly;
		return picoOnly || PicoMix.chartExists(PicoMix.baseName(songName), '');
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{
		if(WeekData.weeksList.length < 1)
			return;

		if(pendingVocalistReload)
		{
			pendingVocalistReload = false;
			FlxG.resetState();
			return;
		}

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) //No decimals, add an empty space
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2) //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = Language.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
			positionHighscore();
			
			if(songs.length > 1)
			{
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;	
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else 
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		if(FlxG.keys.justPressed.TAB)
		{
			persistentUpdate = false;
			var modeBefore:Bool = ClientPrefs.data.picoVocalMode;
			var vocalSelect:VocalistSelectSubState = new VocalistSelectSubState();
			vocalSelect.onConfirm = function()
			{
				if(ClientPrefs.data.picoVocalMode != modeBefore)
					pendingVocalistReload = true;
			};
			openSubState(vocalSelect);
		}
		else if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if(FlxG.keys.justPressed.SPACE)
		{
			if(instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var target:ChartTarget = currentChart();
				Song.loadFromJson(target.id, target.folder);
				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
						if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch(e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}
					
					opponentVocals = new FlxSound();
					try
					{
						//trace('please work...');
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
							//trace('yaaay!!');
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						//trace('FUUUCK');
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			persistentUpdate = false;
			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var target:ChartTarget = currentChart();

			try
			{
				Song.loadFromJson(target.id, target.folder);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;
				applyErectStage();

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			}
			catch(e:haxe.Exception)
			{
				trace('ERROR! ${e.message}');

				var errorStr:String = e.message;
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
				else errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			stopMusicPlay = true;

			destroyFreeplayVocals();
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if(controls.RESET && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(currentChart().scoreName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}
	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	/**
	 * Apply the erect stage (and spooky dark characters) after a chart is loaded.
	 * Mirrors Erect Mode's `changeStage.lua`, but works with the content baked
	 * into assets/, with no dependency on `currentModDirectory`.
	 */
	function applyErectStage():Void
	{
		var diffName:String = Difficulty.getString(curDifficulty, false);
		if(!ErectRemix.usesErectAssets(diffName)) return;

		var songId:String = Paths.formatToSongPath(songs[curSelected].songName);
		if(!erectFolders.exists(songId)) return;

		var baseStage:String = PlayState.SONG.stage;
		var erect:String = ErectRemix.erectStage(baseStage);
		if(erect == null) return;

		PlayState.SONG.stage = erect;
		trace('Erect stage: $baseStage -> $erect');

		if(ErectRemix.isSpookyErect(erect))
		{
			if(PlayState.SONG.player1 != null) PlayState.SONG.player1 += '-dark';
			if(PlayState.SONG.player2 != null) PlayState.SONG.player2 += '-dark';
			if(PlayState.SONG.gfVersion != null) PlayState.SONG.gfVersion += '-dark';
		}
	}

	function currentChart():ChartTarget
	{
		var songName:String = songs[curSelected].songName;
		var songId:String = Paths.formatToSongPath(songName);
		var diffName:String = Difficulty.getString(curDifficulty, false);
		var erectFolder:String = erectFolders.get(songId);

		if(erectFolder != null && ErectRemix.usesErectAssets(diffName))
		{
			trace('Erect chart: $songName / $diffName -> $erectFolder');
			return {
				id: ErectRemix.chartId(erectFolder, diffName),
				folder: erectFolder,
				scoreName: erectFolder
			};
		}

		// TAB toggle: when Pico vocals are requested, load the installed
		// `(Pico Mix)` chart when one exists. Weekend songs are already
		// Pico-sung in their base chart, so they only need a mix when the
		// user installs one. Scores stay in their own bucket.
		if(ClientPrefs.data.picoVocalMode && !PicoMix.isPicoName(songName))
		{
			var picoFolder:String = PicoMix.folderFor(songId);
			if(PicoMix.chartExists(songId, Difficulty.getFilePath(curDifficulty)))
			{
				trace('Pico chart: $songName -> $picoFolder');
				return {
					id: Highscore.formatSong(picoFolder, curDifficulty),
					folder: picoFolder,
					scoreName: picoFolder
				};
			}
		}

		return {
			id: Highscore.formatSong(songName, curDifficulty),
			folder: songId,
			scoreName: songName
		};
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		#if !switch
		var target:ChartTarget = currentChart();
		intendedScore = Highscore.getScore(target.scoreName, curDifficulty);
		intendedRating = Highscore.getRating(target.scoreName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
		updateVocalText();
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			var icon:HealthIcon = iconArray[num];
			item.alpha = 0.6;
			icon.alpha = 0.6;
			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();

		if(erectFolders.exists(Paths.formatToSongPath(songs[curSelected].songName)))
		{
			if(!Difficulty.list.contains('Erect')) Difficulty.list.push('Erect');
			if(!Difficulty.list.contains('Nightmare')) Difficulty.list.push('Nightmare');
		}

		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			var icon:HealthIcon = iconArray[i];
			icon.visible = icon.active = true;
			_lastVisibles.push(i);
		}
	}

	function applyCustomSoundsFreeplay()
	{
		if (menuCustomCfg == null || menuCustomCfg.sounds == null) return;
		if (menuCustomCfg.sounds.music != null && menuCustomCfg.sounds.music.length > 0)
		{
			try { FlxG.sound.playMusic(Paths.music(menuCustomCfg.sounds.music), 0.8); } catch(e:Dynamic) {}
		}
	}

	function addFreeplayLayers()
	{
		if (menuCustomCfg == null || menuCustomCfg.layers == null) return;
		for (layer in menuCustomCfg.layers)
		{
			if (!layer.visible) continue;
			var spr:FlxSprite = new FlxSprite(layer.x, layer.y);
			try { spr.loadGraphic(Paths.image(layer.image)); } catch(e:Dynamic) { spr.makeGraphic(200, 150, 0xFF9271fd); spr.alpha = 0.4; }
			spr.scale.set(layer.scaleX, layer.scaleY);
			spr.alpha = layer.alpha;
			spr.angle = layer.angle;
			spr.scrollFactor.set(layer.scrollX, layer.scrollY);
			spr.antialiasing = layer.antialiasing;
			spr.updateHitbox();
			menuLayers.add(spr);
		}
	}

	override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}	
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}