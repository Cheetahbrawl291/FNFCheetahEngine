package substates;

import openfl.display.BitmapData;
import openfl.geom.Point;

import backend.CharSelectConfig;
import backend.CharSelectConfig.CharSelectCharacter;
import backend.CharSelectConfig.CharSelectConfigData;
import backend.CharSelectConfig.CharSelectMix;

/**
 * Standalone character selector opened with TAB from Freeplay.
 * A 3x3 grid holds the two selectable icons (BF / Pico) in the middle;
 * every other slot is a padlock. Arrow keys or TAB move the cursor,
 * ACCEPT confirms, BACK cancels.
 *
 * Art is optional and read from assets/shared/images/CharSelect:
 *   bg/             -> first available bg image fills the screen
 *   titles/         -> boyfriend.png / Pico.png title art
 *   icons/          -> Sparrow atlases for the icons and the padlocks
 *   Sounds/         -> change / confirm / locked cues
 */
class VocalistSelectSubState extends MusicBeatSubstate
{
	static final NAMES:Array<String> = ['BF', 'PICO'];
	static final TITLES:Array<String> = ['titles/boyfriend', 'titles/Pico'];
	static final ICON_KEYS:Array<String> = [
		'CharSelect/icons/Boyfriend/bfIcon',
		'CharSelect/icons/Pico/picoIcon'
	];
	static final ICON_PREFIX:Array<String> = [
		'boyfriend icon instance',
		'Pico Icon instance'
	];
	static final LOCK_PREFIX:Array<String> = [
		'LOCK FULL 1 instance', 'LOCK FULL 2 instance', 'LOCK FULL 3 instance',
		'LOCK FULL 4 instance', 'LOCK FULL 5 instance', 'LOCK FULL 6 instance'
	];

	// 9 grid slots. -1 = padlock, 0 = BF, 1 = Pico.
	// Pico is far left, BF in the middle; the rest are padlocks.
	static final LAYOUT:Array<Int> = [
		-1, -1, -1,
		 1,  0, -1,
		-1, -1, -1
	];
	static final PICO_CELL:Int = 3;
	static final BF_CELL:Int = 4;

	// Let the confirm cue play before the substate closes.
	static final CONFIRM_DELAY:Float = 1.1;
	static final FADE_TIME:Float = 0.5;
	static final FLASH_TIME:Float = 0.35;
	static final ICON_FPS:Int = 16;
	static final TITLE_X:Float = 0.84;
	static final TITLE_Y:Float = 78;
	static final TITLE_SCALE:Float = 0.7;
	static final GAP_X:Float = 0.11;
	static final GAP_Y:Float = 0.18;

	// Some lock atlases hold two identical 20-frame cycles (10000..10019 and
	// 20000..20019). addByPrefix would play both, so pin the frame range.
	static final LOCK_FRAMES:Int = 20;
	static final LOCK_FPS:Int = 32;
	// Trimmed resting frames place the lock art ~10px below its source box.
	static final LOCK_Y_NUDGE:Float = 10;

	// Preview panel to the right of the 3x3 grid.
	static final PREVIEW_X:Float = 0.79;
	static final PREVIEW_Y:Float = 0.57;
	static final PREVIEW_HEIGHT:Float = 340;
	static final PREVIEW_FPS:Float = 25;
	static final PLACEHOLDER_FPS:Float = 12.5;
	static final PREVIEW_PLACEHOLDER:Int = 2;
	/** Preview slots 0..2 are the built-ins; custom characters start at 3. */
	static final BUILTIN_COUNT:Int = 3;

	var selected:Int = 0;
	var cursor:Int = BF_CELL;
	var bgHasArt:Bool = false;
	var bg:FlxSprite;
	var chooseBacking:FlxSprite = null;
	var titleText:Alphabet;
	var titleArt:FlxSprite;
	var cells:Array<FlxSprite> = [];
	var baseScales:Array<Float> = [];
	// 0 = BF, 1 = Pico, 2 = placeholder (padlocks).
	var previews:Array<FlxSprite> = [];
	var previewMeta:Array<Dynamic> = [];
	var activePreview:Int = -1;
	var cursorBox:FlxSprite;
	var cursorTween:FlxTween = null;
	var selectorPlaced:Bool = false;
	var bgCrowd:FlxAnimate = null;
	var bgStage:FlxAnimate = null;
	var selectorMusic:FlxSound = null;
	var pausedMusic:Bool = false;
	var transitionSprite:FlxSprite;
	var transitioning:Bool = false;
	var confirming:Bool = false;

