using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class UI: SettingsDialogTab
	{
		public UI(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			var ui = Settings.UI.get_instance();

			add_switch(_("Use dark theme"), ui.dark_theme, v => { ui.dark_theme = v; });
			add_switch(_("Compact list"), ui.compact_list, v => { ui.compact_list = v; });

			add_separator();

			add_switch(_("Merge games from different sources"), ui.merge_games, v => { ui.merge_games = v; dialog.show_restart_message(); });
		}

	}
}