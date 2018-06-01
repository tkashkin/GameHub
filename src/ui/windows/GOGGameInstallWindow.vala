using Gtk;
using GLib;
using Gee;
using GameHub.Utils;

using GameHub.Data;
using GameHub.Data.Sources.GOG;

namespace GameHub.UI.Windows
{
	public class GOGGameInstallWindow: Window
	{
		public signal void install(GOGGame.Installer installer);
		public signal void canceled();
		
		private ListBox languages_list;
		
		private bool is_finished = false;

		public GOGGameInstallWindow(GOGGame game, ArrayList<GOGGame.Installer> installers)
		{
			title = _("Install %s").printf(game.name);
			var titlebar = new HeaderBar();
			titlebar.title = title;
			titlebar.show_close_button = true;
			titlebar.has_subtitle = false;
			set_titlebar(titlebar);
			
			set_modal(true);
			
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
			
			add(languages_list);
			
			var install_btn = new Button.with_label(_("Install"));
			
			install_btn.clicked.connect(() => {
				var row = languages_list.get_selected_row() as LangRow;
				
				is_finished = true;
				install(row.installer);
				destroy();
			});
			
			titlebar.pack_end(install_btn);
			
			destroy.connect(() => { if(!is_finished) canceled(); });
			
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
				label.ypad = 8;
				child = label;
			}
		}
	}
}