	/** Called after a confirmed change so the parent can refresh its list. */
	public var onConfirm:Void->Void = null;
	/** Full-screen intro plays before the menu (frames + synced audio). */
	var introSprite:FlxSprite = null;
	var introSound:FlxSound = null;
	var introPlaying:Bool = false;

	/** Custom characters and mixes loaded from mods/data/charselect.json. */
	var charConfig:CharSelectConfigData = null;
	/** Cell index -> preview index (-1 = padlock). Built from LAYOUT + config. */
	var slotOwner:Array<Int> = [];

	public function new()
	{
		super();

		charConfig = CharSelectConfig.load();
		buildSlotOwner();
		selected = ClientPrefs.data.picoVocalMode ? 1 : 0;
		// If the saved vocal mode belongs to a custom character, start there.
		if(charConfig != null)
			for(i in 0...charConfig.characters.length)
			{
				var c:CharSelectCharacter = charConfig.characters[i];
				if((c.mix == 'pico') == ClientPrefs.data.picoVocalMode)
				{
					selected = BUILTIN_COUNT + i;
					break;
				}
			}
		cursor = cellForPreview(selected);
		if(cursor < 0) cursor = BF_CELL;
		trace('Vocalist selector opened: ${nameForPreview(selected)}');
		pauseParentMusic();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);
		loadBackground();
		addChooseArt();
		buildPreviews();

		cursorBox = new FlxSprite().loadGraphic(Paths.image('CharSelect/charSelector'));
		cursorBox.scrollFactor.set();
		add(cursorBox);

		buildGrid();

		titleArt = new FlxSprite();
		titleArt.scrollFactor.set();
		add(titleArt);
		titleText = new Alphabet(0, 70, NAMES[selected], true);
		titleText.screenCenter(X);
		titleText.alpha = 0;
		add(titleText);
		loadTitleArt();

		updateGridVisuals();
		showPreview(selected);

		// Full-screen fade layer for entry/exit transitions.
		transitionSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		transitionSprite.scrollFactor.set();
		transitionSprite.alpha = 1;
		add(transitionSprite);
		transitioning = true;
		FlxTween.tween(transitionSprite, {alpha: 0}, FADE_TIME, {
			ease: FlxEase.quadOut,
			onComplete: function(_) transitioning = false
		});

