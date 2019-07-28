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
using Gdk;
using Gee;

using GameHub.Data;
using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;

using GameHub.Utils;

using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GameDetailsView.Blocks
{
	public class Playtime: GameDetailsBlock
	{
		public Playtime(Game game)
		{
			Object(game: game, orientation: Orientation.VERTICAL, text_max_width: 48);
		}

		construct
		{
			if(!supports_game) return;

			get_style_context().add_class("gameinfo-sidebar-block");

			var header = Styled.H4Label(_("Playtime"));

			var add_separator = false;

			if(game.playtime_tracked > 0)
			{
				add_info_label(_("Playtime (local)"), minutes_to_string(game.playtime_tracked), false, false);
				add_separator = true;
			}

			if(game.playtime_source > 0)
			{
				if(add_separator) add(new Separator(Orientation.HORIZONTAL));
				add_separator = true;
				add_info_label(_("Playtime"), minutes_to_string(game.playtime_source), false, false);
			}

			if(game.last_launch > 0)
			{
				var date = new GLib.DateTime.from_unix_local(game.last_launch);
				if(date != null)
				{
					if(add_separator) add(new Separator(Orientation.HORIZONTAL));
					add_info_label(_("Last launch"), Utils.get_relative_datetime(date), false, false);
				}
			}

			show_all();
			if(parent != null) parent.queue_draw();
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
