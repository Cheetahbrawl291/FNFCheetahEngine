package states.editors;

import flixel.FlxG;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flash.net.FileFilter;

import backend.Paths;
import backend.CharSelectConfig;
import backend.CharSelectConfig.CharSelectCharacter;
import backend.CharSelectConfig.CharSelectConfigData;
import backend.CharSelectConfig.CharSelectMix;
import backend.CharSelectBaker;
import backend.ui.PsychUIInputText;
import states.editors.content.FileDialogHandler;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

typedef EditField =
{
	label:String,
	input:PsychUIInputText,
	kind:String
}

/**
 * In-game editor for the char-select grid. Creates custom characters and
 * sound mixes, assigns each character to a padlock cell, and bakes intro /
 * idle / confirm GIFs (or still images) into a Sparrow atlas with pure Haxe.
 * Titles and icons are copied into the active mod's images folder so the
 * selector finds them at runtime without a recompile.
 */
class CharSelectEditorState extends MusicBeatState
{
	var config:CharSelectConfigData;

	// 0 = list, 1 = character form, 2 = mix form
	var view:Int = 0;
	var curSelected:Int = 0;

	var grpItems:FlxTypedGroup<Alphabet>;
	var bannerText:FlxText;
	var infoText:FlxText;
	var helpText:FlxText;
	var statusText:FlxText;

	var fields:Array<EditField> = [];
	var labels:Array<FlxText> = [];
	var curField:Int = 0;
	var editingChar:CharSelectCharacter = null;
	var editingMix:CharSelectMix = null;

	var dialog:FileDialogHandler;
	var dialogTargetField:Int = -1;
	var menuEntries:Array<String> = [];

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		FlxG.mouse.visible = true;

		config = CharSelectConfig.load(true);

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF353535;
		add(bg);

		grpItems = new FlxTypedGroup<Alphabet>();
		add(grpItems);

		dialog = new FileDialogHandler();
		add(dialog);

		bannerText = new FlxText(0, 20, FlxG.width, '', 30);
		bannerText.setFormat(Paths.font('vcr.ttf'), 30, FlxColor.YELLOW, CENTER);
		bannerText.scrollFactor.set();
		add(bannerText);

