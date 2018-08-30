using Gtk;
using Gdk;
using Granite;
using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView
{
	class GameListRow: ListBoxRow
	{
		public Game game;

		public signal void update_tags();

		private AutoSizeImage image;
		private Label state_label;

		private string old_icon;

		private GameHub.Settings.UI ui_settings;

		public GameListRow(Game game)
		{
			this.game = game;

			var hbox = new Box(Orientation.HORIZONTAL, 8);
			hbox.margin = 4;
			var vbox = new Box(Orientation.VERTICAL, 0);
			vbox.valign = Align.CENTER;

			image = new AutoSizeImage();

			hbox.add(image);

			var label = new Label(game.name);
			label.halign = Align.START;
			label.get_style_context().add_class("category-label");

			state_label = new Label(null);
			state_label.halign = Align.START;

			vbox.add(label);
			vbox.add(state_label);

			hbox.add(vbox);

			game.status_change.connect(s => {
				label.label = (game.has_tag(GamesDB.Tables.Tags.BUILTIN_FAVORITES) ? "★ " : "") + game.name;
				state_label.label = s.description;
				update_icon();
				changed();
			});
			game.status_change(game.status);

			notify["is-selected"].connect(update_icon);

			ui_settings = GameHub.Settings.UI.get_instance();
			ui_settings.notify["compact-list"].connect(update);

			var ebox = new EventBox();
			ebox.add(hbox);

			child = ebox;

			ebox.add_events(EventMask.ALL_EVENTS_MASK);
			ebox.button_release_event.connect(e => {
				switch(e.button)
				{
					case 1:
						activate();
						break;

					case 3:
						new GameContextMenu(game).open(this, e);
						break;
				}
				return true;
			});

			show_all();
		}

		public override void show_all()
		{
			base.show_all();
			update();
		}

		public void update()
		{
			var compact = ui_settings.compact_list;
			var image_size = compact ? 16 : 36;
			image.set_constraint(image_size, image_size, 1);
			image.set_size_request(image_size, image_size);
			state_label.visible = !compact;
		}

		private void update_icon()
		{
			image.queue_draw();
			if(game.icon == old_icon) return;
			old_icon = game.icon;
			Utils.load_image.begin(image, game.icon, "icon");
		}
	}
}