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

using Gee;

using GameHub.Data;
using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;

using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs.InstallDialog.Steps
{
	public class CompatToolStep: InstallDialogStep
	{
		private ListBox compat_tools_list;

		public CompatToolStep(InstallTask task)
		{
			Object(task: task, title: _("Select compatibility layer"));
		}

		construct
		{
			var scroll = new ScrolledWindow(null, null);
			scroll.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			scroll.hscrollbar_policy = PolicyType.NEVER;
			scroll.expand = true;
			scroll.margin = 8;

			#if GTK_3_22
			scroll.propagate_natural_height = true;
			scroll.max_content_height = 600;
			#endif

			compat_tools_list = new ListBox();
			compat_tools_list.selection_mode = SelectionMode.SINGLE;
			compat_tools_list.get_style_context().add_class("separated-list-all");

			compat_tools_list.row_selected.connect(row => {
				if(row != null)
				{
					task.selected_compat_tool = ((CompatToolRow) row).compat_tool;
				}
			});

			scroll.add(compat_tools_list);
			add(scroll);

			show_all();

			update();
		}

		public override void update()
		{
			compat_tools_list.foreach(r => r.destroy());
			foreach(var compat_tool in task.compat_tools)
			{
				var row = new CompatToolRow(task, compat_tool);
				compat_tools_list.add(row);
				if(compat_tool == task.selected_compat_tool)
				{
					compat_tools_list.select_row(row);
				}
			}
		}

		public class CompatToolRow: ListBoxRow
		{
			public InstallTask task { get; construct; }
			public CompatTool compat_tool { get; construct set; }

			private Grid grid;
			private Image icon;
			private Label name_label;
			private Label info_label;
			private Button options_button;

			public CompatToolRow(InstallTask task, CompatTool compat_tool)
			{
				Object(task: task, compat_tool: compat_tool);
			}

			construct
			{
				grid = new Grid();
				grid.column_spacing = 0;
				grid.margin_start = grid.margin_end = 8;
				grid.margin_top = grid.margin_bottom = 4;

				icon = new Image.from_icon_name(compat_tool.icon, IconSize.LARGE_TOOLBAR);
				icon.valign = Align.CENTER;
				icon.margin_end = 12;

				name_label = new Label(null);
				name_label.get_style_context().add_class("bold");
				name_label.ellipsize = Pango.EllipsizeMode.END;
				name_label.xalign = 0;
				name_label.valign = Align.CENTER;

				info_label = new Label(null);
				info_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				info_label.use_markup = true;
				info_label.hexpand = true;
				info_label.ellipsize = Pango.EllipsizeMode.END;
				info_label.xalign = 0;
				info_label.valign = Align.CENTER;

				options_button = new Button.from_icon_name("gh-settings-symbolic", IconSize.BUTTON);
				options_button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				options_button.valign = Align.CENTER;
				options_button.tooltip_text = _("Options");
				options_button.margin_start = 12;

				grid.attach(icon, 0, 0, 1, 2);
				grid.attach(name_label, 1, 0);
				grid.attach(info_label, 1, 1);
				grid.attach(options_button, 2, 0, 1, 2);

				child = grid;

				notify["compat_tool"].connect(() => update());
				update();
			}

			private void update()
			{
				icon.icon_name = compat_tool.icon;
				name_label.label = compat_tool.name;

				if(compat_tool.executable != null)
				{
					info_label.label = compat_tool.executable.get_path();
				}
			}
		}
	}
}
