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
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Views.GamesView
{
	public class FiltersPopover: Popover
	{
		public ArrayList<Tables.Tags.Tag> selected_tags { get; private set; }
		public signal void filters_changed(ArrayList<Tables.Tags.Tag> selected_tags);

		private CheckButton tags_header_check;
		private ListBox tags_list;

		private bool is_toggling_all = false;
		private bool is_updating = false;

		public FiltersPopover(Widget? relative_to)
		{
			Object(relative_to: relative_to);
		}

		construct
		{
			selected_tags = new ArrayList<Tables.Tags.Tag>(Tables.Tags.Tag.is_equal);

			set_size_request(220, -1);

			var vbox = new Box(Orientation.VERTICAL, 0);

			tags_list = new ListBox();
			tags_list.get_style_context().add_class("tags-list");
			tags_list.selection_mode = SelectionMode.NONE;

			tags_list.set_sort_func((row1, row2) => {
				var item1 = row1 as TagRow;
				var item2 = row2 as TagRow;

				if(row1 != null && row2 != null)
				{
					var t1 = item1.tag.id;
					var t2 = item2.tag.id;

					var b1 = t1.has_prefix(Tables.Tags.Tag.BUILTIN_PREFIX);
					var b2 = t2.has_prefix(Tables.Tags.Tag.BUILTIN_PREFIX);
					if(b1 && !b2) return -1;
					if(!b1 && b2) return 1;

					var u1 = t1.has_prefix(Tables.Tags.Tag.USER_PREFIX);
					var u2 = t2.has_prefix(Tables.Tags.Tag.USER_PREFIX);
					if(u1 && !u2) return -1;
					if(!u1 && u2) return 1;

					return item1.tag.name.collate(item1.tag.name);
				}

				return 0;
			});

			var tags_scrolled = new ScrolledWindow(null, null);
			#if GTK_3_22
			tags_scrolled.propagate_natural_width = true;
			tags_scrolled.propagate_natural_height = true;
			tags_scrolled.max_content_height = 440;
			#else
			tags_scrolled.min_content_height = 320;
			#endif
			tags_scrolled.add(tags_list);
			tags_scrolled.show_all();

			var tebox = new EventBox();
			tebox.get_style_context().add_class("tags-list-header");
			tebox.above_child = true;

			var tbox = new Box(Orientation.HORIZONTAL, 8);
			tbox.margin_start = tbox.margin_end = 8;
			tbox.margin_top = tbox.margin_bottom = 6;

			tags_header_check = new CheckButton();

			var header = new HeaderLabel(_("Tags"));
			header.halign = Align.START;
			header.xalign = 0;
			header.hexpand = true;

			tbox.add(tags_header_check);
			tbox.add(header);

			tebox.add_events(EventMask.ALL_EVENTS_MASK);
			tebox.enter_notify_event.connect(e => { tebox.get_style_context().add_class("hover"); });
			tebox.leave_notify_event.connect(e => { tebox.get_style_context().remove_class("hover"); });
			tebox.button_release_event.connect(e => {
				if(e.button == 1)
				{
					tags_header_check.inconsistent = false;
					tags_header_check.active = !tags_header_check.active;

					is_toggling_all = true;
					foreach(var tag in Tables.Tags.TAGS)
					{
						tag.selected = tags_header_check.active;
					}
					is_toggling_all = false;
					update();
				}
				return true;
			});

			tebox.add(tbox);

			vbox.add(tebox);
			vbox.add(new Separator(Orientation.HORIZONTAL));
			vbox.add(tags_scrolled);

			child = vbox;

			load_tags();

			Tables.Tags.instance.tags_updated.connect(load_tags);

			vbox.show_all();
		}

		private void load_tags()
		{
			tags_list.foreach(w => w.destroy());

			foreach(var tag in Tables.Tags.TAGS)
			{
				tags_list.add(new TagRow(tag));
				tag.notify["selected"].connect(update);
			}

			tags_list.show_all();

			update();
		}

		private void update()
		{
			if(is_toggling_all || is_updating) return;
			is_updating = true;

			selected_tags.clear();

			foreach(var tag in Tables.Tags.TAGS)
			{
				if(tag.selected) selected_tags.add(tag);
				Tables.Tags.add(tag, true);
			}

			tags_header_check.inconsistent = selected_tags.size != 0 && selected_tags.size != Tables.Tags.TAGS.size;
			tags_header_check.active = selected_tags.size > 0;

			filters_changed(selected_tags);

			is_updating = false;
		}

		public class TagRow: ListBoxRow
		{
			public Tables.Tags.Tag tag;

			public TagRow(Tables.Tags.Tag tag)
			{
				this.tag = tag;

				var ebox = new EventBox();
				ebox.above_child = true;

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 6;

				var check = new CheckButton();
				check.active = tag.selected;

				var name = new Label(tag.name);
				name.halign = Align.START;
				name.xalign = 0;
				name.hexpand = true;

				var icon = new Image.from_icon_name(tag.icon, IconSize.BUTTON);

				box.add(check);
				box.add(name);
				box.add(icon);

				tag.notify["selected"].connect(() => {
					check.active = tag.selected;
				});

				ebox.add_events(EventMask.ALL_EVENTS_MASK);
				ebox.button_release_event.connect(e => {
					if(e.button == 1)
					{
						check.active = !check.active;
						tag.selected = check.active;
					}
					return true;
				});

				ebox.add(box);

				child = ebox;
			}
		}
	}
}
