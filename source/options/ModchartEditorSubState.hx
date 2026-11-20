#if LUA_ALLOWED
package options;

/**
 * Settings for the external LUA Modchart Editor script.
 *
 * The script itself is downloaded by the player and is never bundled here.
 * Compatibility is opt-in and only applies when the script's own header is
 * recognized while loading a .lua file.
 */
class ModchartEditorSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Modchart Editor';
		rpcTitle = 'Modchart Editor Settings';

		var option:Option = new Option('Lua Compatibility',
			'When the external LUA Modchart Editor is detected, expose the\n'
			+ 'Psych version its compatibility branches expect. Off by default.\n'
			+ 'Other Lua scripts keep the normal engine version.',
			'modchartEditorCompat',
			BOOL);
		addOption(option);

		super();
	}
}
#end
