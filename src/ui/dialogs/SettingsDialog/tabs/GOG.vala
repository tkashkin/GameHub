using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class GOG: SettingsDialogTab
	{
		private Settings.Auth.GOG gog_auth;
		private Box enabled_box;

		public GOG(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.get_instance();

			gog_auth = Settings.Auth.GOG.get_instance();

			enabled_box = add_switch(_("Enabled"), gog_auth.enabled, v => { gog_auth.enabled = v; update(); dialog.show_restart_message(); });

			add_separator();

			#if !FLATPAK
			add_file_chooser(_("Games directory"), FileChooserAction.SELECT_FOLDER, paths.gog_games, v => { paths.gog_games = v; dialog.show_restart_message(); });
			#endif
			add_cache_directory(_("Installers cache"), FSUtils.Paths.GOG.Installers);

			update();
		}

		private void update()
		{
			this.foreach(w => {
				if(w != enabled_box) w.sensitive = gog_auth.enabled;
			});
		}

	}
}