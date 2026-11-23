package backend;

enum CursorStyle
{
	CURSOR_DEFAULT; // Menus, options, gameplay and a held button always use this.
	POINTER; // A note/arrow is currently under the mouse in the chart editor.
	GRABBING; // A note/arrow is being moved in the chart editor.
	CROSS; // The item under the mouse is locked or blocked.
	SCROLL; // The hovered region can be scrolled.
	TEXT; // Horizontal text field.
	TEXT_VERTICAL; // Tall / vertical text field.
	ZOOM_IN; // Zooming in, in an editor.
	ZOOM_OUT; // Zooming out, in an editor.
	HOURGLASS; // A loading state is active.
}
