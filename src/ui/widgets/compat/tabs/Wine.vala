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

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Data;
using GameHub.Data.Compat;
using GameHub.Data.Compat.Tools;

namespace GameHub.UI.Widgets.Compat.Tabs
{
	public class Wine: CompatToolsGroupTab
	{
		public Wine()
		{
			Object(title: "Wine");
		}

		construct
		{
			update();
		}

		private void update()
		{
			clear();

			var wine_versions = GameHub.Data.Compat.Tools.Wine.detect();
			foreach(var wine in wine_versions)
			{
				var row = new WineRow(wine);
				add_tool(row);
				if(tools_list.get_selected_row() == null)
				{
					tools_list.select_row(row);
				}
			}
		}

		protected override void create_options_widget(ListBoxRow row, Box container)
		{
			var wine_row = (WineRow) row;
			var wine = wine_row.wine;

			var sgrp_info = new SettingsGroup();

			var setting_info = sgrp_info.add_setting(new BaseSetting(wine_row.title, wine.executable.get_path()));
			setting_info.icon_name = wine.icon;

			container.add(sgrp_info);
		}

		private class WineRow: BaseSetting
		{
			public GameHub.Data.Compat.Tools.Wine wine { get; construct; }

			public WineRow(GameHub.Data.Compat.Tools.Wine wine)
			{
				Object(title: wine.name, description: wine.executable.get_path(), wine: wine, activatable: false, selectable: true);
			}

			construct
			{
				ellipsize_title = Pango.EllipsizeMode.END;
				ellipsize_description = Pango.EllipsizeMode.END;

				if(wine.version != null)
				{
					title = """%s<span alpha="75%"> • %s</span>""".printf(wine.name, wine.version);
				}
			}
		}
	}
}
