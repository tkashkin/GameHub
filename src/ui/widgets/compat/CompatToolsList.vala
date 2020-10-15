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
		}

		private void add_tool()
		{

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

			tools_list.row_selected.connect((row) => {
				tool_options.foreach(w => w.destroy());
				if(row != null)
				{
					create_options_widget(row, tool_options);
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

		protected void add_tool(ListBoxRow row)
		{
			tools_list.add(row);
		}

		protected virtual void create_options_widget(ListBoxRow row, Box container){}
	}
}
