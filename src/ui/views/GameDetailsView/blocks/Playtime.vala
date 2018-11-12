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
using Gee;
using Granite;

using GameHub.Data;
using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;

using GameHub.Utils;

using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class Playtime: GameDetailsBlock
	{
		public Playtime(Game game, bool is_dialog)
		{
			Object(game: game, orientation: Orientation.VERTICAL, is_dialog: is_dialog);
		}

		construct
		{
			if(!supports_game) return;

			var hbox = new Box(Orientation.HORIZONTAL, 0);

			var header = new Granite.HeaderLabel(_("Playtime"));

			var add_separator = false;

			if(game.playtime_tracked > 0)
			{
				add_info_label(_("Playtime (local)"), minutes_to_string(game.playtime_tracked), false, false, hbox);
				add_separator = true;
			}

			if(game.playtime_source > 0)
			{
				if(add_separator) hbox.add(new Separator(Orientation.VERTICAL));
				add_separator = true;
				add_info_label(_("Playtime"), minutes_to_string(game.playtime_source), false, false, hbox);
			}

			if(game.last_launch > 0)
			{
				var date = new GLib.DateTime.from_unix_local(game.last_launch);
				if(date != null)
				{
					if(add_separator) hbox.add(new Separator(Orientation.VERTICAL));
					add_info_label(_("Last launch"), Granite.DateTime.get_relative_datetime(date), false, false, hbox);
				}
			}

			add(new Separator(Orientation.HORIZONTAL));
			add(hbox);
		}

		private string minutes_to_string(int64 min)
		{
			int h = (int) min / 60;
			int m = (int) min - (h * 60);
			return (h > 0 ? C_("time", "%dh").printf(h) + " " : "") + C_("time", "%dm").printf(m);
		}

		public override bool supports_game { get { return game.playtime_source > 0 || game.playtime_tracked > 0 || game.last_launch > 0; } }
	}
}
