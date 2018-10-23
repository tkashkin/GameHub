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

namespace GameHub.UI.Widgets
{
	public class TagRow: ListBoxRow
	{
		public Game? game;
		public Tables.Tags.Tag tag;
		public bool toggles_tag_for_game;
		private CheckButton check;

		public TagRow(Tables.Tags.Tag tag, Game? game=null)
		{
			this.game = game;
			this.tag = tag;
			this.toggles_tag_for_game = game != null;

			can_focus = true;

			var ebox = new EventBox();
			ebox.above_child = true;

			var box = new Box(Orientation.HORIZONTAL, 8);
			box.margin_start = box.margin_end = 8;
			box.margin_top = box.margin_bottom = 6;

			check = new CheckButton();
			check.can_focus = false;

			if(toggles_tag_for_game)
			{
				check.active = game.has_tag(tag);
			}
			else
			{
				check.active = tag.selected;
				tag.notify["selected"].connect(() => {
					check.active = tag.selected;
				});
			}

			var name = new Label(tag.name);
			name.halign = Align.START;
			name.xalign = 0;
			name.hexpand = true;

			var icon = new Image.from_icon_name(tag.icon, IconSize.BUTTON);

			box.add(check);
			box.add(name);
			box.add(icon);

			ebox.add_events(EventMask.BUTTON_RELEASE_MASK);
			ebox.button_release_event.connect(e => {
				if(e.button == 1)
				{
					toggle();
				}
				return true;
			});

			add_events(EventMask.KEY_RELEASE_MASK);
			key_release_event.connect(e => {
				switch(((EventKey) e).keyval)
				{
					case Key.Return:
					case Key.space:
					case Key.KP_Space:
						toggle();
						return true;
				}
				return false;
			});

			ebox.add(box);

			child = ebox;
		}

		private void toggle()
		{
			if(toggles_tag_for_game)
			{
				game.toggle_tag(tag);
				check.active = game.has_tag(tag);
			}
			else
			{
				check.active = !check.active;
				tag.selected = check.active;
			}
		}
	}
}
