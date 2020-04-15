/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin

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

using GameHub.Data;
using GameHub.Data.Runnables;

using GameHub.UI.Widgets;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.GamePropertiesDialog
{
	public class GamePropertiesDialog: Dialog
	{
		public Game game { get; construct; }

		private HeaderBar headerbar;

		public GamePropertiesDialog(Game game)
		{
			Object(resizable: false, use_header_bar: 1, title: game.name, game: game);
		}

		construct
		{
			set_size_request(700, 500);

			headerbar = (HeaderBar) get_header_bar();
			headerbar.has_subtitle = true;
			headerbar.show_close_button = true;
			headerbar.subtitle = _("Properties");

			var icon = new AutoSizeImage();
			icon.valign = Align.CENTER;
			icon.set_constraint(36, 36);
			icon.load(game.icon, null, @"games/$(game.source.id)/$(game.id)/icons/");
			game.notify["icon"].connect(() => {
				Idle.add(() => {
					icon.load(game.icon, null, @"games/$(game.source.id)/$(game.id)/icons/");
					return Source.REMOVE;
				});
			});
			headerbar.pack_start(icon);
		}
	}
}
