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
using GameHub.Settings;

namespace GameHub.UI.Views.GamesView
{
	public class FiltersPopover: Popover
	{
		public ArrayList<Tables.Tags.Tag> selected_tags { get; private set; }
		public signal void filters_changed(ArrayList<Tables.Tags.Tag> selected_tags);

		public SortMode sort_mode { get; private set; default = SortMode.NAME; }
		public signal void sort_mode_changed(SortMode sort_mode);

		private Granite.Widgets.ModeButton sort_mode_button;

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

			var sort_hbox = new Box(Orientation.HORIZONTAL, 6);
			sort_hbox.margin_start = sort_hbox.margin_end = 8;
			sort_hbox.margin_top = 4;
			sort_hbox.margin_bottom = 2;

			var sort_image = new Image.from_icon_name("view-sort-descending-symbolic", IconSize.BUTTON);
			sort_hbox.add(sort_image);

			var sort_label = new HeaderLabel(_("Sort:"));
			sort_label.margin_end = 8;
			sort_label.xpad = 0;
			sort_label.halign = Align.START;
			sort_label.xalign = 0;
			sort_label.hexpand = true;
			sort_hbox.add(sort_label);

			sort_mode_button = new Granite.Widgets.ModeButton();
			sort_mode_button.get_style_context().add_class("filters-sort-mode");
			sort_mode_button.halign = Align.END;
			sort_mode_button.valign = Align.CENTER;
			sort_mode_button.can_focus = true;
			add_sort_mode(SortMode.NAME);
			add_sort_mode(SortMode.LAST_LAUNCH);
			add_sort_mode(SortMode.PLAYTIME);
			sort_hbox.add(sort_mode_button);

			var saved_state = Settings.SavedState.get_instance();

			sort_mode_button.set_active((int) saved_state.sort_mode);
			sort_mode = saved_state.sort_mode;
			sort_mode_button.mode_changed.connect(() => {
				saved_state.sort_mode = (SortMode) sort_mode_button.selected;
				sort_mode = saved_state.sort_mode;
				sort_mode_changed(sort_mode);
			});

			vbox.add(sort_hbox);

			vbox.add(new Separator(Orientation.HORIZONTAL));

			tags_list = new ListBox();
			tags_list.get_style_context().add_class("tags-list");
			tags_list.get_style_context().add_class("not-rounded");
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
			tebox.can_focus = true;

			var tbox = new Box(Orientation.HORIZONTAL, 8);
			tbox.margin_start = tbox.margin_end = 8;
			tbox.margin_top = tbox.margin_bottom = 6;

			tags_header_check = new CheckButton();
			tags_header_check.can_focus = false;

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
					toggle_all_tags();
				}
				return true;
			});
			tebox.key_release_event.connect(e => {
				switch(((EventKey) e).keyval)
				{
					case Key.Return:
					case Key.space:
					case Key.KP_Space:
						toggle_all_tags();
						return true;
				}
				return false;
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

		private void toggle_all_tags()
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

		private void load_tags()
		{
			tags_list.foreach(w => w.destroy());

			foreach(var tag in Tables.Tags.TAGS)
			{
				if(!tag.enabled) continue;
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

		private void add_sort_mode(SortMode mode)
		{
			var image = new Image.from_icon_name(mode.icon(), IconSize.MENU);
			image.tooltip_text = mode.name();
			sort_mode_button.append(image);
		}
	}
}
