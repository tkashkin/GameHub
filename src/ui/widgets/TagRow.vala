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
using GameHub.Data.DB;
using GameHub.Data.Runnables;

namespace GameHub.UI.Widgets
{
	public class TagRow: ListBoxRow
	{
		public ArrayList<Game>? games;
		public Tables.Tags.Tag tag;
		public bool toggles_tag_for_games;
		private CheckButton check;

		public TagRow(Tables.Tags.Tag tag, ArrayList<Game>? games=null)
		{
			this.games = games;
			this.tag = tag;
			this.toggles_tag_for_games = games != null;

			can_focus = true;

			var ebox = new EventBox();
			ebox.above_child = true;

			var box = new Box(Orientation.HORIZONTAL, 8);
			box.margin_start = box.margin_end = 8;
			box.margin_top = box.margin_bottom = 6;

			check = new CheckButton();
			check.can_focus = false;

			if(toggles_tag_for_games)
			{
				var have_tag = 0;
				foreach(var game in games)
				{
					if(game.has_tag(tag)) have_tag++;
				}
				check.active = have_tag > 0;
				check.inconsistent = have_tag != 0 && have_tag != games.size;
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

			ebox.add_events(EventMask.BUTTON_PRESS_MASK);
			ebox.button_press_event.connect(e => {
				switch(e.button)
				{
					case 1:
						toggle();
						break;

					case 3:
						show_context_menu(e, true);
						break;
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
			if(toggles_tag_for_games)
			{
				check.active = !check.active;
				check.inconsistent = false;

				foreach(var game in games)
				{
					if(check.active && !game.has_tag(tag))
					{
						game.add_tag(tag);
					}
					else if(!check.active && game.has_tag(tag))
					{
						game.remove_tag(tag);
					}
				}
			}
			else
			{
				check.active = !check.active;
				tag.selected = check.active;
			}
		}

		private void show_context_menu(Event e, bool at_pointer=true)
		{
			var menu = new Gtk.Menu();

			var remove = new Gtk.MenuItem.with_label(_("Remove"));
			remove.sensitive = tag.removable;
			remove.activate.connect(() => tag.remove());

			menu.add(remove);

			menu.show_all();

			if(at_pointer)
			{
				menu.popup_at_pointer(e);
			}
			else
			{
				menu.popup_at_widget(this, Gravity.SOUTH, Gravity.NORTH, e);
			}
		}
	}
}