		infoText = new FlxText(FlxG.width - 470, 130, 450, '', 18);
		infoText.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, LEFT);
		infoText.scrollFactor.set();
		add(infoText);

		statusText = new FlxText(20, FlxG.height - 100, FlxG.width - 40, '', 16);
		statusText.setFormat(Paths.font('vcr.ttf'), 16, 0xFF8CE0A0, LEFT);
		statusText.scrollFactor.set();
		add(statusText);

		helpText = new FlxText(0, FlxG.height - 70, FlxG.width, '', 16);
		helpText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER);
		helpText.scrollFactor.set();
		add(helpText);

		buildList();
		super.create();
	}

	// ------------------------------------------------------------------
	// LIST VIEW
	// ------------------------------------------------------------------

	function buildList():Void
	{
		view = 0;
		curSelected = 0;
		clearFields();
		grpItems.clear();

		menuEntries = [];
		for(c in config.characters) menuEntries.push('C|' + c.id + '|' + c.name + ' (slot ' + c.slot + ')');
		menuEntries.push('A|+ New Character');
		for(m in config.mixes) menuEntries.push('M|' + m.id + '|' + m.name);
		menuEntries.push('B|+ New Mix');

		for(i in 0...menuEntries.length)
		{
			var parts:Array<String> = menuEntries[i].split('|');
			var item:Alphabet = new Alphabet(60, 150, parts[parts.length - 1], true);
			item.isMenuItem = true;
			item.targetY = i;
			grpItems.add(item);
			item.snapToPosition();
		}

		bannerText.text = 'CHAR SELECT EDITOR';
		helpText.text = 'UP/DOWN select   ENTER edit   DEL delete   S save   BACK exit';
		refreshList();
	}

	function refreshList():Void
	{
		for(num => item in grpItems.members)
		{
			item.targetY = num - curSelected;
			item.alpha = item.targetY == 0 ? 1 : 0.55;
		}
		infoText.text = [
			'CHARACTERS: ' + config.characters.length,
			'MIXES: ' + config.mixes.length,
			'',
			'CONFIG: ' + CharSelectConfig.path(),
			'',
			'A mix is a per-character sound set.',
			'Slots 3-4 are reserved for BF/Pico.'
		].join('\n');
	}

	function entryAt(index:Int):Array<String>
	{
		if(index < 0 || index >= menuEntries.length) return null;
		return menuEntries[index].split('|');
	}

	function editEntry(index:Int):Void
	{
		var parts:Array<String> = entryAt(index);
		if(parts == null) return;

		switch(parts[0])
		{
			case 'A':
				var id:String = nextFreeId();
				var c:CharSelectCharacter = {
					id: id,
					name: id,
					slot: -1,
					title: '',
					icon: '',
					iconPrefix: id + ' icon instance',
					mix: 'bf',
					atlas: '',
					fps: 25,
					anchors: {},
					introSrc: '',
					idleSrc: '',
					confirmSrc: ''
				};
				var slot:Int = findFreeSlot(-1, c);
				if(slot < 0)
				{
					setStatus('No free padlock cell (3-4 are reserved).');
					return;
				}
				c.slot = slot;
				config.characters.push(c);
				openCharEdit(c);
			case 'B':
				var id:String = nextFreeMixId();
				var m:CharSelectMix = {id: id, name: id, sounds: {}};
				config.mixes.push(m);
				openMixEdit(m);
			case 'C':
				var c:CharSelectCharacter = charById(parts[1]);
				if(c != null) openCharEdit(c);
			case 'M':
				var m:CharSelectMix = mixById(parts[1]);
				if(m != null) openMixEdit(m);
		}
	}

	function deleteEntry(index:Int):Void
	{
		var parts:Array<String> = entryAt(index);
		if(parts == null) return;

		switch(parts[0])
		{
			case 'C':
				var c:CharSelectCharacter = charById(parts[1]);
				if(c != null)
				{
					config.characters.remove(c);
					CharSelectConfig.forget();
					buildList();
					setStatus('Removed character ' + c.id + ' (save to persist).');
				}
			case 'M':
				var m:CharSelectMix = mixById(parts[1]);
				if(m != null)
				{
					if(m.id == 'bf' || m.id == 'pico')
					{
						setStatus('The bf and pico mixes are built in and cannot be deleted.');
						return;
					}
					config.mixes.remove(m);
					for(c in config.characters)
						if(c.mix == m.id) c.mix = 'bf';
					CharSelectConfig.forget();
					buildList();
					setStatus('Removed mix ' + m.id + ' (save to persist).');
				}
			case 'A', 'B':
				setStatus('Nothing to delete here.');
		}
	}

	function charById(id:String):CharSelectCharacter
	{
		for(c in config.characters) if(c.id == id) return c;
		return null;
	}

	function mixById(id:String):CharSelectMix
	{
		for(m in config.mixes) if(m.id == id) return m;
		return null;
	}

	function nextFreeId():String
	{
		var n:Int = 1;
		while(charById('char' + n) != null) n++;
		return 'char' + n;
	}

	function nextFreeMixId():String
	{
		var n:Int = 1;
		while(mixById('mix' + n) != null) n++;
		return 'mix' + n;
	}

	// ------------------------------------------------------------------
	// EDIT VIEWS
	// ------------------------------------------------------------------

	function openCharEdit(c:CharSelectCharacter):Void
	{
		view = 1;
		editingChar = c;
		editingMix = null;
		clearFields();
		grpItems.clear();

		addField('ID', c.id, 'text');
		addField('Name', c.name, 'text');
		addField('Padlock slot (0-8)', Std.string(c.slot), 'slot');
		addField('Mix id', c.mix, 'text');
		addField('FPS', Std.string(c.fps), 'fps');
		addField('Title key', c.title, 'file');
		addField('Icon atlas key', c.icon, 'file');
		addField('Icon prefix', c.iconPrefix, 'text');
		addField('Intro (GIF/PNG)', c.introSrc, 'state');
		addField('Idle (GIF/PNG)', c.idleSrc, 'state');
		addField('Confirm (GIF/PNG)', c.confirmSrc, 'state');
		addField('Baked atlas key', c.atlas, 'text');

		bannerText.text = 'EDIT CHARACTER - ' + c.id;
		helpText.text = 'TAB focus   ESC release   when released: UP/DOWN field   F pick file   B bake   S save   BACK list';
		setStatus('Click a field or press TAB. ESC releases the field so commands work.');
		refreshFields();
	}

	function openMixEdit(m:CharSelectMix):Void
	{
		view = 2;
		editingMix = m;
		editingChar = null;
		clearFields();
		grpItems.clear();

		var s:Dynamic = m.sounds;
		addField('Mix id', m.id, 'text');
		addField('Name', m.name, 'text');
		addField('change cue key', Std.string(Reflect.field(s, 'change') == null ? '' : Reflect.field(s, 'change')), 'text');
		addField('confirm cue key', Std.string(Reflect.field(s, 'confirm') == null ? '' : Reflect.field(s, 'confirm')), 'text');
		addField('locked cue key', Std.string(Reflect.field(s, 'locked') == null ? '' : Reflect.field(s, 'locked')), 'text');

		bannerText.text = 'EDIT MIX - ' + m.id;
		helpText.text = 'TAB focus   ESC release   when released: UP/DOWN field   S save   BACK list';
		setStatus('Cue keys are Paths sound keys, e.g. CharSelect/Sounds/change. Blank uses the built-in cue.');
		refreshFields();
	}

	function addField(label:String, value:String, kind:String):Void
	{
		var y:Float = 74 + fields.length * 30;
		var lab:FlxText = new FlxText(30, y + 4, 300, label, 16);
		lab.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, LEFT);
		lab.scrollFactor.set();
		add(lab);
		labels.push(lab);

		var input:PsychUIInputText = new PsychUIInputText(340, y, 520, value == null ? '' : value, 14);
		input.maxLength = 220;
		add(input);
		fields.push({label: label, input: input, kind: kind});
	}

	function clearFields():Void
	{
		for(f in fields)
		{
			remove(f.input);
			f.input.destroy();
		}
		fields = [];
		for(l in labels)
		{
			remove(l);
			l.destroy();
		}
		labels = [];
		PsychUIInputText.focusOn = null;
	}

	function refreshFields():Void
	{
		for(i in 0...labels.length)
			labels[i].color = i == curField ? FlxColor.YELLOW : FlxColor.WHITE;
	}

	function fieldValue(index:Int):String
	{
		if(index < 0 || index >= fields.length) return '';
		return StringTools.trim(fields[index].input.text);
	}

	function applyCharFields():Bool
	{
		if(editingChar == null) return false;

		var id:String = cleanId(fieldValue(0));
		if(id.length == 0)
		{
			setStatus('ID cannot be empty.');
			return false;
		}
		if(charById(id) != null && charById(id) != editingChar)
		{
			setStatus('Another character already uses id ' + id + '.');
			return false;
		}

		var oldId:String = editingChar.id;
		editingChar.id = id;
		editingChar.name = fieldValue(1).length > 0 ? fieldValue(1) : id;

		var slot:Int = Std.parseInt(fieldValue(2));
		var freeSlot:Int = findFreeSlot(slot, editingChar);
		if(freeSlot < 0)
		{
			setStatus('No free padlock cell (3-4 are reserved).');
			return false;
		}
		editingChar.slot = freeSlot;
		fields[2].input.text = Std.string(freeSlot);

		editingChar.mix = mixById(fieldValue(3)) != null ? fieldValue(3) : 'bf';
		fields[3].input.text = editingChar.mix;

		var fps:Float = Std.parseFloat(fieldValue(4));
		if(!Math.isFinite(fps) || fps < 1 || fps > 60) fps = 25;
		editingChar.fps = fps;
		fields[4].input.text = Std.string(fps);

		editingChar.title = fieldValue(5);
		editingChar.icon = fieldValue(6);
		editingChar.iconPrefix = fieldValue(7).length > 0 ? fieldValue(7) : id + ' icon instance';
		editingChar.introSrc = fieldValue(8);
		editingChar.idleSrc = fieldValue(9);
		editingChar.confirmSrc = fieldValue(10);
		editingChar.atlas = fieldValue(11);

		if(id != oldId && editingChar.atlas.indexOf('CharSelect/char/' + oldId + '/') == 0)
		{
			editingChar.atlas = 'CharSelect/char/' + id + '/' + id;
			fields[11].input.text = editingChar.atlas;
		}
		return true;
	}

	function applyMixFields():Bool
	{
		if(editingMix == null) return false;
		var id:String = cleanId(fieldValue(0));
		if(id.length == 0)
		{
			setStatus('Mix id cannot be empty.');
			return false;
		}
		if(mixById(id) != null && mixById(id) != editingMix)
		{
			setStatus('Another mix already uses id ' + id + '.');
			return false;
		}

		var oldId:String = editingMix.id;
		editingMix.id = id;
		editingMix.name = fieldValue(1).length > 0 ? fieldValue(1) : id;
		editingMix.sounds = {
			change: fieldValue(2),
			confirm: fieldValue(3),
			locked: fieldValue(4)
		};
		if(id != oldId)
			for(c in config.characters)
				if(c.mix == oldId) c.mix = id;
		return true;
	}

	function findFreeSlot(preferred:Int, self:CharSelectCharacter):Int
	{
		var taken:Array<Int> = [];
		for(c in config.characters)
			if(c != self && c.slot >= 0) taken.push(c.slot);

		if(preferred >= 0 && preferred <= 8 && preferred != 3 && preferred != 4 && taken.indexOf(preferred) < 0)
			return preferred;
		for(i in 0...9)
			if(i != 3 && i != 4 && taken.indexOf(i) < 0) return i;
		return -1;
	}

	inline function cleanId(value:String):String
	{
		if(value == null) return '';
		var out:StringBuf = new StringBuf();
		for(i in 0...value.length)
		{
			var ch:String = value.charAt(i);
			if(~/^[a-zA-Z0-9_-]$/.match(ch)) out.add(ch);
		}
		return out.toString();
	}

	// ------------------------------------------------------------------
	// FILE PICKING / BAKING
	// ------------------------------------------------------------------

	function openFileFor(index:Int):Void
	{
		#if sys
		if(index < 0 || index >= fields.length) return;
		var kind:String = fields[index].kind;
		if(kind != 'file' && kind != 'state')
		{
			setStatus('This field is typed directly. Pick a Title/Icon/state field.');
			return;
		}
		dialogTargetField = index;
		var filter:Array<FileFilter> = kind == 'file'
			? [new FileFilter('PNG / atlas', '*.png;*.xml;*.json')]
			: [new FileFilter('GIF or PNG', '*.gif;*.png')];
		dialog.open(null, 'Select character asset', filter, onFileChosen, null, onFileError);
		#else
		setStatus('File picking requires a desktop build.');
		#end
	}

	function onFileChosen():Void
	{
		#if sys
		var path:String = dialog.path;
		var index:Int = dialogTargetField;
		dialogTargetField = -1;
		if(path == null || index < 0 || index >= fields.length) return;

		if(fields[index].kind == 'state')
		{
			fields[index].input.text = path;
			setStatus('State source set: ' + haxe.io.Path.withoutDirectory(path));
			return;
		}

		var kind:String = fields[index].label.indexOf('Title') >= 0 ? 'titles' : 'icons';
		var key:String = copyIntoMod(path, kind);
		if(key == null)
			setStatus('Could not copy ' + path);
		else
		{
			fields[index].input.text = key;
			setStatus('Copied to ' + key);
		}
		#end
	}

	function onFileError():Void
	{
		dialogTargetField = -1;
		setStatus('File dialog cancelled or failed.');
	}

	/** Copies an image plus any sibling atlas metadata into the active mod. */
	function copyIntoMod(src:String, subfolder:String):String
	{
		#if sys
		try
		{
			var p:haxe.io.Path = new haxe.io.Path(src);
			if(p.file == null || p.file.length == 0 || p.ext == null) return null;
			var mod:String = Mods.currentModDirectory;
			var root:String = (mod != null && mod.length > 0) ? 'mods/$mod' : 'mods';
			var destFolder:String = '$root/images/CharSelect/$subfolder';
			if(!FileSystem.exists(destFolder)) FileSystem.createDirectory(destFolder);

			File.copy(src, '$destFolder/${p.file}.${p.ext}');
			for(side in ['xml', 'json', 'txt'])
			{
				var sourceSibling:String = src.substr(0, src.length - p.ext.length - 1) + '.$side';
				if(FileSystem.exists(sourceSibling))
					File.copy(sourceSibling, '$destFolder/${p.file}.$side');
			}
			return 'CharSelect/$subfolder/${p.file}';
		}
		catch(e:Dynamic)
			return null;
		#else
		return null;
		#end
	}

	function bakeChar():Void
	{
		#if sys
		if(editingChar == null) return;
		if(!applyCharFields()) return;

		var sources:Array<BakeSource> = [];
		var pairs:Array<Array<String>> = [
			['intro', fieldValue(8)],
			['idle', fieldValue(9)],
			['confirm', fieldValue(10)]
		];
		for(pair in pairs)
			if(pair[1].length > 0) sources.push({state: pair[0], path: pair[1]});

		if(sources.length == 0)
		{
			setStatus('Pick at least one intro / idle / confirm source file first.');
			return;
		}

		var id:String = editingChar.id;
		var mod:String = Mods.currentModDirectory;
		var root:String = (mod != null && mod.length > 0) ? 'mods/$mod' : 'mods';
		var destFolder:String = '$root/images/CharSelect/char/$id';
		var result:BakeResult = CharSelectBaker.bake(id, sources, destFolder, editingChar.fps);

		if(result.ok)
		{
			editingChar.atlas = 'CharSelect/char/$id/$id';
			fields[11].input.text = editingChar.atlas;
			bakeAnchorsIfNeeded(destFolder, id);
		}
		setStatus(result.message + (result.ok ? ' | atlas: ' + editingChar.atlas : ''));
		#else
		setStatus('Baking requires a desktop build.');
		#end
	}

	/** The baker writes anchors next to the atlas; config keeps them too. */
	function bakeAnchorsIfNeeded(destFolder:String, id:String):Void
	{
		#if sys
		try
		{
			var anchorPath:String = '$destFolder/$id.json';
			if(FileSystem.exists(anchorPath))
				editingChar.anchors = haxe.Json.parse(File.getContent(anchorPath));
		}
		catch(e:Dynamic)
			trace('CharSelectEditor: could not read anchors ($e)');
		#end
	}

	function save():Void
	{
		if(view == 1 && !applyCharFields()) return;
		if(view == 2 && !applyMixFields()) return;

		CharSelectConfig.sanitize(config);
		var ok:Bool = CharSelectConfig.save(config);
		setStatus(ok ? 'Saved ' + CharSelectConfig.path() : 'Save failed (desktop only).');
	}

	function setStatus(msg:String):Void
	{
		if(statusText != null) statusText.text = msg;
	}

	// ------------------------------------------------------------------
	// INPUT
	// ------------------------------------------------------------------

	override function update(elapsed:Float)
	{
		var focused:Bool = PsychUIInputText.focusOn != null;

		if(FlxG.keys.justPressed.TAB && fields.length > 0)
		{
			var from:Int = curField;
			if(focused)
				for(i in 0...fields.length)
					if(fields[i].input == PsychUIInputText.focusOn)
					{
						from = i;
						break;
					}
			curField = (from + 1) % fields.length;
			PsychUIInputText.focusOn = fields[curField].input;
			refreshFields();
		}

		if(focused)
		{
			// Typing goes into the focused field; ESC is handled by the input.
			super.update(elapsed);
			return;
		}

		if(view == 0)
		{
			if(controls.UI_UP_P) changeSelection(-1);
			if(controls.UI_DOWN_P) changeSelection(1);
			if(FlxG.keys.justPressed.ENTER) editEntry(curSelected);
			if(FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE) deleteEntry(curSelected);
			if(FlxG.keys.justPressed.S) save();
			if(controls.BACK)
			{
				save();
				CharSelectConfig.forget();
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}
		else
		{
			if(controls.UI_UP_P || FlxG.keys.justPressed.PAGEUP)
			{
				curField = (curField - 1 + fields.length) % fields.length;
				refreshFields();
			}
			if(controls.UI_DOWN_P || FlxG.keys.justPressed.PAGEDOWN)
			{
				curField = (curField + 1) % fields.length;
				refreshFields();
			}
			if(FlxG.keys.justPressed.F) openFileFor(curField);
			if(view == 1 && FlxG.keys.justPressed.B) bakeChar();
			if(FlxG.keys.justPressed.S) save();
			if(controls.BACK)
			{
				if(view == 1) applyCharFields();
				if(view == 2) applyMixFields();
				buildList();
			}
		}

		super.update(elapsed);
	}

	function changeSelection(change:Int = 0):Void
	{
		if(menuEntries.length == 0) return;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, menuEntries.length - 1);
		refreshList();
	}
}
