/*
This file is part of GameHub.
Copyright(C) Anatoliy Kashkin

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

/* Based on Granite.Widgets.ModeButton */

using Gtk;
using Gee;

namespace GameHub.UI.Widgets
{
	public class ModeButton: Box
	{
		private class Item: ToggleButton
		{
			public int index { get; construct; }
			public Item(int index)
			{
				Object(index: index);
				can_focus = false;
				add_events(Gdk.EventMask.SCROLL_MASK);
			}
		}

		public signal void mode_added(int index, Widget widget);
		public signal void mode_removed(int index, Widget widget);
		public signal void mode_changed(Widget widget);

		public int selected
		{
			get { return _selected; }
			set { set_active(value); }
		}

		public uint n_items { get { return item_map.size; } }

		private int _selected = -1;
		private HashMap<int, Item> item_map;

		public ModeButton(){}

		construct
		{
			homogeneous = true;
			spacing = 0;
			can_focus = false;
			item_map = new HashMap<int, Item>();
			StyleClass.add(this, Gtk.STYLE_CLASS_LINKED, "raised");
		}

		public int append_pixbuf(Gdk.Pixbuf pixbuf, string? tooltip=null, bool tooltip_markup=false)
		{
			return append(new Image.from_pixbuf(pixbuf), tooltip, tooltip_markup);
		}

		public int append_text(string text, string? tooltip=null, bool tooltip_markup=false)
		{
			return append(new Label(text), tooltip, tooltip_markup);
		}

		public int append_icon(string icon_name, IconSize size, string? tooltip=null, bool tooltip_markup=false)
		{
			return append(new Image.from_icon_name(icon_name, size), tooltip, tooltip_markup);
		}

		public int append(Widget w, string? tooltip=null, bool tooltip_markup=false)
		{
			int index;
			for(index = item_map.size; item_map.has_key(index); index++);
			assert(item_map[index] == null);

			var item = new Item(index);
			item.scroll_event.connect(on_scroll_event);
			item.add(w);

			item.toggled.connect(() => {
				if(item.active)
				{
					selected = item.index;
				}
				else if(selected == item.index)
				{
					item.active = true;
				}
			});

			item_map[index] = item;

			add(item);
			item.show_all();

			mode_added(index, w);

			if(tooltip != null)
			{
				if(tooltip_markup)
					w.tooltip_markup = tooltip;
				else
					w.tooltip_text = tooltip;
			}

			return index;
		}

		private void clear_selected()
		{
			_selected = -1;
			foreach(var item in item_map.values)
			{
				if(item != null && item.active)
				{
					item.set_active(false);
				}
			}
		}

		public void set_active(int new_active_index)
		{
			if(new_active_index <= -1)
			{
				clear_selected();
				return;
			}

			return_if_fail(item_map.has_key(new_active_index));
			var new_item = item_map[new_active_index] as Item;

			if(new_item != null)
			{
				assert(new_item.index == new_active_index);
				new_item.set_active(true);

				if(_selected == new_active_index) return;

				var old_item = item_map[_selected] as Item;

				_selected = new_active_index;

				if(old_item != null)
				{
					old_item.set_active(false);
				}

				mode_changed(new_item.get_child());
			}
		}

		public void set_item_visible(int index, bool val)
		{
			return_if_fail(item_map.has_key(index));
			var item = item_map[index] as Item;

			if(item != null)
			{
				assert(item.index == index);
				item.no_show_all = !val;
				item.visible = val;
			}
		}

		public new void remove(int index)
		{
			return_if_fail(item_map.has_key(index));
			var item = item_map[index] as Item;

			if(item != null)
			{
				assert(item.index == index);
				item_map.unset(index);
				mode_removed(index, item.get_child());
				item.destroy();
			}
		}

		public void clear_children()
		{
			foreach(weak Widget button in get_children())
			{
				button.hide();
				if(button.get_parent() != null)
				{
					base.remove(button);
				}
			}

			item_map.clear();
			_selected = -1;
		}

		private bool on_scroll_event(Widget widget, Gdk.EventScroll ev)
		{
			int offset;
			switch(ev.direction)
			{
				case Gdk.ScrollDirection.DOWN:
				case Gdk.ScrollDirection.RIGHT:
					offset = 1;
					break;
				case Gdk.ScrollDirection.UP:
				case Gdk.ScrollDirection.LEFT:
					offset = -1;
					break;
				default:
					return false;
			}

			var children = get_children();
			uint n_children = children.length();

			var selected_item = item_map[selected];
			if(selected_item == null) return false;

			int new_item = children.index(selected_item);
			if(new_item < 0) return false;

			do
			{
				new_item += offset;
				var item = children.nth_data(new_item) as Item;

				if(item != null && item.visible && item.sensitive)
				{
					selected = item.index;
					break;
				}
			}
			while(new_item >= 0 && new_item < n_children);

			return false;
		}
	}
}
