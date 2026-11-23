package backend;

import flixel.FlxG;
import flixel.graphics.FlxGraphic;
import backend.ui.PsychUIInputText;

/**
 * State-driven cursor replacement for the stock Psych Engine pointer.
 *
 * The engine hides the mouse in dozens of unrelated places, so the manager is
 * driven from Main's postUpdate signal: it restores visibility and swaps the
 * cursor only when the resolved style changes. All cursors come from
 * assets/shared/images/cursor.
 */
class CursorManager
{
	static var cache:Map<CursorStyle, FlxGraphic> = new Map();
	static var failed:Map<CursorStyle, Bool> = new Map();
	static var current:CursorStyle = null;

	// Short-lived context pulses written by states/widgets during their update.
	static var zoomPulseDir:Int = 0; // 1 = in, -1 = out
	static var zoomPulseFrames:Int = 0;
	static var scrollPulseFrames:Int = 0;
	static var blockedPulseFrames:Int = 0;
	static var lastCameraZoom:Float = -1;

	public static function update():Void
	{
		FlxG.mouse.visible = true;

		// Editors zoom FlxG.camera; detect it generically so every editor is
		// covered without touching each one. ChartingState also pulses its
		// own grid zoom explicitly.
		var state = FlxG.state;
		var stateName:String = state == null ? '' : Type.getClassName(Type.getClass(state));
		if(stateName.indexOf('states.editors.') >= 0)
		{
			var camZoom:Float = FlxG.camera.zoom;
			if(lastCameraZoom >= 0 && Math.abs(camZoom - lastCameraZoom) > 0.0001)
				pulseZoom(camZoom > lastCameraZoom);
			lastCameraZoom = camZoom;
		}
		else lastCameraZoom = -1;

		if(zoomPulseFrames > 0) zoomPulseFrames--;
		if(scrollPulseFrames > 0) scrollPulseFrames--;
		if(blockedPulseFrames > 0) blockedPulseFrames--;

		var style:CursorStyle = decide();
		if(style != current && !failed.exists(style)) apply(style);
	}

	/** Show the zoom-in or zoom-out cursor for a few frames after a zoom action. */
	public static function pulseZoom(zoomIn:Bool):Void
	{
		zoomPulseDir = zoomIn ? 1 : -1;
		zoomPulseFrames = 12;
	}

	/** Keep the scroll cursor while the pointer is over a scrollable widget. */
	public static function markScrollable():Void
	{
		scrollPulseFrames = 2;
	}

	/** Called by UI objects whose hovered item is locked or disabled. */
	public static function setBlockedHover(value:Bool):Void
	{
		if(value) blockedPulseFrames = 2;
	}

	/** Highest-priority wins. Order here is the exact user-requested mapping. */
	static function decide():CursorStyle
	{
		var state = FlxG.state;
		var name:String = state == null ? '' : Type.getClassName(Type.getClass(state));

		// Loading state keeps its dedicated cursor.
		if(name.indexOf('LoadingState') >= 0) return HOURGLASS;

		// Zoom pulse outranks the editor's per-frame answer.
		if(zoomPulseFrames > 0) return zoomPulseDir > 0 ? ZOOM_IN : ZOOM_OUT;

		// Locked / blocked item under the mouse.
		if(blockedPulseFrames > 0) return CROSS;

		// Text fields. Tall fields use the vertical I-beam.
		var input = PsychUIInputText.focusOn;
		if(input != null)
		{
			if(input.behindText != null && input.behindText.height > input.behindText.width * 1.5)
				return TEXT_VERTICAL;
			return TEXT;
		}

		// Scrollable region: active wheel or a widget reporting hover.
		if(FlxG.mouse.wheel != 0 || scrollPulseFrames > 0) return SCROLL;

		// Editor-specific fine mapping (note placement, hover, dragged note,
		// locked column). Implemented by ChartingState.
		if(state != null && Std.isOfType(state, CursorStyleProvider))
		{
			var provided:Null<CursorStyle> = cast(state, CursorStyleProvider).provideCursorStyle();
			if(provided != null) return provided;
		}

		// Remaining editors use the pointer.
		if(name.indexOf('states.editors.') >= 0) return POINTER;

		// Menus, options, gameplay and a held mouse button all use the default.
		return CURSOR_DEFAULT;
	}

	static function apply(style:CursorStyle):Void
	{
		var cfg = config(style);
		var graphic:FlxGraphic = cache.get(style);
		if(graphic == null)
		{
			// GPU-cached bitmaps have their CPU image disposed; FlxMouse needs
			// those pixels to draw the cursor, so keep this one on the CPU.
			graphic = Paths.image(cfg.file, null, false);
			if(graphic == null)
			{
				failed.set(style, true);
				return;
			}
			cache.set(style, graphic);
		}

		FlxG.mouse.load(graphic.bitmap, cfg.scale, cfg.x, cfg.y);
		current = style;
	}

	static function config(style:CursorStyle):{file:String, scale:Float, x:Int, y:Int}
	{
		// Offsets are relative to the mouse position (FlxMouse puts the bitmap
		// at cursorContainer.x + XOffset). Negative offsets center the visual
		// hotspot on the real pointer; arrow styles align their tip instead.
		return switch(style)
		{
			case CURSOR_DEFAULT: {file: 'cursor/cursor-default', scale: 1, x: -1, y: 0};
			case POINTER: {file: 'cursor/cursor-pointer', scale: 1, x: -7, y: 0};
			case GRABBING: {file: 'cursor/cursor-grabbing', scale: 1, x: -16, y: -19};
			case CROSS: {file: 'cursor/cursor-cross', scale: 0.25, x: -19, y: -19};
			case SCROLL: {file: 'cursor/cursor-scroll', scale: 0.25, x: -19, y: -19};
			case TEXT: {file: 'cursor/cursor-text', scale: 0.4, x: -18, y: -28};
			case TEXT_VERTICAL: {file: 'cursor/cursor-text-vertical', scale: 0.4, x: -28, y: -17};
			case ZOOM_IN: {file: 'cursor/cursor-zoom-in', scale: 0.25, x: -15, y: -16};
			case ZOOM_OUT: {file: 'cursor/cursor-zoom-out', scale: 0.25, x: -15, y: -16};
			case HOURGLASS: {file: 'cursor/cursor-hourglass', scale: 0.25, x: -16, y: -18};
		};
	}
}
