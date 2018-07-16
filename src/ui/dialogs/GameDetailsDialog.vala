using Gtk;
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

			set_modal(true);

			var content = get_content_area();
			content.set_size_request(560, -1);

			content.add(new GameHub.UI.Views.GameDetailsView(game));

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CLOSE:
						destroy();
						break;
				}
			});

			add_button(_("Close"), ResponseType.CLOSE).margin_end = 7;
			show_all();
		}
	}
}
