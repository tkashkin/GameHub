using Gtk;
using GLib;
using Gee;
using GameHub.Utils;

using GameHub.Data;
using GameHub.Data.Sources.GOG;

namespace GameHub.UI.Dialogs
{
	public class GOGGameInstallDialog: Granite.MessageDialog
	{
		public signal void install(GOGGame.Installer installer);
		public signal void canceled();
		
		private ListBox languages_list;
		
		private bool is_finished = false;

		public GOGGameInstallDialog(GOGGame game, ArrayList<GOGGame.Installer> installers)
		{
			Object(transient_for: Windows.MainWindow.instance, deletable: false, resizable: false);
			
			set_modal(true);
			
			image_icon = Icon.new_for_string("go-down");
			
			primary_text = game.name;
			
			languages_list = new ListBox();
			
			var sys_langs = Intl.get_language_names();
			
			foreach(var installer in installers)
			{
				var row = new LangRow(installer);
				languages_list.add(row);
				
				if(installer.lang in sys_langs)
				{
					languages_list.select_row(row);
				}
			}
			
			if(installers.size > 1)
			{
				secondary_text = _("Select game language");
				custom_bin.child = languages_list;
			}
			
			destroy.connect(() => { if(!is_finished) canceled(); });
			
			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CANCEL:
						destroy();
						break;
						
					case ResponseType.ACCEPT:
						var row = languages_list.get_selected_row() as LangRow;
						is_finished = true;
						install(row.installer);
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
		
		private class LangRow: ListBoxRow
		{
			public GOGGame.Installer installer;
			
			public LangRow(GOGGame.Installer installer)
			{
				this.installer = installer;
				
				var label = new Label(installer.lang_full);
				label.xpad = 16;
				label.ypad = 4;
				child = label;
			}
		}
	}
}
