package options;

import backend.CalibrationScroll;
import backend.MainMenuConfig;
import backend.OffsetCalibrator;
import objects.Bar;
import objects.Note;
import flixel.addons.display.shapes.FlxShapeCircle;
import flixel.input.gamepad.FlxGamepadInputID;

class NoteOffsetState extends MusicBeatState
{
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;
	public var camOther:FlxCamera;

	var menuBg:FlxSprite;
	var receptor:FlxSprite;
	var risingArrows:Array<FlxSprite> = [];
	var receptorY:Float = 0;

	var coolText:FlxText;
	var rating:FlxSprite;
	var comboNums:FlxSpriteGroup;
	var dumbTexts:FlxTypedGroup<FlxText>;

	var barPercent:Float = 0;
	var delayMin:Int = -500;
	var delayMax:Int = 500;
	var timeBar:Bar;
	var timeTxt:FlxText;
	var changeModeText:FlxText;
	var autoStatusText:FlxText;

	// 0 = combo, 1 = audio offset, 2 = video offset
	var mode:Int = 0;
	// 0 = idle, 1 = audio tap pass, 2 = visual tap pass
	var calibrationPhase:Int = 0;
	var autoTaps:Array<Float> = [];
	var calibratedAudio:Int = 0;

	var drumsSound:FlxSound;

	var controllerPointer:FlxSprite;
	var _lastControllerMode:Bool = false;

	override public function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Delay/Combo Offset Menu", null);
		#end

