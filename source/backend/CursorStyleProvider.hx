package backend;

/**
 * A state can implement this to describe its own cursor each frame. The method
 * is called from Main's postUpdate signal, after the state's update, so it can
 * read freshly-updated internal flags. Returning null falls back to the
 * generic mapping in CursorManager.
 */
interface CursorStyleProvider
{
	function provideCursorStyle():Null<CursorStyle>;
}
