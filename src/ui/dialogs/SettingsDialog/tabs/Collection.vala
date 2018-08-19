using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class Collection: SettingsDialogTab
	{
		public Collection(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			add_file_chooser(_("Collection root directory"), FileChooserAction.SELECT_FOLDER, "", v => {});

			add_separator();

			add_header("GOG");
			add_entry(_("Game directory ($game_dir)"), "$root/GOG/$game", v => {}, "gog-symbolic");
			add_entry(_("Installers"), "$game_dir", v => {}, "gog-symbolic");
			add_entry(_("DLC"), "$game_dir/dlc", v => {}, "folder-download-symbolic");
			add_entry(_("Bonus content"), "$game_dir/bonus", v => {}, "folder-music-symbolic");

			add_separator();

			add_header("Humble Bundle");
			add_entry(_("Game directory ($game_dir)"), "$root/Humble Bundle/$game", v => {}, "humble-symbolic");
			add_entry(_("Installers"), "$game_dir", v => {}, "humble-symbolic");

			add_separator();

			add_header(_("Variables")).sensitive = false;
			add_labels("• $root", _("Collection root directory")).sensitive = false;
			add_labels("• $game", _("Game")).sensitive = false;
			add_labels("• $game_dir", _("Game directory")).sensitive = false;
		}

	}
}