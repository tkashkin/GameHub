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
using GameHub.Data.Adapters;
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView.List
{
	public class GamesList: ListBox
	{
		public signal void game_selected(Game? game);
		public signal void multiple_games_selected(ArrayList<Game> games);

		private GamesAdapter? adapter = null;
		public ScrolledWindow scrolled;

		public GamesList()
		{
			Object(selection_mode: SelectionMode.MULTIPLE);
		}

		construct
		{
			selected_rows_changed.connect(() => {
				var rows = get_selected_rows();
				if(rows.length() == 1)
				{
					game_selected(((GameListRow) rows.data).game);
				}
				else if(rows.length() > 1)
				{
					var selected = new ArrayList<Game>();
					foreach(var row in rows)
					{
						var game = ((GameListRow) row).game;
						if(game != null) selected.add(game);
					}
					multiple_games_selected(selected);
				}
			});
		}

		public void attach(GamesAdapter adapter)
		{
			this.adapter = adapter;
			adapter.attach_list(this);
		}

		public void select(int index, bool grab_focus=false)
		{
			unselect_all();
			var row = get_row_at_index(index);
			if(row != null)
			{
				select_row(row);
				if(grab_focus) row.grab_focus();
			}
		}

		private void update_scroll()
		{
			var scroll = scrolled.vadjustment.value;
			var height = scrolled.vadjustment.page_size;

			var viewport_top = scroll;
			var viewport_bottom = scroll + height;

			this.foreach(w => {
				var row = (GameListRow) w;

				if(!row.visible) return;

				Allocation alloc;
				row.get_allocation(out alloc);

				if(alloc.x < 0 || alloc.y < 0 || alloc.width < 1 || alloc.height < 1) return;

				var row_top = alloc.y;
				var row_bottom = alloc.y + alloc.height;

				var is_before_viewport = row_bottom < viewport_top;
				var is_after_viewport = row_top > viewport_bottom;

				row.icon_is_visible = !is_before_viewport && !is_after_viewport;
			});
		}

		public ScrolledWindow wrapped()
		{
			scrolled = new ScrolledWindow(null, null);
			scrolled.hscrollbar_policy = PolicyType.NEVER;
			scrolled.set_size_request(220, -1);
			scrolled.add(this);
			scrolled.vadjustment.value_changed.connect(update_scroll);
			scrolled.size_allocate.connect(update_scroll);
			scrolled.show_all();
			show_all();
			return scrolled;
		}
	}
}
