package options;

#if desktop
import backend.MenuReset;
import states.editors.content.Prompt;
#end
import backend.Mods;

/**
 * Engine-specific conveniences that do not belong in the generic Psych menus:
 * restoring the stock main menu, a master switch for Windows API chart events,
 * and the erect-mix/Freeplay unification toggle.
 */
class CheetahOptionsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('cheetah_options_menu', 'Cheetah Engine Options');
		rpcTitle = 'Cheetah Engine Options';

		// Destructive action, so it confirms before touching any file.
		#if desktop
		var resetOption:Option = new Option('Reset Custom Main Menu',
			'Delete the saved mainmenu.json and menu_custom.json files\nfor this mod and for the global mods folder. The stock menu returns.',
			'cheetahResetMainMenu',
			BOOL);
		resetOption.onChange = confirmResetMainMenu;
		addOption(resetOption);
		#end

		var winOption:Option = new Option('Windows API Events',
			'Master switch for chart events that use the Windows API.\nOff refuses every Windows API event, including cosmetic ones.\nDesktop cleanup on exit still runs.',
			'winApiEvents',
			BOOL);
		#if !windows
		winOption.description += '\nThis build has no Windows API support.';
		#end
		addOption(winOption);

		var erectOption:Option = new Option('Erect Mix Unification',
			'Merge erect remixes into their base songs in Freeplay\nas Erect/Nightmare difficulties. Off shows them as\nordinary standalone songs instead.',
			'erectMixUnification',
			BOOL);
		addOption(erectOption);

		super();
	}

	#if desktop
	function confirmResetMainMenu():Void
	{
		// The option is a momentary action: restore its checkbox immediately.
		Reflect.setProperty(ClientPrefs.data, 'cheetahResetMainMenu', false);
		reloadCheckboxes();

		openSubState(new Prompt(
			Language.getPhrase('cheetah_reset_menu_confirm', 'Reset the custom main menu?\nSaved menu layouts for this mod and the global mods folder will be deleted.'),
			performResetMainMenu,
			null,
			'Reset',
			'Cancel'));
	}

	function performResetMainMenu():Void
	{
		var removed:Int = MenuReset.reset(Mods.currentModDirectory);
		var globalRemoved:Int = Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0
			? MenuReset.reset()
			: 0;
		trace('Cheetah Options: removed ${removed + globalRemoved} custom main menu config file(s)');
	}
	#end
}
