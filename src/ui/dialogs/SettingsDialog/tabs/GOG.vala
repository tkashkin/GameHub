using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class GOG: SettingsDialogTab
	{
		public GOG(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.get_instance();

			var gog_auth = Settings.Auth.GOG.get_instance();

			add_switch(_("Enabled"), gog_auth.enabled, v => { gog_auth.enabled = v; dialog.show_restart_message(); });

			add_separator();

			#if !FLATPAK
			add_file_chooser(_("Games directory"), FileChooserAction.SELECT_FOLDER, paths.gog_games, v => { paths.gog_games = v; dialog.show_restart_message(); });
			#endif
			add_cache_directory(_("Installers cache"), FSUtils.Paths.GOG.Installers);
		}

	}
}