		// Cameras
		camGame = initPsychCamera();

		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camHUD, false);

		camOther = new FlxCamera();
		camOther.bgColor.alpha = 0;
		FlxG.cameras.add(camOther, false);

		persistentUpdate = true;
		FlxG.sound.pause();

		// Same backdrop as the main menu, so the calibration reads as part of it.
		var menuConfig = MainMenuConfig.load();
		MainMenuConfig.sanitize(menuConfig);
		var yScroll:Float = menuConfig.bgScrollSpeed;
		menuBg = new FlxSprite(-80).loadGraphic(Paths.image(menuConfig.bgImage));
		menuBg.antialiasing = ClientPrefs.data.antialiasing;
		menuBg.scrollFactor.set(0, yScroll);
		menuBg.setGraphicSize(Std.int(menuBg.width * 1.175));
		menuBg.updateHitbox();
		menuBg.screenCenter();
		add(menuBg);

		// Combo stuff
		coolText = new FlxText(0, 0, 0, '', 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.35;

		rating = new FlxSprite().loadGraphic(Paths.image('sick'));
		rating.cameras = [camHUD];
		rating.antialiasing = ClientPrefs.data.antialiasing;
		rating.setGraphicSize(Std.int(rating.width * 0.7));
		rating.updateHitbox();

		add(rating);

		comboNums = new FlxSpriteGroup();
		comboNums.cameras = [camHUD];
		add(comboNums);

		var seperatedScore:Array<Int> = [];
		for (i in 0...3)
		{
			seperatedScore.push(FlxG.random.int(0, 9));
		}

		var daLoop:Int = 0;
		for (i in seperatedScore)
		{
			var numScore:FlxSprite = new FlxSprite(43 * daLoop).loadGraphic(Paths.image('num' + i));
			numScore.cameras = [camHUD];
			numScore.antialiasing = ClientPrefs.data.antialiasing;
			numScore.setGraphicSize(Std.int(numScore.width * 0.5));
			numScore.updateHitbox();
			comboNums.add(numScore);
			daLoop++;
		}

		dumbTexts = new FlxTypedGroup<FlxText>();
		dumbTexts.cameras = [camHUD];
		add(dumbTexts);
		createTexts();

		repositionCombo();

		// Gameplay-style calibration lane: one fixed receptor, arrows rising to it.
		receptorY = FlxG.height * 0.5;
		receptor = makeArrow(1, 'arrowUP0000', false);
		receptor.screenCenter(X);
		receptor.y = receptorY - receptor.height / 2;
		add(receptor);

		for (i in 0...(CalibrationScroll.BEATS_BEHIND + CalibrationScroll.BEATS_AHEAD))
		{
			var arrow:FlxSprite = makeArrow(0.85, 'green0000', true);
			arrow.screenCenter(X);
			arrow.visible = false;
			risingArrows.push(arrow);
			add(arrow);
		}

		// Note delay stuff
		timeTxt = new FlxText(0, 600, FlxG.width, "", 32);
		timeTxt.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		timeTxt.scrollFactor.set();
		timeTxt.borderSize = 2;
		timeTxt.visible = false;
		timeTxt.cameras = [camHUD];

		barPercent = currentOffset();
		updateNoteDelay();

		timeBar = new Bar(0, timeTxt.y + (timeTxt.height / 3), 'healthBar', function() return barPercent, delayMin, delayMax);
		timeBar.scrollFactor.set();
		timeBar.screenCenter(X);
		timeBar.visible = false;
		timeBar.cameras = [camHUD];
		timeBar.leftBar.color = FlxColor.LIME;

		add(timeBar);
		add(timeTxt);

		///////////////////////

		var blackBox:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 40, FlxColor.BLACK);
		blackBox.scrollFactor.set();
		blackBox.alpha = 0.6;
		blackBox.cameras = [camHUD];
		add(blackBox);

		changeModeText = new FlxText(0, 4, FlxG.width, "", 32);
		changeModeText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER);
		changeModeText.scrollFactor.set();
		changeModeText.cameras = [camHUD];
		add(changeModeText);

		autoStatusText = new FlxText(0, timeTxt.y + 44, FlxG.width, "", 20);
		autoStatusText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		autoStatusText.scrollFactor.set();
		autoStatusText.borderSize = 2;
		autoStatusText.visible = false;
		autoStatusText.cameras = [camHUD];
		add(autoStatusText);

		controllerPointer = new FlxShapeCircle(0, 0, 20, {thickness: 0}, FlxColor.WHITE);
		controllerPointer.offset.set(20, 20);
		controllerPointer.screenCenter();
		controllerPointer.alpha = 0.6;
		controllerPointer.cameras = [camHUD];
		add(controllerPointer);

		updateMode();
		_lastControllerMode = true;

		// Both bundled offset loops are 100 BPM (76.8 s = 128 beats).
		Conductor.bpm = 100.0;
		FlxG.sound.playMusic(Paths.music('offset/offsetsLoop'), 0.5, true);
		drumsSound = FlxG.sound.load(Paths.music('offset/drumsLoop'), 1, true);

		super.create();
	}

	function makeArrow(scale:Float, framePrefix:String, useUserColors:Bool):FlxSprite
	{
		var arrow:FlxSprite = new FlxSprite();
		arrow.frames = Paths.getSparrowAtlas('noteSkins/NOTE_assets');
		arrow.animation.addByPrefix('note', framePrefix, 24, false);
		arrow.animation.play('note');
		// Lane 2 is UP; its RGB palette is the one the user configured in Note Colors.
		if(useUserColors) arrow.shader = Note.initializeGlobalRGBShader(2).shader;
		arrow.antialiasing = ClientPrefs.data.antialiasing;
		arrow.setGraphicSize(Std.int(arrow.width * scale));
		arrow.updateHitbox();
		arrow.cameras = [camHUD];
		return arrow;
	}

	function currentOffset():Int
	{
		return mode == 2 ? ClientPrefs.data.videoOffset : ClientPrefs.data.noteOffset;
	}

	function setCurrentOffset(value:Int):Void
	{
		if(mode == 2) ClientPrefs.data.videoOffset = value;
		else ClientPrefs.data.noteOffset = value;
	}

	var holdTime:Float = 0;
	var onComboMenu:Bool = true;
	var holdingObjectType:Null<Bool> = null;

	var startMousePos:FlxPoint = new FlxPoint();
	var startComboOffset:FlxPoint = new FlxPoint();

	override public function update(elapsed:Float)
	{
		var addNum:Int = 1;
		if(FlxG.keys.pressed.SHIFT || FlxG.gamepads.anyPressed(LEFT_SHOULDER))
		{
			if(onComboMenu)
				addNum = 10;
			else
				addNum = 3;
		}

		if(FlxG.gamepads.anyJustPressed(ANY)) controls.controllerMode = true;
		else if(FlxG.mouse.justPressed) controls.controllerMode = false;

		if(controls.controllerMode != _lastControllerMode)
		{
			FlxG.mouse.visible = !controls.controllerMode;
			controllerPointer.visible = controls.controllerMode;

			if(controls.controllerMode)
			{
				var mousePos = FlxG.mouse.getScreenPosition(camHUD);
				controllerPointer.x = mousePos.x;
				controllerPointer.y = mousePos.y;
			}
			updateMode();
			_lastControllerMode = controls.controllerMode;
		}

		if(calibrationPhase == 0 && mode > 0 && (FlxG.keys.justPressed.C || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.Y)))
			startAutoCalibration();

		if(calibrationPhase > 0)
			collectAutoTap();

		if(onComboMenu)
		{
			if(FlxG.keys.justPressed.ANY || FlxG.gamepads.anyJustPressed(ANY))
			{
				var controlArray:Array<Bool> = null;
				if(!controls.controllerMode)
				{
					controlArray = [
						FlxG.keys.justPressed.LEFT,
						FlxG.keys.justPressed.RIGHT,
						FlxG.keys.justPressed.UP,
						FlxG.keys.justPressed.DOWN,

						FlxG.keys.justPressed.A,
						FlxG.keys.justPressed.D,
						FlxG.keys.justPressed.W,
						FlxG.keys.justPressed.S
					];
				}
				else
				{
					controlArray = [
						FlxG.gamepads.anyJustPressed(DPAD_LEFT),
						FlxG.gamepads.anyJustPressed(DPAD_RIGHT),
						FlxG.gamepads.anyJustPressed(DPAD_UP),
						FlxG.gamepads.anyJustPressed(DPAD_DOWN),

						FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_LEFT),
						FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_RIGHT),
						FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_UP),
						FlxG.gamepads.anyJustPressed(RIGHT_STICK_DIGITAL_DOWN)
					];
				}

				if(controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if(controlArray[i])
						{
							switch(i)
							{
								case 0:
									ClientPrefs.data.comboOffset[0] -= addNum;
								case 1:
									ClientPrefs.data.comboOffset[0] += addNum;
								case 2:
									ClientPrefs.data.comboOffset[1] += addNum;
								case 3:
									ClientPrefs.data.comboOffset[1] -= addNum;
								case 4:
									ClientPrefs.data.comboOffset[2] -= addNum;
								case 5:
									ClientPrefs.data.comboOffset[2] += addNum;
								case 6:
									ClientPrefs.data.comboOffset[3] += addNum;
								case 7:
									ClientPrefs.data.comboOffset[3] -= addNum;
							}
						}
					}
					repositionCombo();
				}
			}

			// controller things
			var analogX:Float = 0;
			var analogY:Float = 0;
			var analogMoved:Bool = false;
			var gamepadPressed:Bool = false;
			var gamepadReleased:Bool = false;
			if(controls.controllerMode)
			{
				for (gamepad in FlxG.gamepads.getActiveGamepads())
				{
					analogX = gamepad.getXAxis(LEFT_ANALOG_STICK);
					analogY = gamepad.getYAxis(LEFT_ANALOG_STICK);
					analogMoved = (analogX != 0 || analogY != 0);
					if(analogMoved) break;
				}
				controllerPointer.x = Math.max(0, Math.min(FlxG.width, controllerPointer.x + analogX * 1000 * elapsed));
				controllerPointer.y = Math.max(0, Math.min(FlxG.height, controllerPointer.y + analogY * 1000 * elapsed));
				gamepadPressed = !FlxG.gamepads.anyJustPressed(START) && controls.ACCEPT;
				gamepadReleased = !FlxG.gamepads.anyJustReleased(START) && controls.justReleased('accept');
			}
			//

			// probably there's a better way to do this but, oh well.
			if (FlxG.mouse.justPressed || gamepadPressed)
			{
				holdingObjectType = null;
				if(!controls.controllerMode)
					FlxG.mouse.getScreenPosition(camHUD, startMousePos);
				else
					controllerPointer.getScreenPosition(startMousePos, camHUD);

				if (startMousePos.x - comboNums.x >= 0 && startMousePos.x - comboNums.x <= comboNums.width &&
					startMousePos.y - comboNums.y >= 0 && startMousePos.y - comboNums.y <= comboNums.height)
				{
					holdingObjectType = true;
					startComboOffset.x = ClientPrefs.data.comboOffset[2];
					startComboOffset.y = ClientPrefs.data.comboOffset[3];
				}
				else if (startMousePos.x - rating.x >= 0 && startMousePos.x - rating.x <= rating.width &&
						 startMousePos.y - rating.y >= 0 && startMousePos.y - rating.y <= rating.height)
				{
					holdingObjectType = false;
					startComboOffset.x = ClientPrefs.data.comboOffset[0];
					startComboOffset.y = ClientPrefs.data.comboOffset[1];
				}
			}
			if(FlxG.mouse.justReleased || gamepadReleased) {
				holdingObjectType = null;
			}

			if(holdingObjectType != null)
			{
				if(FlxG.mouse.justMoved || analogMoved)
				{
					var mousePos:FlxPoint = null;
					if(!controls.controllerMode)
						mousePos = FlxG.mouse.getScreenPosition(camHUD);
					else
						mousePos = controllerPointer.getScreenPosition(camHUD);

					var addNum:Int = holdingObjectType ? 2 : 0;
					ClientPrefs.data.comboOffset[addNum + 0] = Math.round((mousePos.x - startMousePos.x) + startComboOffset.x);
					ClientPrefs.data.comboOffset[addNum + 1] = -Math.round((mousePos.y - startMousePos.y) - startComboOffset.y);
					repositionCombo();
				}
			}

			if(controls.RESET)
			{
				for (i in 0...ClientPrefs.data.comboOffset.length)
				{
					ClientPrefs.data.comboOffset[i] = 0;
				}
				repositionCombo();
			}
		}
		else if(calibrationPhase == 0)
		{
			if(controls.UI_LEFT_P)
			{
				barPercent = Math.max(delayMin, Math.min(currentOffset() - 1, delayMax));
				updateNoteDelay();
			}
			else if(controls.UI_RIGHT_P)
			{
				barPercent = Math.max(delayMin, Math.min(currentOffset() + 1, delayMax));
				updateNoteDelay();
			}

			var mult:Int = 1;
			if(controls.UI_LEFT || controls.UI_RIGHT)
			{
				holdTime += elapsed;
				if(controls.UI_LEFT) mult = -1;
			}

			if(controls.UI_LEFT_R || controls.UI_RIGHT_R) holdTime = 0;

			if(holdTime > 0.5)
			{
				barPercent += 100 * addNum * elapsed * mult;
				barPercent = Math.max(delayMin, Math.min(barPercent, delayMax));
				updateNoteDelay();
			}

			if(controls.RESET)
			{
				holdTime = 0;
				barPercent = 0;
				updateNoteDelay();
			}
		}

		if(calibrationPhase == 0 && ((!controls.controllerMode && controls.ACCEPT) ||
		(controls.controllerMode && FlxG.gamepads.anyJustPressed(START))))
		{
			mode = (mode + 1) % 3;
			onComboMenu = (mode == 0);
			barPercent = currentOffset();
			updateNoteDelay();
			updateMode();
		}

		if(controls.BACK)
		{
			stopCalibration();
			persistentUpdate = false;
			ClientPrefs.saveSettings();
			MusicBeatState.switchState(new options.OptionsState());
			if(OptionsState.onPlayState)
			{
				if(ClientPrefs.data.pauseMusic != 'None')
					FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)));
				else
					FlxG.sound.music.volume = 0;
			}
			else FlxG.sound.playMusic(Paths.music('freakyMenu'));
			FlxG.mouse.visible = false;
		}

		updateRisingArrows();
		if(receptor.scale.x > 1)
		{
			var next:Float = Math.max(1, receptor.scale.x - elapsed * 1.5);
			receptor.scale.set(next, next);
		}

		Conductor.songPosition = FlxG.sound.music.time;
		super.update(elapsed);
	}

	function updateRisingArrows():Void
	{
		var beatInterval:Float = Conductor.crochet;
		var base:Int = CalibrationScroll.currentBeatIndex(Conductor.songPosition, beatInterval);
		var songPosition:Float = Conductor.songPosition;
		var calibrating:Bool = calibrationPhase > 0 && mode > 0;

		for (i in 0...risingArrows.length)
		{
			var arrow:FlxSprite = risingArrows[i];
			// One beat yes, one beat no: notes sit either side of the current beat.
			var beatIndex:Int = base + (i == 0 ? -CalibrationScroll.BEATS_BEHIND : CalibrationScroll.BEATS_AHEAD);
			if(beatIndex < 0 || !calibrating)
			{
				arrow.visible = false;
				continue;
			}

			var beatTime:Float = CalibrationScroll.beatTime(beatIndex, beatInterval);
			var y:Float = CalibrationScroll.arrowY(receptorY - arrow.height / 2, beatTime, songPosition);
			arrow.y = y;
			arrow.visible = y > -arrow.height && y < FlxG.height + arrow.height;
		}
	}

	var lastBeatHit:Int = -1;
	override public function beatHit()
	{
		super.beatHit();

		if(lastBeatHit == curBeat) return;
		if(mode > 0) receptor.scale.set(1.18, 1.18);
		lastBeatHit = curBeat;
	}

	function repositionCombo()
	{
		rating.screenCenter();
		rating.x = coolText.x - 40 + ClientPrefs.data.comboOffset[0];
		rating.y -= 60 + ClientPrefs.data.comboOffset[1];

		comboNums.screenCenter();
		comboNums.x = coolText.x - 90 + ClientPrefs.data.comboOffset[2];
		comboNums.y += 80 - ClientPrefs.data.comboOffset[3];
		reloadTexts();
	}

	function createTexts()
	{
		for (i in 0...4)
		{
			var text:FlxText = new FlxText(10, 48 + (i * 30), 0, '', 24);
			text.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			text.scrollFactor.set();
			text.borderSize = 2;
			dumbTexts.add(text);
			text.cameras = [camHUD];

			if(i > 1)
			{
				text.y += 24;
			}
		}
	}

	function reloadTexts()
	{
		for (i in 0...dumbTexts.length)
		{
			switch(i)
			{
				case 0: dumbTexts.members[i].text = Language.getPhrase('combo_rating_offset', 'Rating Offset:');
				case 1: dumbTexts.members[i].text = '[' + ClientPrefs.data.comboOffset[0] + ', ' + ClientPrefs.data.comboOffset[1] + ']';
				case 2: dumbTexts.members[i].text = Language.getPhrase('combo_numbers_offset', 'Numbers Offset:');
				case 3: dumbTexts.members[i].text = '[' + ClientPrefs.data.comboOffset[2] + ', ' + ClientPrefs.data.comboOffset[3] + ']';
			}
		}
	}

	function updateNoteDelay()
	{
		setCurrentOffset(Math.round(barPercent));
		timeTxt.text = Language.getPhrase('delay_current_offset', 'Current offset: {1} ms', [Math.floor(barPercent)]) +
			'  (audio ' + ClientPrefs.data.noteOffset + ' / video ' + ClientPrefs.data.videoOffset + ')';
	}

	function updateMode()
	{
		onComboMenu = (mode == 0);
		rating.visible = onComboMenu;
		comboNums.visible = onComboMenu;
		dumbTexts.visible = onComboMenu;

		timeBar.visible = !onComboMenu;
		timeTxt.visible = !onComboMenu;
		autoStatusText.visible = !onComboMenu;
		if(!onComboMenu && calibrationPhase == 0)
			autoStatusText.text = Language.getPhrase('auto_offset_hint', 'Press C / Y to auto-calibrate, then tap to the beat (8 taps).');

		controllerPointer.visible = false;
		FlxG.mouse.visible = false;
		if(onComboMenu)
		{
			FlxG.mouse.visible = !controls.controllerMode;
			controllerPointer.visible = controls.controllerMode;
		}

		var str:String = switch(mode)
		{
			case 0: Language.getPhrase('combo_offset', 'Combo Offset');
			case 1: Language.getPhrase('audio_offset', 'Audio Offset');
			default: Language.getPhrase('video_offset', 'Video Offset');
		};
		var str2:String;
		if(!controls.controllerMode)
			str2 = Language.getPhrase('switch_on_accept', '(Press Accept to Switch)');
		else
			str2 = Language.getPhrase('switch_on_start', '(Press Start to Switch)');

		changeModeText.text = '< ${str.toUpperCase()} ${str2.toUpperCase()} >';
	}

	function stopCalibration():Void
	{
		calibrationPhase = 0;
		autoTaps = [];
		if(drumsSound != null)
		{
			drumsSound.stop();
			drumsSound.volume = 1;
		}
		if(FlxG.sound.music != null) FlxG.sound.music.volume = 0.5;
	}

	function startAutoCalibration():Void
	{
		calibrationPhase = 1;
		autoTaps = [];
		calibratedAudio = ClientPrefs.data.noteOffset;
		if(drumsSound != null)
		{
			drumsSound.play();
			// Align the drum loop's beat grid with the music's grid.
			drumsSound.time = FlxG.sound.music.time % Conductor.crochet;
			drumsSound.volume = 1;
		}
		if(FlxG.sound.music != null) FlxG.sound.music.volume = 0.35;
		autoStatusText.text = Language.getPhrase('auto_offset_audio_hint', 'Audio calibration: tap to the beat (8 taps).');
	}

	function collectAutoTap():Void
	{
		var tapped:Bool = FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN ||
			FlxG.keys.justPressed.A || FlxG.keys.justPressed.D || FlxG.keys.justPressed.W || FlxG.keys.justPressed.S ||
			FlxG.gamepads.anyJustPressed(FlxGamepadInputID.A) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.B) ||
			FlxG.gamepads.anyJustPressed(FlxGamepadInputID.X) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.Y) ||
			FlxG.gamepads.anyJustPressed(FlxGamepadInputID.DPAD_LEFT) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.DPAD_RIGHT) ||
			FlxG.gamepads.anyJustPressed(FlxGamepadInputID.DPAD_UP) || FlxG.gamepads.anyJustPressed(FlxGamepadInputID.DPAD_DOWN);
		if(!tapped) return;

		autoTaps.push(FlxG.sound.music != null ? FlxG.sound.music.time : Conductor.songPosition);
		if(autoTaps.length < 8)
		{
			autoStatusText.text = 'Auto calibration: ${autoTaps.length}/8 taps';
			return;
		}

		var result:Null<Int> = OffsetCalibrator.suggestOffset(autoTaps, Conductor.crochet);
		autoTaps = [];
		if(result == null)
		{
			stopCalibration();
			autoStatusText.text = Language.getPhrase('auto_offset_failed', 'Auto calibration failed. Try again.');
			return;
		}

		if(calibrationPhase == 1)
		{
			calibratedAudio = result;
			barPercent = result;
			ClientPrefs.data.noteOffset = result;
			updateNoteDelay();

			calibrationPhase = 2;
			if(drumsSound != null) drumsSound.volume = 0;
			autoStatusText.text = Language.getPhrase('auto_offset_video_hint', 'Audio: {1} ms. Now tap when the arrow reaches the center (8 taps).', [result]);
			return;
		}

		ClientPrefs.data.videoOffset = result;
		stopCalibration();
		ClientPrefs.saveSettings();
		barPercent = mode == 2 ? result : ClientPrefs.data.noteOffset;
		updateNoteDelay();
		autoStatusText.text = Language.getPhrase('auto_offset_done_both', 'Audio: {1} ms / Video: {2} ms (applied). Press C / Y to retry.', [calibratedAudio, result]);
	}
}
