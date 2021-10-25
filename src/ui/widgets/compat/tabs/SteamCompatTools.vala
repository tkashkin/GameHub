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

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Data;
using GameHub.Data.Compat;
using GameHub.Data.Compat.Tools;
using GameHub.Data.Runnables;

using GameHub.Utils;

namespace GameHub.UI.Widgets.Compat.Tabs
{
	public class SteamCompatTools: CompatToolsGroupTab
	{
		protected ArrayList<VariableEntry.Variable> prefix_variables = new ArrayList<VariableEntry.Variable>();

		public SteamCompatTools(Traits.SupportsCompatTools? runnable = null, CompatToolsList.Mode mode = CompatToolsList.Mode.RUN)
		{
			Object(title: _("Other (Steam)"), runnable: runnable, mode: mode);
		}

		construct
		{
			update();
		}

		protected virtual void update()
		{
			clear();

			if(mode != CompatToolsList.Mode.RUN) return;

			var steamct_tools = Tools.SteamCompatTool.detect();
			foreach(var tool in steamct_tools)
			{
				var is_selected_tool = false;
				if(runnable != null)
				{
					if(!tool.can_run(runnable)) continue;
					is_selected_tool = runnable.compat_tool == tool.full_id;
				}
				var row = new CompatToolRow(tool);
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
			var tool = (Tools.SteamCompatTool) row.tool;

			var sgrp_info = new SettingsGroup();

			var setting_info = sgrp_info.add_setting(new BaseSetting(row.title, tool.executable.get_path()));
			setting_info.icon_name = tool.icon;

			container.add(sgrp_info);

			compat_tool_selected(tool);
		}

		public override void add_new_tool(Button button)
		{
			var chooser = new FileChooserNative(_("Select Steam compatibility tool directory"), GameHub.UI.Windows.MainWindow.instance, FileChooserAction.SELECT_FOLDER, _("Select"), _("Cancel"));
			if(chooser.run() == ResponseType.ACCEPT)
			{
				Tools.SteamCompatTool.add_tool_from_directory(chooser.get_file());
				update();
			}
		}
	}
}
