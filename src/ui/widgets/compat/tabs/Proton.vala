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
				var row = new ProtonRow(proton);
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

		protected override void create_options_widget(ListBoxRow row, Box container)
		{
			var proton_row = (ProtonRow) row;
			var proton = proton_row.proton;

			Json.Node? options_node = null;
			if(runnable != null)
			{
				options_node = runnable.get_compat_settings(proton);
			}
			var wine_options = new WineOptions.from_json(options_node ?? Parser.parse_json(proton.options));

			var sgrp_info = new SettingsGroup();

			var setting_info = sgrp_info.add_setting(new BaseSetting(proton_row.title, proton.executable.get_path()));
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

		public override void add_new_tool()
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

		private class ProtonRow: BaseSetting
		{
			public Tools.Proton.Proton proton { get; construct; }

			public ProtonRow(Tools.Proton.Proton proton)
			{
				Object(title: proton.name, description: proton.executable.get_path(), proton: proton, activatable: false, selectable: true);
			}

			construct
			{
				ellipsize_title = Pango.EllipsizeMode.END;
				ellipsize_description = Pango.EllipsizeMode.END;

				if(proton.version != null)
				{
					title = """%s<span alpha="75%"> • %s</span>""".printf(proton.name, proton.version);
				}
			}
		}
	}
}
