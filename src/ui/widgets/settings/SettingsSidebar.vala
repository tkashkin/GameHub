/*
This file is part of GameHub.
Copyright(C) 2018-2019 Anatoliy Kashkin

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

/* Based on Granite.SettingsSidebar */

using Gtk;

namespace GameHub.UI.Widgets.Settings
{
	public class SettingsSidebar: ScrolledWindow
	{
		private ListBox listbox;
		public Stack stack { get; construct; }

		public string? visible_child_name
		{
			get
			{
				var selected_row = listbox.get_selected_row();
				if(selected_row == null)
				{
					return null;
				}
				else
				{
					return ((Row) selected_row).name;
				}
			}
			set
			{
				foreach(unowned Widget listbox_child in listbox.get_children())
				{
					if(((Row) listbox_child).name == value)
					{
						listbox.select_row((ListBoxRow) listbox_child);
					}
				}
			}
		}

		public SettingsSidebar(Stack stack)
		{
			Object(stack: stack);
		}

		construct
		{
			get_style_context().add_class("settings-sidebar");

			hscrollbar_policy = PolicyType.NEVER;
			width_request = 200;
			listbox = new ListBox();
			listbox.activate_on_single_click = true;
			listbox.selection_mode = SelectionMode.SINGLE;
			listbox.hexpand = false;

			add(listbox);

			on_sidebar_changed();
			stack.add.connect(on_sidebar_changed);
			stack.remove.connect(on_sidebar_changed);

			listbox.row_selected.connect((row) => {
				stack.visible_child = ((Row) row).page;
			});

			listbox.set_header_func((row, before) => {
				var header = ((Row) row).header;
				if(header != null)
				{
					row.set_header(Styled.H4Label(header));
				}
			});
		}

		private void on_sidebar_changed()
		{
			listbox.get_children().foreach((listbox_child) => {
				listbox_child.destroy();
			});

			stack.get_children().foreach((child) => {
				if(child is SettingsSidebar.SettingsPage)
				{
					var row = new Row((SettingsPage) child);
					listbox.add(row);
				}
			});

			listbox.show_all();
		}

		public abstract class SettingsPage: ScrolledWindow
		{
			protected string _icon_name;
			protected string _title;

			public enum StatusType { ERROR, WARNING, NONE }

			public StatusType status_type { get; set; default = StatusType.NONE; }
			public string? header { get; construct set; }
			public string? description { get; construct set; }

			public bool has_active_switch { get; construct set; }
			public bool active { get; construct set; }

			public string? icon_name
			{
				get
				{
					return _icon_name;
				}
				construct set
				{
					_icon_name = value;
				}
			}

			public string title
			{
				get
				{
					return _title;
				}
				construct set
				{
					_title = value;
				}
			}

			construct
			{
			    get_style_context().add_class("settings-page");
			}
		}

		public abstract class SimpleSettingsPage: SettingsPage
		{
			public Box content { get; construct; }

			construct
			{
			    get_style_context().add_class("simple-settings-page");
				content = new Box(Orientation.VERTICAL, 0);
				content.vexpand = true;
				add(content);
				notify["has-active-switch"].connect(update_sensitivity);
				notify["active"].connect(update_sensitivity);
				update_sensitivity();
			}

			private void update_sensitivity()
			{
			    content.sensitive = active || !has_active_switch;
			}

			protected T add_widget<T>(T widget)
			{
			    content.add((Widget) widget);
			    return widget;
			}
		}

		private class Row: ListBoxRow
		{
			public SettingsPage.StatusType status_type
			{
				set
				{
					switch(value)
					{
						case SettingsPage.StatusType.ERROR:
						    status_icon.visible = true;
							status_icon.icon_name = "dialog-error-symbolic";
							break;
						case SettingsPage.StatusType.WARNING:
						    status_icon.visible = true;
							status_icon.icon_name = "dialog-warning-symbolic";
							break;
						default:
						    status_icon.visible = false;
						    break;
					}
				}
			}

			public unowned SettingsPage page { get; construct; }

			public string? icon_name
			{
				owned get
				{
					return icon.icon_name;
				}
				set
				{
					icon.icon_name = value;
				}
			}

			public string? header { get; set; }

			public string? title
			{
				get
				{
					return title_label.label;
				}
				set
				{
					title_label.label = value;
				}
			}

			private Image icon;
			private Label title_label;
			private Image status_icon;

			public Row(SettingsPage page)
			{
				Object(page: page);
			}

			construct
			{
			    get_style_context().add_class("settings-sidebar-row");

				icon = new Image();
				icon.halign = Align.START;
				icon.valign = Align.CENTER;
				icon.icon_size = IconSize.BUTTON;

				title_label = Styled.H3Label(page.title);
				title_label.hexpand = true;
				title_label.ellipsize = Pango.EllipsizeMode.END;
				title_label.xalign = 0;
				title_label.valign = Align.CENTER;

				status_icon = new Image();
				status_icon.halign = Align.END;
				status_icon.valign = Align.CENTER;
				status_icon.icon_size = IconSize.BUTTON;
				status_icon.no_show_all = true;

				var hbox = new Box(Orientation.HORIZONTAL, 8);

				hbox.add(icon);
				hbox.add(title_label);
				hbox.add(status_icon);
				hbox.show_all();

				child = hbox;

				page.bind_property("header", this, "header", BindingFlags.SYNC_CREATE);
				page.bind_property("icon-name", this, "icon-name", BindingFlags.SYNC_CREATE);
				page.bind_property("title", this, "title", BindingFlags.SYNC_CREATE);
				page.bind_property("status-type", this, "status-type", BindingFlags.SYNC_CREATE);
			}
		}
	}
}
