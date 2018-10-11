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
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Dialogs
{
	public class GameDetailsDialog: Dialog
	{
		public Game? game { get; construct; }

		public GameDetailsDialog(Game? game)
		{
			Object(transient_for: Windows.MainWindow.instance, resizable: false, title: game.name, game: game);
		}

		construct
		{
			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			gravity = Gdk.Gravity.CENTER;

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

			show_all();
		}
	}
}
