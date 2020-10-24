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
using GameHub.Data.Tweaks;
using GameHub.Data.Runnables;

namespace GameHub.UI.Widgets.Compat
{
	public class CompatToolsList: Notebook
	{
		public Traits.SupportsCompatTools? runnable { get; construct; default = null; }
		public Mode mode { get; construct; default = Mode.RUN; }

		public signal void compat_tool_selected(CompatTool tool);

		private Button add_tool_button;

		public CompatToolsList(Traits.SupportsCompatTools? runnable = null, Mode mode = Mode.RUN)
		{
			Object(runnable: runnable, mode: mode, show_border: false, expand: true, scrollable: true);
		}

		construct
		{
			add_tool_button = new Button.from_icon_name("list-add-symbolic", IconSize.SMALL_TOOLBAR);
			add_tool_button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			add_tool_button.valign = Align.CENTER;
			add_tool_button.tooltip_text = _("Add");
			add_tool_button.clicked.connect(add_tool);
			add_tool_button.show();
			set_action_widget(add_tool_button, PackType.END);
			update();
		}

		private void update()
		{
			this.foreach(w => w.destroy());
			add_tab(new Tabs.Wine(runnable, mode));
			add_tab(new Tabs.Proton(runnable, mode));

			if(mode == CompatToolsList.Mode.RUN)
			{
				add_tab(new Tabs.SteamCompatTools(runnable, mode));
			}
		}

		private void add_tool()
		{
			var tab = get_nth_page(page) as CompatToolsGroupTab;
			if(tab != null)
			{
				tab.add_new_tool(add_tool_button);
			}
		}

		private void add_tab(CompatToolsGroupTab tab)
		{
			append_page(tab, new Label(tab.title));
			tab.compat_tool_selected.connect(tool => compat_tool_selected(tool));
		}

		public enum Mode { RUN, INSTALL }
	}

	public abstract class CompatToolsGroupTab: Box
	{
		public string title { get; construct set; }

		public Traits.SupportsCompatTools? runnable { get; construct; default = null; }
		public CompatToolsList.Mode mode { get; construct; default = CompatToolsList.Mode.RUN; }

		protected ListBox tools_list;
		private Box tool_options;

		public signal void compat_tool_selected(CompatTool tool);

		construct
		{
			orientation = Orientation.HORIZONTAL;

			var tools_list_scrolled = new ScrolledWindow(null, null);
			tools_list_scrolled.get_style_context().add_class("compat-tools-list");
			tools_list_scrolled.set_size_request(200, -1);
			tools_list_scrolled.hscrollbar_policy = PolicyType.NEVER;
			tools_list_scrolled.hexpand = false;
			tools_list_scrolled.vexpand = true;

			tools_list = new ListBox();
			tools_list.selection_mode = SelectionMode.SINGLE;

			var tool_options_scrolled = new ScrolledWindow(null, null);
			tool_options_scrolled.get_style_context().add_class(Gtk.STYLE_CLASS_BACKGROUND);
			tool_options_scrolled.hscrollbar_policy = PolicyType.NEVER;
			tool_options_scrolled.expand = true;

			tool_options = new Box(Orientation.VERTICAL, 0);

			tools_list_scrolled.add(tools_list);
			tool_options_scrolled.add(tool_options);

			add(tools_list_scrolled);
			add(tool_options_scrolled);

			tools_list.set_sort_func((first_row, second_row) => {
				var first = ((CompatToolRow) first_row).tool;
				var second = ((CompatToolRow) second_row).tool;
				if(first.version != null && second.version != null) return second.version.collate(first.version);
				return second.name.collate(first.name);
			});

			tools_list.row_selected.connect((row) => {
				tool_options.foreach(w => w.destroy());
				if(row != null)
				{
					create_options_widget((CompatToolRow) row, tool_options);
					tool_options.show_all();
				}
			});

			show_all();
		}

		protected void clear()
		{
			tools_list.foreach(w => w.destroy());
			tool_options.foreach(w => w.destroy());
		}

		protected void add_tool(CompatToolRow row)
		{
			tools_list.add(row);
		}

		protected void select_tab()
		{
			Idle.add(() => {
				var notebook = parent as Notebook;
				if(notebook != null)
				{
					notebook.page = notebook.page_num(this);
				}
				return Source.REMOVE;
			});
		}

		protected virtual void create_options_widget(CompatToolRow row, Box container){}

		public virtual void add_new_tool(Button button){}
	}

	public class CompatToolRow: BaseSetting
	{
		public CompatTool tool { get; construct; }

		public CompatToolRow(CompatTool tool)
		{
			Object(tool: tool, activatable: false, selectable: true);
		}

		construct
		{
			ellipsize_title = Pango.EllipsizeMode.END;
			ellipsize_description = Pango.EllipsizeMode.END;
			activatable = false;
			selectable = false;
			if(tool.version != null)
			{
				title = """%s<span alpha="75%"> • %s</span>""".printf(tool.name, tool.version);
			}
			else
			{
				title = tool.name;
			}
			description = tool.executable.get_path();
		}
	}
}
