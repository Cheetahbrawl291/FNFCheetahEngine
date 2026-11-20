#if LUA_ALLOWED
package options;

/**
 * Settings for the bundled LUA Modchart Editor script.
 *
 * Compatibility is on by default and only applies when a .lua file's own
 * header identifies it as the editor. Disable it to restore the engine
 * version for every Lua script.
 */
class ModchartEditorSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Modchart Editor';
		rpcTitle = 'Modchart Editor Settings';

		var option:Option = new Option('Lua Compatibility',
			'When the LUA Modchart Editor is detected, expose the\n'
			+ 'Psych version its compatibility branches expect. On by default.\n'
			+ 'Turn off to restore the engine version for all Lua scripts.',
			'modchartEditorCompat',
			BOOL);
		addOption(option);

		super();
	}
}
#end