		// Intro is added last so it covers the selector while it plays.
		startIntroVideo();
	}

	/** Checks mods first, then embedded assets, so mod overrides are visible. */
	function assetExists(rel:String):Bool
	{
		var key:String = 'images/CharSelect/$rel';
		return Paths.fileExists(key, (rel.endsWith('.xml') || rel.endsWith('.json')) ? TEXT : IMAGE);
	}

	function buildSlotOwner():Void
	{
		slotOwner = LAYOUT.copy();
		if(charConfig == null) return;
		for(i in 0...charConfig.characters.length)
		{
			var c:CharSelectCharacter = charConfig.characters[i];
			if(c.slot >= 0 && c.slot < slotOwner.length)
				slotOwner[c.slot] = BUILTIN_COUNT + i;
		}
	}

	inline function charDef(preview:Int):CharSelectCharacter
	{
		return (charConfig != null && preview >= BUILTIN_COUNT)
			? charConfig.characters[preview - BUILTIN_COUNT] : null;
	}

	function nameForPreview(preview:Int):String
	{
		var c:CharSelectCharacter = charDef(preview);
		if(c != null) return c.name;
		return (preview >= 0 && preview < NAMES.length) ? NAMES[preview] : '???';
	}

	function cellForPreview(preview:Int):Int
	{
		for(i in 0...slotOwner.length)
			if(slotOwner[i] == preview) return i;
		return -1;
	}

	function selectablePreviews():Array<Int>
	{
		var out:Array<Int> = [0, 1];
		if(charConfig != null)
			for(i in 0...charConfig.characters.length) out.push(BUILTIN_COUNT + i);
		return out;
	}

	inline function cellSize():Float
		return FlxG.width * 0.15;

	function cellPosition(index:Int):{x:Float, y:Float}
	{
		var col:Int = index % 3;
		var row:Int = Std.int(index / 3);
		var gapX:Float = FlxG.width * GAP_X;
		var gapY:Float = FlxG.height * GAP_Y;
		// Even 3x3 grid centred on screen, no half-cell offset.
		var x:Float = FlxG.width / 2 + (col - 1) * gapX;
		var y:Float = FlxG.height * 0.52 + (row - 1) * gapY;
		return {x: x, y: y};
	}

	/** Centers a cell on its slot, lifting padlocks so their trimmed art lines
	 *  up with the character icons. */
	function positionCell(index:Int, spr:FlxSprite):Void
	{
		var p = cellPosition(index);
		spr.x = p.x - spr.width / 2;
		spr.y = p.y - spr.height / 2;
		if(vocalistAt(index) < 0)
			spr.y -= LOCK_Y_NUDGE * spr.scale.y;
	}

	/** Preview index at a grid cell, or -1 for a padlock. */
	function vocalistAt(index:Int):Int
	{
		if(index < 0 || index >= slotOwner.length) return -1;
		return slotOwner[index];
	}

	function buildGrid():Void
	{
		for(i in 0...slotOwner.length)
		{
			var vocalist:Int = slotOwner[i];
			var spr:FlxSprite = new FlxSprite();
			try
			{
				if(vocalist >= 0)
				{
					var c:CharSelectCharacter = charDef(vocalist);
					var iconKey:String = (c != null && c.icon != null && c.icon.length > 0)
						? c.icon : ICON_KEYS[vocalist < ICON_KEYS.length ? vocalist : 0];
					var prefix:String = (c != null && c.iconPrefix != null && c.iconPrefix.length > 0)
						? c.iconPrefix : ICON_PREFIX[vocalist < ICON_PREFIX.length ? vocalist : 0];
					spr.frames = Paths.getSparrowAtlas(iconKey);
					if(vocalist == 1)
					{
						// Pico's first three frames are lead-in poses; skip them.
						var frames:Array<Int> = [];
						for(f in 3...21) frames.push(10000 + f);
						spr.animation.addByIndices('idle', prefix + ' ', frames, '', ICON_FPS, false);
					}
					else
						spr.animation.addByPrefix('idle', prefix, ICON_FPS, false);
					spr.animation.play('idle');
					spr.animation.pause(); // hold first frame until ENTER
				}
				else
				{
					spr.frames = Paths.getSparrowAtlas('CharSelect/icons/locks');
					var lockFrames:Array<Int> = [];
					for(f in 0...LOCK_FRAMES) lockFrames.push(10000 + f);
					spr.animation.addByIndices('idle', LOCK_PREFIX[i % LOCK_PREFIX.length] + ' ', lockFrames, '', LOCK_FPS, false);
					spr.animation.finishCallback = function(_)
					{
						// Return to the resting frame and size after the deny animation.
						spr.animation.frameIndex = 0;
						spr.animation.pause();
						var s:Float = cellScale(i);
						spr.scale.set(s, s);
						spr.updateHitbox();
						positionCell(i, spr);
					};
					spr.animation.play('idle');
					spr.animation.pause(); // hold first frame until ENTER
				}
			}
			catch(e:Dynamic)
			{
				trace('CharSelect: could not load grid cell $i ($e)');
				spr.makeGraphic(Std.int(cellSize()), Std.int(cellSize()), 0xFF333333);
			}
			spr.scrollFactor.set();
			spr.updateHitbox();
			positionCell(i, spr);
			cells.push(spr);
			add(spr);
		}

		// BF and Pico atlases have different frame sizes. Give both icons the
		// average natural size so neither one looks bigger than the other.
		var iconW:Float = 0;
		var iconH:Float = 0;
		var iconCount:Int = 0;
		for(i in 0...cells.length)
			if(vocalistAt(i) >= 0 && cells[i].frames != null)
			{
				iconW += cells[i].width;
				iconH += cells[i].height;
				iconCount++;
			}
		if(iconCount > 0)
		{
			iconW /= iconCount;
			iconH /= iconCount;
		}

		for(i in 0...cells.length)
		{
			var spr:FlxSprite = cells[i];
			if(vocalistAt(i) >= 0 && iconCount > 0 && spr.width > 0 && spr.height > 0)
				baseScales[i] = 0.75 * ((iconW / spr.width) + (iconH / spr.height)) / 2;
			else
				baseScales[i] = vocalistAt(i) >= 0 ? 0.75 : 1.0;
		}
	}

	/** Preview sprites: intro once when entering a character, then idle loop;
	 *  confirm plays on ENTER and holds its last frame. Placeholder has no
	 *  confirm because padlocks cannot be chosen. */
	function buildPreviews():Void
	{
		addPreview(0, 'CharSelect/char/Boyfriend/preview', PREVIEW_FPS, null, true);
		addPreview(1, 'CharSelect/char/Pico/preview', PREVIEW_FPS, null, true);
		addPreview(PREVIEW_PLACEHOLDER, 'CharSelect/char/Placeholder/preview', PLACEHOLDER_FPS, null, false);
		if(charConfig != null)
			for(i in 0...charConfig.characters.length)
			{
				var c:CharSelectCharacter = charConfig.characters[i];
				addPreview(BUILTIN_COUNT + i, c.atlas, c.fps, c.anchors, true);
			}
	}

	/** Accepts either a Sparrow atlas (animated states) or a single still image. */
	function addPreview(index:Int, key:String, fps:Float, anchors:Dynamic, hasConfirm:Bool):Void
	{
		try
		{
			var p:FlxSprite = new FlxSprite();
			if(Paths.fileExists('images/$key.xml', TEXT) || Paths.fileExists('images/$key.json', TEXT))
			{
				p.frames = Paths.getSparrowAtlas(key);
				p.animation.addByPrefix('idle', 'idle', fps, true);
				p.animation.addByPrefix('intro', 'intro', fps, false);
				if(hasConfirm) p.animation.addByPrefix('confirm', 'confirm', fps, false);
			}
			else
			{
				// Still image: the same frame serves every state.
				p.loadGraphic(Paths.image(key));
				p.animation.add('idle', [0], fps, true);
				p.animation.add('intro', [0], fps, false);
				if(hasConfirm) p.animation.add('confirm', [0], fps, false);
			}
			p.animation.finishCallback = function(name:String)
			{
				// Intro hands off to idle; confirm deliberately holds its last frame.
				if(name == 'intro' && p.animation.getByName('idle') != null)
					p.animation.play('idle');
			};
			p.animation.play('idle');
			p.scrollFactor.set();
			p.visible = false;
			previews[index] = p;
			if(anchors != null) previewMeta[index] = anchors;
			else
			{
				var raw:String = Paths.getTextFromFile('images/${key}.json');
				if(raw != null)
				{
					try previewMeta[index] = haxe.Json.parse(raw)
					catch(e:Dynamic) trace('CharSelect: bad preview meta $key ($e)');
				}
			}
			add(p);
		}
		catch(e:Dynamic)
			trace('CharSelect: could not load preview $key ($e)');
	}

	function showPreview(index:Int):Void
	{
		if(index < 0 || index >= previews.length || activePreview == index) return;
		for(i in 0...previews.length)
			if(previews[i] != null) previews[i].visible = (i == index);
		activePreview = index;
		var p:FlxSprite = previews[index];
		if(p == null) return;
		p.animation.play('intro', true);
		positionPreview(index);
	}

	function confirmPreview(index:Int):Void
	{
		if(index < 0 || index >= previews.length) return;
		var p:FlxSprite = previews[index];
		if(p == null) return;
		activePreview = index;
		for(i in 0...previews.length)
			if(previews[i] != null) previews[i].visible = (i == index);
		if(p.animation.getByName('confirm') != null)
			p.animation.play('confirm', true);
	}

	/** Each state keeps its native GIF size; scale to a common height and
	 *  anchor the art centre so intro -> idle -> confirm never jumps. */
	function positionPreview(index:Int):Void
	{
		var p:FlxSprite = previews[index];
		if(p == null || p.frameHeight <= 0) return;
		var s:Float = PREVIEW_HEIGHT / p.frameHeight;
		p.scale.set(s, s);
		var name:String = p.animation.curAnim != null ? p.animation.curAnim.name : 'idle';
		var meta:Dynamic = index < previewMeta.length ? previewMeta[index] : null;
		var anchor:Dynamic = meta != null ? Reflect.field(meta, name) : null;
		var ax:Float = anchor != null ? Std.parseFloat(Std.string(anchor[0])) : p.frameWidth / 2;
		var ay:Float = anchor != null ? Std.parseFloat(Std.string(anchor[1])) : p.frameHeight / 2;
		p.x = FlxG.width * PREVIEW_X - ax * s;
		p.y = FlxG.height * PREVIEW_Y - ay * s;
	}

	/** Single source of truth for cell scale, shared with the lock's finish
	 *  callback so a confirmed cell keeps the same size on every ENTER. */
	function cellScale(index:Int):Float
	{
		var base:Float = index < baseScales.length ? baseScales[index] : (vocalistAt(index) >= 0 ? 0.75 : 1.0);
		return base * (index == cursor ? 1.35 : 1);
	}

	function updateGridVisuals():Void
	{
		for(i in 0...cells.length)
		{
			var spr:FlxSprite = cells[i];
			var isIcon:Bool = vocalistAt(i) >= 0;
			var s:Float = cellScale(i);
			spr.scale.set(s, s);
			spr.alpha = isIcon ? ((i == cursor) ? 1 : 0.65) : 0.85;
			spr.updateHitbox();
			positionCell(i, spr);
		}
		// Match the highlight to the selected sprite's real hitbox, since
		// icons and padlocks no longer share a scale.
		if(cursor >= 0 && cursor < cells.length)
		{
			var cur:FlxSprite = cells[cursor];
			// One uniform scale keeps the selector's aspect ratio intact.
			var boxW:Float = cur.width * 1.18;
			var boxH:Float = cur.height * 1.18;
			var s:Float = Math.min(1.0, Math.min(boxW / cursorBox.frameWidth, boxH / cursorBox.frameHeight));
			cursorBox.scale.set(s, s);
			cursorBox.updateHitbox();
		}
		var cpos = cellPosition(cursor);
		var targetX:Float = cpos.x - cursorBox.width / 2;
		var targetY:Float = cpos.y - cursorBox.height / 2;
		if(!selectorPlaced)
		{
			cursorBox.x = targetX;
			cursorBox.y = targetY;
			selectorPlaced = true;
		}
		else
		{
			if(cursorTween != null) cursorTween.cancel();
			cursorTween = FlxTween.tween(cursorBox, {x: targetX, y: targetY}, 0.14, {ease: FlxEase.quadOut});
		}
	}

	/** Pauses whichever music Freeplay had, restoring it when the selector closes. */
	function pauseParentMusic():Void
	{
		if(FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			FlxG.sound.music.pause();
			pausedMusic = true;
		}
	}

	/** Plays a cue from the active character's mix, falling back to Sounds/. */
	function playCue(name:String, volume:Float = 1):Void
	{
		var c:CharSelectCharacter = charDef(selected);
		if(c != null)
		{
			var m:CharSelectMix = CharSelectConfig.mix(charConfig, c.mix);
			var key:Dynamic = (m != null && m.sounds != null) ? Reflect.field(m.sounds, name) : null;
			if(key != null && Std.string(key).length > 0)
			{
				var custom = Paths.returnSound(Std.string(key), null, true, false);
				if(custom != null)
				{
					FlxG.sound.play(custom, volume);
					return;
				}
			}
		}
		var snd = Paths.returnSound('images/CharSelect/Sounds/$name', null, true, false);
		if(snd != null) FlxG.sound.play(snd, volume);
	}

	/** Full-screen intro extracted from stayFunky.mp4 as a sprite sheet, with
	 *  its audio in sync. Uses no video decoder dependency. The looping theme
	 *  starts only after the intro finishes. */
	function startIntroVideo():Void
	{
		if(!assetExists('intro/frames.png'))
		{
			startSelectorMusic();
			return;
		}

		try
		{
			introSprite = new FlxSprite();
			introSprite.frames = Paths.getSparrowAtlas('CharSelect/intro/frames');
			introSprite.animation.addByPrefix('intro', 'frame', 24, false);
			introSprite.scrollFactor.set();
			var scaleX:Float = FlxG.width / introSprite.frameWidth;
			var scaleY:Float = FlxG.height / introSprite.frameHeight;
			introSprite.scale.set(scaleX, scaleY);
			introSprite.updateHitbox();
			introSprite.screenCenter();
			introSprite.animation.finishCallback = function(name:String)
			{
				if(name == 'intro') onIntroFinished();
			};
			add(introSprite);

			// Audio decoded from the same mp4, played in sync with the frames.
			try
			{
				introSound = FlxG.sound.play(Paths.music('charSelectIntro/charSelectIntro'), 1);
			}
			catch(e:Dynamic)
			{
				trace('CharSelect: could not play intro audio ($e)');
			}

			introSprite.animation.play('intro', true);
			introPlaying = true;
		}
		catch(e:Dynamic)
		{
			trace('CharSelect: could not load intro frames ($e)');
			onIntroFinished();
		}
	}

	function onIntroFinished():Void
	{
		if(ClientPrefs.data.flashing)
			FlxG.camera.flash(FlxColor.WHITE, FLASH_TIME);

		introPlaying = false;
		if(introSprite != null)
		{
			remove(introSprite);
			introSprite.destroy();
			introSprite = null;
		}
		if(introSound != null && introSound.exists)
		{
			// FlxG.sound owns this sound; stop, never destroy.
			introSound.stop();
			introSound = null;
		}
		startSelectorMusic();
	}

	/** Loops stayFunky.ogg directly (no intro track). */
	function startSelectorMusic():Void
	{
		var key:String = 'stayFunky/stayFunky';
		if(!openfl.utils.Assets.exists('assets/shared/music/$key.ogg')) return;

		try
		{
			selectorMusic = FlxG.sound.play(Paths.music(key), 0.8, true);
		}
		catch(e:Dynamic)
		{
			trace('CharSelect: could not play music ($e)');
		}
	}

	function stopSelectorMusic():Void
	{
		if(selectorMusic != null)
		{
			// FlxG.sound owns this sound. Destroying it here leaves a dead entry
			// in its list and the next state reset crashes in updateTransform().
			selectorMusic.stop();
			selectorMusic = null;
		}
		if(pausedMusic && FlxG.sound.music != null)
		{
			FlxG.sound.music.resume();
			pausedMusic = false;
		}
	}

	override function close():Void
	{
		stopSelectorMusic();
		super.close();
	}

	/** Static centered art: chooseDipshit, always the same. */
	function addChooseArt():Void
	{
		if(!assetExists('bg/chooseDipshit.png')) return;
		try
		{
			chooseBacking = new FlxSprite().loadGraphic(Paths.image('CharSelect/bg/chooseDipshit'));
			var scale:Float = (FlxG.height * 0.95) / chooseBacking.height;
			fitChooseArt(chooseBacking, scale);
			add(chooseBacking);
		}
		catch(e:Dynamic)
			trace('CharSelect: could not load chooseDipshit ($e)');
	}

	/** On a valid confirm, swap the static dipshit for its animated atlas. */
	function playConfirmDipshit():Void
	{
		if(chooseBacking == null || !assetExists('bg/dipshitBacking.xml')) return;
		try
		{
			chooseBacking.frames = Paths.getSparrowAtlas('CharSelect/bg/dipshitBacking');
			chooseBacking.animation.addByPrefix('idle', 'CHOOSE horizontal offset instance', 24, true);
			chooseBacking.animation.play('idle', true);
			fitChooseArt(chooseBacking, (FlxG.height * 0.95) / chooseBacking.height);
		}
		catch(e:Dynamic)
			trace('CharSelect: could not load confirm dipshit ($e)');
	}

	function fitChooseArt(spr:FlxSprite, scale:Float):Void
	{
		if(spr == null || spr.width <= 0 || spr.height <= 0) return;
		spr.setGraphicSize(Std.int(spr.width * scale), Std.int(spr.height * scale));
		spr.updateHitbox();
		spr.screenCenter();
		spr.scrollFactor.set();
	}

	function loadBackground():Void
	{
		// Layer order (back to front): base art, crowd, stage.
		if(addBgLayer('bg/charSelectBG', 'cover'))
		{
			addBgCrowd();
			addBgStage();
			return;
		}

		for(name in ['bg/bg', 'bg/background', 'bg'])
			if(addBgLayer(name, 'cover')) return;
	}

	function addBgLayer(name:String, anchor:String):Bool
	{
		if(!assetExists('$name.png')) return false;
		try
		{
			var layer:FlxSprite = new FlxSprite();
			layer.loadGraphic(anchor == 'cover' ? coverGraphic(name) : Paths.image('CharSelect/$name'));

			if(anchor == 'cover')
			{
				var ratio:Float = Math.max(FlxG.width / layer.width, FlxG.height / layer.height);
				layer.setGraphicSize(Std.int(layer.width * ratio), Std.int(layer.height * ratio));
				layer.updateHitbox();
				layer.screenCenter();
			}
			else
			{
				var ratio:Float = FlxG.width / layer.width;
				layer.setGraphicSize(FlxG.width, Std.int(layer.height * ratio));
				layer.updateHitbox();
				layer.screenCenter(X);
				layer.y = FlxG.height - layer.height;
			}

			layer.scrollFactor.set();
			if(name == 'bg/charSelectBG') bgHasArt = true;
			add(layer);
			return true;
		}
		catch(e:Dynamic)
		{
			trace('CharSelect: could not load background $name ($e)');
			return false;
		}
	}

	function coverGraphic(name:String):BitmapData
	{
		var src:BitmapData = Paths.image('CharSelect/$name').bitmap;
		var b = src.getColorBoundsRect(0xFF000000, 0x00000000, false);
		if(b.width <= 0 || b.height <= 0) return src;
		var cropped:BitmapData = new BitmapData(Std.int(b.width), Std.int(b.height), true, 0);
		cropped.copyPixels(src, b, new Point(0, 0));
		return cropped;
	}

	function addBgCrowd():Void
	{
		var path:String = 'assets/shared/images/CharSelect/bg/crowd';
		if(!openfl.utils.Assets.exists('$path/Animation.json')) return;
		try
		{
			var crowd:FlxAnimate = new FlxAnimate();
			crowd.loadAtlas(path);
			crowd.anim.play('crowd');
			crowd.scrollFactor.set();
			pinAtlas(crowd, FlxG.width / 2, FlxG.height - 200);
			bgCrowd = crowd;
			add(crowd);
		}
		catch(e:Dynamic)
			trace('CharSelect: could not load crowd atlas ($e)');
	}

	function addBgStage():Void
	{
		var path:String = 'assets/shared/images/CharSelect/bg/charSelectStage';
		if(openfl.utils.Assets.exists('$path/Animation.json'))
		{
			try
			{
				var stage:FlxAnimate = new FlxAnimate();
				stage.loadAtlas(path);
				stage.anim.play('stage full');
				stage.scrollFactor.set();
				pinAtlas(stage, FlxG.width / 2, FlxG.height + 80);
				bgStage = stage;
				add(stage);
				return;
			}
			catch(e:Dynamic)
				trace('CharSelect: could not load stage atlas ($e)');
		}
		addBgLayer('bg/charSelectStage', 'bottom');
	}

	function loadTitleArt():Void
	{
		var onLock:Bool = vocalistAt(cursor) < 0;
		var c:CharSelectCharacter = onLock ? null : charDef(selected);
		var file:String = onLock ? 'titles/placeholder' : TITLES[selected];
		var key:String = 'CharSelect/$file';
		if(c != null && c.title != null && c.title.length > 0) key = c.title;
		if(Paths.fileExists('images/$key.png', IMAGE))
		{
			try
			{
				titleArt.loadGraphic(Paths.image(key));
				titleArt.scale.set(TITLE_SCALE, TITLE_SCALE);
				titleArt.updateHitbox();
				titleArt.x = FlxG.width * TITLE_X - titleArt.width / 2;
				titleArt.y = TITLE_Y;
				titleArt.alpha = 1;
				titleArt.visible = true;
				titleText.visible = false;
				return;
			}
			catch(e:Dynamic)
				trace('CharSelect: could not load title $file ($e)');
		}
		titleArt.visible = false;
		titleText.text = onLock ? '???' : nameForPreview(selected);
		titleText.scale.set(TITLE_SCALE, TITLE_SCALE);
		titleText.x = FlxG.width * TITLE_X - titleText.width * TITLE_SCALE / 2;
		titleText.y = TITLE_Y;
		titleText.visible = true;
	}

	function pinAtlas(spr:FlxAnimate, centerX:Float, bottomY:Float):Void
	{
		if(spr.width <= 0 || spr.height <= 0) return;
		spr.x = centerX - (spr.width / 2) - spr.relativeX;
		spr.y = bottomY - spr.height - spr.relativeY;
	}

	function moveCursor(dCol:Int, dRow:Int):Void
	{
		var col:Int = (cursor % 3) + dCol;
		var row:Int = Std.int(cursor / 3) + dRow;
		if(col < 0 || col > 2 || row < 0 || row > 2)
		{
			// Moving never plays locked; only confirming a padlock does.
			playCue('change', 0.9);
			return;
		}
		cursor = row * 3 + col;
		cellChanged();
	}

	function cellChanged():Void
	{
		// One navigation cue for every cell, including padlocks.
		playCue('change', 0.9);
		var vocalist:Int = vocalistAt(cursor);
		if(vocalist >= 0) selected = vocalist;
		loadTitleArt();
		showPreview(vocalist >= 0 ? vocalist : PREVIEW_PLACEHOLDER);
		updateGridVisuals();
	}

	/** Returns the grid cell under the mouse, or -1 if none. */
	function cellAtMouse():Int
	{
		var mx:Float = FlxG.mouse.x;
		var my:Float = FlxG.mouse.y;
		var halfW:Float = FlxG.width * GAP_X / 2;
		var halfH:Float = FlxG.height * GAP_Y / 2;
		for(i in 0...cells.length)
		{
			var p = cellPosition(i);
			if(mx >= p.x - halfW && mx <= p.x + halfW && my >= p.y - halfH && my <= p.y + halfH)
				return i;
		}
		return -1;
	}

	/** Confirms one cell, shared by keyboard ACCEPT and mouse click. */
	function confirmCell(index:Int):Void
	{
		var vocalist:Int = vocalistAt(index);
		animateCell(index);
		confirmPreview(vocalist >= 0 ? vocalist : PREVIEW_PLACEHOLDER);
		if(vocalist < 0)
		{
			playCue('locked', 0.9);
			return;
		}

		confirming = true;
		playConfirmDipshit();
		playCue('confirm');
		// Hold the sound, then fade out before returning to Freeplay.
		new FlxTimer().start(CONFIRM_DELAY, function(_)
		{
			var c:CharSelectCharacter = charDef(vocalist);
			var wantPico:Bool = (c != null) ? (c.mix == 'pico') : (vocalist == 1);
			var changed:Bool = ClientPrefs.data.picoVocalMode != wantPico;
			ClientPrefs.data.picoVocalMode = wantPico;
			ClientPrefs.saveSettings();
			trace('Vocalist confirmed: ${nameForPreview(vocalist)} (changed=$changed)');
			if(changed && onConfirm != null) onConfirm();
			fadeOutThen(close);
		});
	}

	/** Plays the cell animation from frame 0. Cells start paused and only
	 *  animate when the user confirms with ENTER. */
	function animateCell(index:Int):Void
	{
		if(index < 0 || index >= cells.length) return;
		cells[index].animation.play('idle', true);
	}

	/** Fades the screen out, then runs the callback (used before close()). */
	function fadeOutThen(done:Void->Void):Void
	{
		transitioning = true;
		FlxTween.tween(transitionSprite, {alpha: 1}, FADE_TIME, {
			ease: FlxEase.quadIn,
			onComplete: function(_) done()
		});
	}

	override function update(elapsed:Float)
	{
		if(!bgHasArt && bg.alpha < 0.8)
			bg.alpha = Math.min(0.8, bg.alpha + elapsed * 2.5);
		if(bgCrowd != null)
			pinAtlas(bgCrowd, FlxG.width / 2, FlxG.height - 200);
		if(bgStage != null)
			pinAtlas(bgStage, FlxG.width / 2, FlxG.height + 80);
		titleText.alpha = Math.min(1, titleText.alpha + elapsed * 3);
		if(activePreview >= 0)
			positionPreview(activePreview);

		// Let the intro play and block selector input until it finishes.
		if(introPlaying)
		{
			super.update(elapsed);
			return;
		}

		// Block input during the fades and while the confirm cue is playing.
		if(transitioning || confirming)
		{
			super.update(elapsed);
			return;
		}

		var hovered:Int = cellAtMouse();
		if(hovered >= 0 && hovered != cursor)
		{
			cursor = hovered;
			cellChanged();
		}

		if(controls.UI_LEFT_P)
			moveCursor(-1, 0);
		else if(controls.UI_RIGHT_P)
			moveCursor(1, 0);
		else if(controls.UI_UP_P)
			moveCursor(0, -1);
		else if(controls.UI_DOWN_P)
			moveCursor(0, 1);
		else if(FlxG.keys.justPressed.TAB)
		{
			var order:Array<Int> = selectablePreviews();
			var pos:Int = order.indexOf(selected);
			selected = order[(pos + 1) % order.length];
			cursor = cellForPreview(selected);
			if(cursor < 0) cursor = BF_CELL;
			cellChanged();
		}
		else if(controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			fadeOutThen(close);
		}
		else if(FlxG.mouse.justPressed && hovered >= 0)
			confirmCell(hovered);
		else if(controls.ACCEPT)
			confirmCell(cursor);

		super.update(elapsed);
	}
}
