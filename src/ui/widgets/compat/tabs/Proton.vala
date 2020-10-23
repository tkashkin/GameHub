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
using GameHub.Data.Compat.Tools.Wine;
using GameHub.Data.Compat.Tools.Proton;

using GameHub.Data.Sources.Steam;

using GameHub.Data.Runnables;

using GameHub.Utils;

namespace GameHub.UI.Widgets.Compat.Tabs
{
	public class Proton: Wine
	{
		public Proton(Traits.SupportsCompatTools? runnable = null, CompatToolsList.Mode mode = CompatToolsList.Mode.RUN)
		{
			Object(title: "Proton", runnable: runnable, mode: mode);
		}

		protected override void update()
		{
			clear();

			var proton_versions = Tools.Proton.Proton.detect();
			foreach(var proton in proton_versions)
			{
				var is_selected_tool = false;
				if(runnable != null)
				{
					if(mode == CompatToolsList.Mode.RUN && !proton.can_run(runnable))
						continue;
					if(mode == CompatToolsList.Mode.INSTALL && !proton.can_install(runnable))
						continue;
					is_selected_tool = runnable.compat_tool == proton.full_id;
				}
				var row = new CompatToolRow(proton);
				add_tool(row);
				if(tools_list.get_selected_row() == null || is_selected_tool)
				{
					tools_list.select_row(row);
				}
				if(is_selected_tool)
				{
					select_tab();
				}
			}
		}

		protected override void create_options_widget(CompatToolRow row, Box container)
		{
			var proton = (Tools.Proton.Proton) row.tool;

			Json.Node? options_node = null;
			if(runnable != null)
			{
				options_node = runnable.get_compat_settings(proton);
			}
			var wine_options = new WineOptions.from_json(options_node ?? Parser.parse_json(proton.options));

			var sgrp_info = new SettingsGroup();

			var setting_info = sgrp_info.add_setting(new BaseSetting(row.title, proton.executable.get_path()));
			setting_info.icon_name = proton.icon;

			container.add(sgrp_info);

			create_options_widget_wine(wine_options, container);

			sgrp_info.unrealize.connect(() => {
				var node = wine_options.to_json();
				if(runnable != null)
				{
					runnable.set_compat_settings(proton, node);
				}
				else
				{
					proton.options = Json.to_string(node, false);
					proton.save();
				}
			});

			compat_tool_selected(proton);
		}

		public override void add_new_tool(Button button)
		{
			var appids = Tools.Proton.Proton.get_appids();
			if(appids != null && appids.size > 0)
			{
				var menu = new Gtk.Menu();
				menu.halign = Align.END;

				var steam_menu = new Gtk.Menu();
				foreach(var app in appids.entries)
				{
					var menu_item = new Gtk.MenuItem.with_label(app.value);
					menu_item.activate.connect(() => {
						Steam.install_app(app.key);
					});
					steam_menu.add(menu_item);
				}

				var steam_menu_item = new Gtk.MenuItem.with_label(_("Install Proton from Steam"));
				steam_menu_item.submenu = steam_menu;
				menu.add(steam_menu_item);

				var custom_menu_item = new Gtk.MenuItem.with_label(_("Add custom Proton version"));
				custom_menu_item.activate.connect(add_custom_proton_version);
				menu.add(custom_menu_item);

				menu.show_all();
				#if GTK_3_22
				menu.popup_at_widget(button, Gravity.SOUTH_EAST, Gravity.NORTH_EAST, null);
				#else
				menu.popup(null, null, null, 0, Gdk.CURRENT_TIME);
				#endif
			}
			else
			{
				add_custom_proton_version();
			}
		}

		private void add_custom_proton_version()
		{
			#if GTK_3_22
			var chooser = new FileChooserNative(_("Select Proton executable"), GameHub.UI.Windows.MainWindow.instance, FileChooserAction.OPEN, _("Select"), _("Cancel"));
			#else
			var chooser = new FileChooserDialog(_("Select Proton executable"), GameHub.UI.Windows.MainWindow.instance, FileChooserAction.OPEN, _("Select"), ResponseType.ACCEPT, _("Cancel"), ResponseType.CANCEL);
			#endif
			if(chooser.run() == ResponseType.ACCEPT)
			{
				Tools.Proton.Proton.add_proton_version_from_file(chooser.get_file());
				update();
			}
		}
	}
}
