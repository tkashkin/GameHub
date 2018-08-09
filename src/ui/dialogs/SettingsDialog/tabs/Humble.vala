using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class Humble: SettingsDialogTab
	{
		public Humble(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.get_instance();

			var humble_auth = Settings.Auth.Humble.get_instance();

			add_switch(_("Enabled"), humble_auth.enabled, v => { humble_auth.enabled = v; dialog.show_restart_message(); });

			add_separator();

			#if !FLATPAK
			add_file_chooser(_("Games directory"), FileChooserAction.SELECT_FOLDER, paths.humble_games, v => { paths.humble_games = v; dialog.show_restart_message(); });
			#endif
			add_cache_directory(_("Installers cache"), FSUtils.Paths.Humble.Installers);
		}

	}
}