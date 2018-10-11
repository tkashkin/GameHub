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

namespace GameHub.UI.Views.GameDetailsView
{
	public abstract class GameDetailsBlock: Box
	{
		public Game game { get; construct; }

		public bool is_dialog { get; construct; }

		public GameDetailsBlock(Game game, bool is_dialog)
		{
			Object(game: game, orientation: Orientation.VERTICAL, is_dialog: is_dialog);
		}

		public abstract bool supports_game { get; }

		protected void add_info_label(string title, string? text, bool multiline=true, bool markup=false)
		{
			if(text == null || text == "") return;

			var title_label = new Granite.HeaderLabel(title);
			title_label.set_size_request(multiline ? -1 : 128, -1);
			title_label.valign = Align.START;

			var text_label = new Label(text);
			text_label.halign = Align.START;
			text_label.hexpand = false;
			text_label.wrap = true;
			text_label.xalign = 0;
			text_label.max_width_chars = is_dialog ? 60 : -1;
			text_label.use_markup = markup;

			if(!multiline)
			{
				text_label.get_style_context().add_class("gameinfo-singleline-value");
			}

			var box = new Box(multiline ? Orientation.VERTICAL : Orientation.HORIZONTAL, 0);
			box.margin_start = box.margin_end = 8;
			box.add(title_label);
			box.add(text_label);
			add(box);
		}
	}
}
