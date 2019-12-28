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

namespace GameHub.UI.Widgets
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
			hscrollbar_policy = PolicyType.NEVER;
			width_request = 200;
			listbox = new ListBox();
			listbox.activate_on_single_click = true;
			listbox.selection_mode = SelectionMode.SINGLE;

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
			public Widget? display_widget { get; construct; }
			public string? header { get; construct; }
			public string status { get; set; }

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
		}

		public abstract class SimpleSettingsPage: SettingsPage
		{
			private Image header_icon;
			private Label description_label;
			private Label title_label;
			private string _description;

			public ButtonBox action_area { get; construct; }
			public Grid content_area { get; construct; }
			public Switch? status_switch { get; construct; }
			public bool activatable { get; construct; }

			public string description
			{
				get
				{
					return _description;
				}
				construct set
				{
					if(description_label != null)
					{
						description_label.label = value;
					}
					_description = value;
				}
			}

			public new string icon_name
			{
				get
				{
					return _icon_name;
				}
				construct set
				{
					if(header_icon != null)
					{
						header_icon.icon_name = value;
					}
					_icon_name = value;
				}
			}

			construct
			{
				header_icon = new Image.from_icon_name(icon_name, IconSize.DIALOG);
				header_icon.pixel_size = 48;
				header_icon.valign = Align.START;

				title_label = Styled.H2Label(title);
				title_label.ellipsize = Pango.EllipsizeMode.END;
				title_label.xalign = 0;

				var header_area = new Grid();
				header_area.column_spacing = 12;
				header_area.row_spacing = 3;

				header_area.attach(title_label, 1, 0);

				if(description != null)
				{
					description_label = new Label(description);
					description_label.xalign = 0;
					description_label.wrap = true;

					header_area.attach(header_icon, 0, 0, 1, 2);
					header_area.attach(description_label, 1, 1);
				}
				else
				{
					header_area.attach(header_icon, 0, 0);
				}

				if(activatable)
				{
					status_switch = new Switch();
					status_switch.hexpand = true;
					status_switch.halign = Align.END;
					status_switch.valign = Align.CENTER;
					header_area.attach(status_switch, 2, 0);
				}

				content_area = new Grid();
				content_area.column_spacing = 12;
				content_area.row_spacing = 12;
				content_area.vexpand = true;

				action_area = new ButtonBox(Orientation.HORIZONTAL);
				action_area.set_layout(ButtonBoxStyle.END);
				action_area.spacing = 6;

				var grid = new Grid();
				grid.margin = 12;
				grid.orientation = Orientation.VERTICAL;
				grid.row_spacing = 24;
				grid.add(header_area);
				grid.add(content_area);
				grid.add(action_area);

				add(grid);

				set_action_area_visibility();

				action_area.add.connect(set_action_area_visibility);
				action_area.remove.connect(set_action_area_visibility);

				notify["icon-name"].connect(() => {
					if(header_icon != null)
					{
						header_icon.icon_name = icon_name;
					}
				});

				notify["title"].connect(() => {
					if(title_label != null)
					{
						title_label.label = title;
					}
				});
			}

			private void set_action_area_visibility()
			{
				if(action_area.get_children() != null)
				{
					action_area.no_show_all = false;
					action_area.show();
				}
				else
				{
					action_area.no_show_all = true;
					action_area.hide();
				}
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
							status_icon.icon_name = "dialog-error-symbolic";
							break;
						case SettingsPage.StatusType.WARNING:
							status_icon.icon_name = "dialog-warning-symbolic";
							break;
					}
				}
			}

			public Widget display_widget { get; construct; }

			public string? header { get; set; }

			public unowned SettingsPage page { get; construct; }

			public string icon_name
			{
				get
				{
					return _icon_name;
				}
				set
				{
					_icon_name = value;
					if(display_widget is Image)
					{
						((Image) display_widget).icon_name = value;
						((Image) display_widget).pixel_size = 32;
					}
				}
			}

			public string status
			{
				set
				{
					status_label.label = "<span font_size='small'>%s</span>".printf(value);
					status_label.no_show_all = false;
					status_label.show();
				}
			}

			public string title
			{
				get
				{
					return _title;
				}
				set
				{
					_title = value;
					title_label.label = value;
				}
			}

			private Image status_icon;
			private Label status_label;
			private Label title_label;
			private string _icon_name;
			private string _title;

			public Row(SettingsPage page)
			{
				Object(page: page);
			}

			construct
			{
				title_label = Styled.H3Label(page.title);
				title_label.ellipsize = Pango.EllipsizeMode.END;
				title_label.xalign = 0;

				status_icon = new Image();
				status_icon.halign = Align.END;
				status_icon.valign = Align.END;

				status_label = new Label(null);
				status_label.no_show_all = true;
				status_label.use_markup = true;
				status_label.ellipsize = Pango.EllipsizeMode.END;
				status_label.xalign = 0;

				if(page.icon_name != null)
				{
					display_widget = new Image();
					icon_name = page.icon_name;
				}
				else
				{
					display_widget = page.display_widget;
				}

				var overlay = new Overlay();
				overlay.width_request = 38;
				overlay.add(display_widget);
				overlay.add_overlay(status_icon);

				var grid = new Grid();
				grid.margin = 6;
				grid.column_spacing = 6;
				grid.attach(overlay, 0, 0, 1, 2);
				grid.attach(title_label, 1, 0, 1, 1);
				grid.attach(status_label, 1, 1, 1, 1);

				add(grid);

				header = page.header;
				page.bind_property("icon-name", this, "icon-name", BindingFlags.DEFAULT);
				page.bind_property("status", this, "status", BindingFlags.DEFAULT);
				page.bind_property("status-type", this, "status-type", BindingFlags.DEFAULT);
				page.bind_property("title", this, "title", BindingFlags.DEFAULT);

				if(page.status != null)
				{
					status = page.status;
				}

				if(page.status_type != SettingsPage.StatusType.NONE)
				{
					status_type = page.status_type;
				}
			}
		}
	}
}
