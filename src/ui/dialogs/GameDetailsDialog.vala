using Gtk;
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Dialogs
{
	public class GameDetailsDialog: Dialog
	{
		public GameDetailsDialog(Game? game)
		{
			Object(transient_for: Windows.MainWindow.instance, deletable: false, resizable: false, title: game.name);

			gravity = Gdk.Gravity.CENTER;
			modal = true;

			var content = get_content_area();
			content.set_size_request(560, -1);

			content.add(new GameHub.UI.Views.GameDetailsView.GameDetailsView(game));

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CLOSE:
						destroy();
						break;
				}
			});

			get_style_context().add_class("gameinfo-background");
			var ui_settings = GameHub.Settings.UI.get_instance();
			ui_settings.notify["dark-theme"].connect(() => {
				get_style_context().remove_class("dark");
				if(ui_settings.dark_theme) get_style_context().add_class("dark");
			});
			ui_settings.notify_property("dark-theme");

			add_button(_("Close"), ResponseType.CLOSE).margin_end = 7;
			show_all();
		}
	}
}
