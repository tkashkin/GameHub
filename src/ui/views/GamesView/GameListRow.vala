using Gtk;
using Gdk;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views
{
	class GameListRow: ListBoxRow
	{
		public Game game;

		public GameListRow(Game game)
		{
			this.game = game;

			var hbox = new Box(Orientation.HORIZONTAL, 8);
			hbox.margin = 4;
			var vbox = new Box(Orientation.VERTICAL, 0);

			var image = new AutoSizeImage();
			image.set_constraint(36, 36, 1);
			image.set_size_request(36, 36);

			hbox.add(image);

			var label = new Label(game.name);
			label.halign = Align.START;
			label.get_style_context().add_class("category-label");

			var state_label = new Label(null);
			state_label.halign = Align.START;

			vbox.add(label);
			vbox.add(state_label);

			hbox.add(vbox);

			child = hbox;

			game.status_change.connect(s => {
				state_label.label = s.description;
			});
			game.status_change(game.status);

			Utils.load_image.begin(image, game.icon, "icon");

			show_all();
		}
	}
}