/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

GameHub is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GameHub is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GameHub.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gtk;
using Gdk;
using Granite;
using GameHub.Data;
using GameHub.Data.DB;
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

			var label_hbox = new Box(Orientation.HORIZONTAL, 4);

			var favorite_icon = new Image.from_icon_name("gh-game-favorite-symbolic", IconSize.BUTTON);
			var updated_icon = new Image.from_icon_name("gh-game-updated-symbolic", IconSize.BUTTON);
			favorite_icon.margin_top = updated_icon.margin_top = 2;
			favorite_icon.valign = updated_icon.valign = Align.CENTER;
			favorite_icon.pixel_size = updated_icon.pixel_size = 8;

			var label = new Label(game.name);
			label.halign = Align.START;
			label.get_style_context().add_class("category-label");

			label_hbox.add(favorite_icon);
			label_hbox.add(updated_icon);
			label_hbox.add(label);

			state_label = new Label(null);
			state_label.halign = Align.START;

			vbox.add(label_hbox);
			vbox.add(state_label);

			hbox.add(vbox);

			game.status_change.connect(s => {
				Idle.add(() => {
					label.label = game.name;
					state_label.label = s.description;
					favorite_icon.visible = game.has_tag(Tables.Tags.BUILTIN_FAVORITES);
					update_icon();
					changed();
					return Source.REMOVE;
				});
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
						new GameContextMenu(game, image).open(e, true);
						break;
				}
				return true;
			});

			show_all();

			updated_icon.visible = false;
			if(game is GameHub.Data.Sources.GOG.GOGGame)
			{
				game.notify["has-updates"].connect(() => {
					Idle.add(() => {
						updated_icon.visible = (game as GameHub.Data.Sources.GOG.GOGGame).has_updates;
						return Source.REMOVE;
					});
				});
				game.notify_property("has-updates");
			}
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
