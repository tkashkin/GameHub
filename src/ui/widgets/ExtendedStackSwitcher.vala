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
using Gee;


namespace GameHub.UI.Widgets
{
	public class ExtendedStackSwitcher: ModeButton
	{
		public Stack stack { get; construct; }

		private ArrayList<string> tab_names = new ArrayList<string>();

		public ExtendedStackSwitcher(Stack stack)
		{
			Object(stack: stack, homogeneous: false);

			stack.notify["visible-child-name"].connect(() => {
				set_active(tab_names.index_of(stack.visible_child_name));
			});

			notify["selected"].connect(() => {
				if(selected > -1 && selected < tab_names.size)
				{
					stack.visible_child_name = tab_names[selected];
				}
			});
		}

		public void add_tab(Widget tab, string name, string? text=null, bool text_markup=true, string? icon=null, string? tooltip=null, bool tooltip_markup=true)
		{
			stack.add_named(tab, name);
			tab_names.add(name);

			var tab_hbox = new Box(Orientation.HORIZONTAL, 2);

			if(icon != null)
			{
				tab_hbox.add(new Image.from_icon_name(icon, IconSize.LARGE_TOOLBAR));
			}

			if(text != null)
			{
				var label = new Label(text);
				label.use_markup = text_markup;
				tab_hbox.add(label);
			}

			if(tooltip != null)
			{
				if(tooltip_markup)
				{
					tab_hbox.tooltip_markup = tooltip;
				}
				else
				{
					tab_hbox.tooltip_text = tooltip;
				}
			}

			tab_hbox.show_all();
			append(tab_hbox);
		}

		public void clear()
		{
			set_active(-1);
			tab_names.clear();
			clear_children();
			stack.foreach(t => t.destroy());
		}
	}
}
