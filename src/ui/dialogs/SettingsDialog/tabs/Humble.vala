using Gtk;
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class Humble: SettingsDialogTab
	{
		private Settings.Auth.Humble humble_auth;
		private Box enabled_box;

		public Humble(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.get_instance();

			humble_auth = Settings.Auth.Humble.get_instance();

			enabled_box = add_switch(_("Enabled"), humble_auth.enabled, v => { humble_auth.enabled = v; update(); dialog.show_restart_message(); });

			add_separator();

			#if !FLATPAK
			add_file_chooser(_("Games directory"), FileChooserAction.SELECT_FOLDER, paths.humble_games, v => { paths.humble_games = v; dialog.show_restart_message(); });
			#endif
			add_cache_directory(_("Installers cache"), FSUtils.Paths.Humble.Installers);

			update();
		}

		private void update()
		{
			this.foreach(w => {
				if(w != enabled_box) w.sensitive = humble_auth.enabled;
			});
		}

	}
}