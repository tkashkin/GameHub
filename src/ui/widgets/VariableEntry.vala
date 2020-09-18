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

using GameHub.Utils;

namespace GameHub.UI.Widgets
{
	public class VariableEntry: Entry
	{
		public ArrayList<Variable>? variables { get; construct set; }
		private Gtk.Menu? menu = null;

		public VariableEntry(ArrayList<Variable>? variables = null)
		{
			Object(
				variables: variables,
				secondary_icon_name: "insert-text-symbolic",
				secondary_icon_tooltip_text: _("Variables")
			);
		}

		construct
		{
			icon_press.connect((icon_pos, e) => {
				if(icon_pos == EntryIconPosition.SECONDARY && menu != null)
				{
					grab_focus_without_selecting();
					#if GTK_3_22
					menu.popup_at_widget(this, Gravity.SOUTH_EAST, Gravity.NORTH_EAST, e);
					#else
					menu.popup(null, null, null, 0, ((EventButton) e).time);
					#endif
				}
			});

			update_variables();
		}

		private void update_variables()
		{
			if(menu != null)
			{
				menu.destroy();
				menu = null;
				secondary_icon_sensitive = false;
			}
			if(variables == null || variables.size == 0) return;

			menu = new Gtk.Menu();
			menu.halign = Align.END;

			var title_item = new Gtk.MenuItem.with_label("""<span weight="600" size="small">%s</span>""".printf(_("Variables")));
			((Label) title_item.get_child()).use_markup = true;
			title_item.sensitive = false;
			menu.add(title_item);

			foreach(var variable in variables)
			{
				var item_text = variable.variable;
				if(variable.description != null)
				{
					item_text = """<span weight="600" size="smaller">%s</span>%s%s""".printf(variable.variable, "\n", variable.description);
				}
				var item = new Gtk.MenuItem.with_label(item_text);
				((Label) item.get_child()).use_markup = true;
				item.activate.connect(() => {
					delete_selection();
					insert_at_cursor(variable.variable);
				});
				menu.add(item);
			}

			menu.show_all();
			secondary_icon_sensitive = true;
		}

		public class Variable: Object
		{
			public string variable { get; construct; }
			public string? description { get; construct; }

			public Variable(string variable, string? description = null)
			{
				Object(variable: variable, description: description);
			}
		}
	}
}
