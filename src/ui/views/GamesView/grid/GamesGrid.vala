/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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
using GameHub.Data.Runnables;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView.Grid
{
	public class GamesGrid: FlowBox
	{
		public signal void game_selected(Game? game);

		private GamesAdapter? adapter = null;
		public ScrolledWindow scrolled;

		public GamesGrid()
		{
			Object(selection_mode: SelectionMode.SINGLE);
		}

		construct
		{
			get_style_context().add_class("games-grid");
			margin = 4;
			activate_on_single_click = false;
			homogeneous = true;
			min_children_per_line = 2;
			max_children_per_line = 32;
			selection_mode = SelectionMode.BROWSE;
			valign = Align.START;
		}

		public void attach(GamesAdapter adapter)
		{
			this.adapter = adapter;
			adapter.attach_grid(this);
		}

		public void select(int index, bool grab_focus=false)
		{
			var card = get_child_at_index(index);
			if(card != null)
			{
				select_child(card);
				if(grab_focus) card.grab_focus();
			}
		}

		private void update_scroll()
		{
			var scroll = scrolled.vadjustment.value;
			var height = scrolled.vadjustment.page_size;

			var viewport_top = scroll;
			var viewport_bottom = scroll + height;

			this.foreach(w => {
				var card = (GameCard) w;

				if(!card.visible) return;

				Allocation alloc;
				card.get_allocation(out alloc);

				if(alloc.x < 0 || alloc.y < 0 || alloc.width < 1 || alloc.height < 1) return;

				var card_top = alloc.y;
				var card_bottom = alloc.y + alloc.height;

				var is_before_viewport = card_bottom < viewport_top;
				var is_after_viewport = card_top > viewport_bottom;

				card.image_is_visible = !is_before_viewport && !is_after_viewport;
			});
		}

		public ScrolledWindow wrapped()
		{
			scrolled = new ScrolledWindow(null, null);
			scrolled.expand = true;
			scrolled.hscrollbar_policy = PolicyType.NEVER;
			scrolled.add(this);
			setup_scroll_events();
			scrolled.show_all();
			show_all();
			return scrolled;
		}

		private void setup_scroll_events()
		{
			var limiter = new SignalRateLimiter(100);
			scrolled.vadjustment.value_changed.connect(() => limiter.update());
			scrolled.size_allocate.connect(() => limiter.update());
			limiter.signaled.connect(update_scroll);
		}
	}
}
