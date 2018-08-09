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

			add_switch(_("Use dark theme"), ui.dark_theme, e => { ui.dark_theme = e; });
			add_switch(_("Compact list"), ui.compact_list, e => { ui.compact_list = e; });
		}

	}
}