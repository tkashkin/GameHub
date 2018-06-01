using Gtk;
using Granite;
using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Views
{
	public class WelcomeView: BaseView
	{	
		private Granite.Widgets.Welcome welcome;
		
		private Button skip_btn;
		
		private bool is_updating = false;
		
		construct
		{
			welcome = new Granite.Widgets.Welcome(_("All your games in one place"), _("Let's get started"));
			
			welcome.activated.connect(index => {
				on_entry_clicked.begin(index);
			});
			
			add(welcome);
			
			skip_btn = new Button.with_label(_("Skip"));
			skip_btn.clicked.connect(open_games_grid);
			skip_btn.set_sensitive(false);
			
			titlebar.pack_end(skip_btn);
			
			foreach(var src in GameSources)
			{
				var image = FSUtils.get_icon(src.icon);
				welcome.append_with_pixbuf(image, src.name, "");
			}
			
			update_entries.begin();
		}
		
		public override void on_window_focus()
		{
			update_entries.begin();
		}
		
		private void open_games_grid()
		{
			window.add_view(new GamesGridView());
		}
		
		private async void update_entries()
		{
			if(is_updating) return;
			is_updating = true;
			
			skip_btn.set_sensitive(false);
			var all_authenticated = true;
			
			for(int index = 0; index < GameSources.length; index++)
			{
				var src = GameSources[index];
				
				var btn = welcome.get_button_from_index(index);
				
				if(src.is_installed(true))
				{
					btn.title = src.name;
					
					if(src.is_authenticated())
					{
						btn.description = _("Ready");
						welcome.set_item_sensitivity(index, false);
						skip_btn.set_sensitive(true);
					}
					else
					{
						btn.description = _("Authentication required") + src.auth_description;
						all_authenticated = false;
						if(src.can_authenticate_automatically())
						{
							btn.description = _("Authenticating...");
							welcome.set_item_sensitivity(index, false);
							yield src.authenticate();
							is_updating = false;
							update_entries.begin();
							return;
						}
					}
				}
				else
				{
					btn.title = _("Install %s").printf(src.name);
					btn.description = _("Return to GameHub after installing");
					all_authenticated = false;
				}
			}
			
			if(all_authenticated)
			{
				open_games_grid();
			}
			
			welcome.show_all();
			
			is_updating = false;
		}
		
		private async void on_entry_clicked(int index)
		{
			welcome.set_item_sensitivity(index, false);
			
			GameSource src = GameSources[index];
			var installed = src.is_installed();
			
			if(installed)
			{
				if(!src.is_authenticated())
				{
					if(!(yield src.authenticate()))
					{
						welcome.set_item_sensitivity(index, true);
						return;
					}
				}
				yield update_entries();
			}
			else
			{
				yield src.install();
				welcome.set_item_sensitivity(index, true);
			}
		}
	}
}
