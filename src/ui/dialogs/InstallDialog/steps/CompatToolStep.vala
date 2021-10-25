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

using GameHub.Data;
using GameHub.Data.Compat;
using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;

using GameHub.Utils;
using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Compat;
using GameHub.UI.Widgets.Settings;

namespace GameHub.UI.Dialogs.InstallDialog.Steps
{
	public class CompatToolStep: InstallDialogStep
	{
		private CompatToolsList compat_tools_list;

		public CompatToolStep(InstallTask task)
		{
			Object(task: task, title: _("Select compatibility layer"));
		}

		construct
		{
			var sgrp_compat = new SettingsGroupBox();
			sgrp_compat.container.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);
			compat_tools_list = sgrp_compat.add_widget(new CompatToolsList(task.runnable as Traits.SupportsCompatTools, CompatToolsList.Mode.INSTALL));
			add(sgrp_compat);

			compat_tools_list.compat_tool_selected.connect(tool => {
				tool.cast<CompatToolTraits.Install>(tool => task.selected_compat_tool = tool);
			});
		}
	}
}
