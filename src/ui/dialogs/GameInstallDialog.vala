using Gtk;
using GLib;
using Gee;
using GameHub.Utils;

using GameHub.Data;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;

namespace GameHub.UI.Dialogs
{
	public class GameInstallDialog: Granite.MessageDialog
	{
		public signal void install(Game.Installer installer);
		public signal void canceled();
		
		private ListBox installers_list;
		
		private bool is_finished = false;

		public GameInstallDialog(Game game, ArrayList<Game.Installer> installers)
		{
			Object(transient_for: Windows.MainWindow.instance, deletable: false, resizable: false);
			
			set_modal(true);
			
			image_icon = Icon.new_for_string("go-down");
			
			primary_text = game.name;
			
			installers_list = new ListBox();
			
			var sys_langs = Intl.get_language_names();
			
			foreach(var installer in installers)
			{
				var row = new InstallerRow(installer);
				installers_list.add(row);
				
				if(installer is GOGGame.Installer && (installer as GOGGame.Installer).lang in sys_langs)
				{
					installers_list.select_row(row);
				}
			}
			
			if(installers.size > 1)
			{
				secondary_text = _("Select game installer");
				custom_bin.child = installers_list;
			}
			
			destroy.connect(() => { if(!is_finished) canceled(); });
			
			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CANCEL:
						destroy();
						break;
						
					case ResponseType.ACCEPT:
						var installer = installers[0];
						if(installers.size > 1)
						{
							var row = installers_list.get_selected_row() as InstallerRow;
							installer = row.installer;
						}
						is_finished = true;
						install(installer);
						destroy();
						break;
				}
			});

			add_button(_("Cancel"), ResponseType.CANCEL);
			var install_btn = add_button(_("Install"), ResponseType.ACCEPT);
			install_btn.get_style_context().add_class(STYLE_CLASS_SUGGESTED_ACTION);
			install_btn.grab_default();
			
			show_all();
		}
		
		private class InstallerRow: ListBoxRow
		{
			public Game.Installer installer;
			
			public InstallerRow(Game.Installer installer)
			{
				this.installer = installer;
				
				var label = new Label(installer.name);
				label.xpad = 16;
				label.ypad = 4;
				child = label;
			}
		}
	}
}
