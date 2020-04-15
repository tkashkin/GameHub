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
using GameHub.Data.DB;

namespace GameHub.UI.Widgets
{
	public class GameTagsList: Box
	{
		private ArrayList<Game> _games;
		public ArrayList<Game> games
		{
			get { return _games; }
			set
			{
				_games = value;
				update();
			}
		}

		private ListBox list;
		private ScrolledWindow scrolled;
		private Entry new_entry;

		public GameTagsList(Game? game=null, ArrayList<Game>? games=null)
		{
			Object(orientation: Orientation.VERTICAL, spacing: 0);
			_games = games ?? new ArrayList<Game>();
			if(game != null && !(game in _games))
			{
				_games.add(game);
			}
			update();
		}

		construct
		{
			var header = Styled.H4Label(_("Tags"));
			header.xpad = 8;
			add(header);

			list = new ListBox();
			list.get_style_context().add_class("tags-list");
			list.selection_mode = SelectionMode.NONE;

			list.set_sort_func((row1, row2) => {
				var item1 = row1 as TagRow;
				var item2 = row2 as TagRow;

				if(row1 != null && row2 != null)
				{
					var tag1 = item1.tag;
					var tag2 = item2.tag;

					if(tag1 == null || tag2 == null) return 0;

					var t1 = tag1.id;
					var t2 = tag2.id;

					var b1 = t1.has_prefix(Tables.Tags.Tag.BUILTIN_PREFIX);
					var b2 = t2.has_prefix(Tables.Tags.Tag.BUILTIN_PREFIX);
					if(b1 && !b2) return -1;
					if(!b1 && b2) return 1;

					var u1 = t1.has_prefix(Tables.Tags.Tag.USER_PREFIX);
					var u2 = t2.has_prefix(Tables.Tags.Tag.USER_PREFIX);
					if(u1 && !u2) return -1;
					if(!u1 && u2) return 1;

					if(tag1.name == null || tag1.name.length == 0 || tag2.name == null || tag2.name.length == 0) return 0;
					return tag1.name.collate(tag2.name);
				}

				return 0;
			});

			scrolled = new ScrolledWindow(null, null);
			scrolled.vexpand = true;
			#if GTK_3_22
			scrolled.propagate_natural_width = true;
			scrolled.propagate_natural_height = true;
			scrolled.max_content_height = 320;
			#endif
			scrolled.add(list);

			add(scrolled);

			new_entry = new Entry();
			new_entry.placeholder_text = _("Add tag");
			new_entry.primary_icon_name = "gh-tag-add-symbolic";
			new_entry.primary_icon_activatable = false;
			new_entry.secondary_icon_name = "list-add-symbolic";
			new_entry.secondary_icon_activatable = true;
			new_entry.margin = 4;

			new_entry.icon_press.connect((icon, event) => {
				if(icon == EntryIconPosition.SECONDARY && ((EventButton) event).button == 1)
				{
					add_tag();
				}
			});
			new_entry.activate.connect(add_tag);

			add(new_entry);

			Tables.Tags.instance.tags_updated.connect(update);

			show_all();
		}

		private void update()
		{
			list.foreach(w => w.destroy());
			foreach(var tag in Tables.Tags.TAGS)
			{
				if(tag in Tables.Tags.DYNAMIC_TAGS || !tag.enabled) continue;
				list.add(new TagRow(tag, games));
			}
			list.show_all();
		}

		private void add_tag()
		{
			var name = new_entry.text.strip();
			if(name.length == 0) return;
			new_entry.text = "";
			var tag = new Tables.Tags.Tag.from_name(name);
			Tables.Tags.add(tag);
			foreach(var game in games)
			{
				game.add_tag(tag);
			}
			update();
		}
	}
}
