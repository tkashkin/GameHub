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

using Gtk;
using Gee;

using GameHub.UI.Widgets;
using GameHub.Utils;

namespace GameHub.UI.Widgets.Settings
{
	public interface ActivatableSetting: ListBoxRow
	{
		public signal void setting_activated();
	}

	public class BaseSetting: ListBoxRow, ActivatableSetting
	{
		public string title { get; construct set; }
		public string? description { get; construct set; }
		public string? icon_name { get; set; }
		public Widget? widget { get; construct set; }

		public Pango.EllipsizeMode ellipsize_title { get; set; default = Pango.EllipsizeMode.NONE; }
		public Pango.EllipsizeMode ellipsize_description { get; set; default = Pango.EllipsizeMode.NONE; }

		private Box hbox;
		protected Image icon_image;
		protected Label title_label;
		protected Label description_label;

		public BaseSetting(string title, string? description = null, Widget? widget = null)
		{
			Object(title: title, description: description, widget: widget, activatable: false, selectable: false);
		}

		construct
		{
			get_style_context().add_class("setting");

			hbox = new Box(Orientation.HORIZONTAL, 12);

			icon_image = new Image.from_icon_name("gamehub-symbolic", IconSize.LARGE_TOOLBAR);
			icon_image.no_show_all = true;
			icon_image.valign = Align.CENTER;

			hbox.add(icon_image);

			var text_vbox = new Box(Orientation.VERTICAL, 0);
			text_vbox.hexpand = true;
			text_vbox.valign = Align.CENTER;

			title_label = new Label(null);
			title_label.get_style_context().add_class("title");
			title_label.use_markup = true;
			title_label.hexpand = true;
			title_label.wrap = true;
			title_label.xalign = 0;

			description_label = new Label(null);
			description_label.get_style_context().add_class("description");
			description_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
			description_label.use_markup = true;
			description_label.hexpand = true;
			description_label.wrap = true;
			description_label.xalign = 0;
			description_label.no_show_all = true;

			text_vbox.add(title_label);
			text_vbox.add(description_label);

			hbox.add(text_vbox);
			child = hbox;
			show_all();

			description_label.notify["label"].connect(() => {
				description_label.visible = description_label.label != null && description_label.label.length > 0;
			});

			bind_property("title", title_label, "label", BindingFlags.SYNC_CREATE);

			bind_property("description", description_label, "label", BindingFlags.SYNC_CREATE);
			bind_property("description", description_label, "tooltip-markup", BindingFlags.SYNC_CREATE);

			notify["ellipsize-title"].connect(() => {
				title_label.ellipsize = ellipsize_title;
				title_label.wrap = ellipsize_title == Pango.EllipsizeMode.NONE;
			});

			notify["ellipsize-description"].connect(() => {
				description_label.ellipsize = ellipsize_description;
				description_label.wrap = ellipsize_description == Pango.EllipsizeMode.NONE;
			});

			notify["icon-name"].connect(() => {
				icon_image.icon_name = icon_name;
				icon_image.visible = icon_name != null;
			});

			notify["widget"].connect(() => replace_widget(widget));
			replace_widget(widget);
		}

		protected void replace_widget(Widget? w)
		{
			if(widget != null && widget.parent == hbox)
			{
				hbox.remove(widget);
			}
			widget = w;
			if(widget != null && widget.parent != hbox)
			{
				widget.valign = Align.CENTER;
				widget.halign = Align.END;
				hbox.add(widget);
				init_widget(widget);
			}
		}

		protected virtual void init_widget(Widget w){}
	}

	public class CustomWidgetSetting: ListBoxRow
	{
		public Widget widget { get; construct; }

		public CustomWidgetSetting(Widget widget)
		{
			Object(widget: widget, activatable: false, selectable: false);
		}

		construct
		{
			get_style_context().add_class("setting");
			get_style_context().add_class("custom-widget-setting");
			child = widget;
			show_all();
		}
	}

	public class LabelSetting: ListBoxRow
	{
		public Label label { get; construct; }

		public LabelSetting(string label)
		{
			Object(label: new Label(label), activatable: false, selectable: false, can_focus: false);
		}

		construct
		{
			get_style_context().add_class("setting");
			get_style_context().add_class("label-setting");
			label.wrap = true;
			child = label;
			show_all();
		}
	}

	public class ButtonLabelSetting: ListBoxRow, ActivatableSetting
	{
		public Label label { get; construct; }
		public Button button { get; construct; }

		public ButtonLabelSetting(string label, string button_label, bool activate_on_row_click = false)
		{
			Object(label: new Label(label), button: new Button.with_label(button_label), activatable: activate_on_row_click, selectable: false);
		}

		construct
		{
			get_style_context().add_class("setting");
			get_style_context().add_class("label-setting");
			get_style_context().add_class("button-label-setting");

			label.halign = Align.START;
			label.valign = Align.CENTER;
			label.xalign = 0;
			label.hexpand = true;
			label.wrap = true;

			button.halign = Align.END;
			button.valign = Align.CENTER;
			button.can_focus = !activatable;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(button);

			child = hbox;
			show_all();

			setting_activated.connect(() => {
				if(activatable)
				{
					button.activate();
				}
			});
		}
	}

	public class LinkLabelSetting: ButtonLabelSetting
	{
		public LinkButton link { get { return button as LinkButton; } }

		public LinkLabelSetting(string label, string link_label, string url, bool activate_on_row_click = true)
		{
			Object(label: new Label(label), button: new LinkButton.with_label(url, link_label), activatable: activate_on_row_click, selectable: false);
		}

		construct
		{
			get_style_context().remove_class("button-label-setting");
			get_style_context().add_class("link-label-setting");
		}
	}

	public class SwitchSetting: BaseSetting
	{
		public Switch? @switch { get { return widget as Switch; } }

		public SwitchSetting(string title, string? description = null, bool active = false)
		{
			Object(title: title, description: description, widget: new Switch(), activatable: true, selectable: false);
			@switch.active = active;
			@switch.can_focus = false;
		}

		public SwitchSetting.bind(string title, string? description = null, Object target, string prop, BindingFlags flags = BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL)
		{
			Object(title: title, description: description, widget: new Switch(), activatable: true, selectable: false);
			target.bind_property(prop, @switch, "active", flags);
			@switch.can_focus = false;
		}

		construct
		{
			get_style_context().add_class("switch-setting");
			setting_activated.connect(() => {
				@switch.activate();
			});
		}
	}

	public class EntrySetting: BaseSetting
	{
		public Entry? entry { get { return widget as Entry; } }

		public EntrySetting(string title, string? description = null, Entry text_entry, string? value = null)
		{
			Object(title: title, description: description, widget: text_entry, activatable: false, selectable: false);
			if(value != null) entry.text = value;
		}

		public EntrySetting.bind(string title, string? description = null, Entry text_entry, Object target, string prop, BindingFlags flags = BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL)
		{
			Object(title: title, description: description, widget: text_entry, activatable: false, selectable: false);
			target.bind_property(prop, entry, "text", flags);
		}

		construct
		{
			get_style_context().add_class("entry-setting");
		}
	}

	public class ModeButtonSetting: BaseSetting
	{
		public ModeButton? button { get { return widget as ModeButton; } }

		public ModeButtonSetting(string title, string? description = null, string[]? options = null, int selected_option = -1)
		{
			Object(title: title, description: description, widget: new ModeButton(), options: options, selected_option: selected_option, activatable: false, selectable: false);
		}

		public ModeButtonSetting.bind(string title, string? description = null, string[]? options = null, Object target, string prop, BindingFlags flags = BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL)
		{
			Object(title: title, description: description, widget: new ModeButton(), activatable: false, selectable: false);
			target.bind_property(prop, this, "selected-option", flags);
			this.options = options;
		}

		private string[]? _options = null;
		private int _selected_option = -1;

		public string[]? options
		{
			get { return _options; }
			set
			{
				_options = value;
				if(button != null && _options != null)
				{
					button.clear_children();
					for(var i = 0; i < _options.length; i++)
					{
						button.append_text(_options[i]);
						if(i == selected_option)
						{
							button.selected = i;
						}
					}
				}
			}
		}
		public int selected_option
		{
			get { return _selected_option; }
			set
			{
				_selected_option = value;
				if(_selected_option >= 0 && _selected_option < button.n_items)
				{
					button.selected = _selected_option;
				}
			}
		}

		construct
		{
			get_style_context().add_class("mode-button-setting");
			button.homogeneous = false;
			button.mode_changed.connect(() => {
				selected_option = button.selected;
			});
		}
	}

	public class FileSetting: BaseSetting
	{
		public FileChooserEntry? chooser { get { return widget as FileChooserEntry; } }

		public FileSetting(string title, string? description = null, FileChooserEntry file_chooser, string? value)
		{
			Object(title: title, description: description, widget: file_chooser, activatable: false, selectable: false);
			chooser.select_file_path(value);
		}

		public FileSetting.bind(string title, string? description = null, FileChooserEntry file_chooser, Object target, string prop, BindingFlags flags = BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL)
		{
			Object(title: title, description: description, widget: file_chooser, activatable: false, selectable: false);
			target.bind_property(prop, chooser, "file-path", flags);
		}

		construct
		{
			get_style_context().add_class("file-setting");
		}
	}

	public class DirectoryButtonSetting: BaseSetting
	{
		public Button? button { get { return widget as Button; } }
		public File directory { get; construct; }

		public DirectoryButtonSetting(string title, string? description = null, string button_icon = "folder-symbolic", File directory)
		{
			Object(title: title, description: description ?? directory.get_path(), widget: new Button.from_icon_name(button_icon, IconSize.BUTTON), directory: directory, activatable: true, selectable: false);
		}

		construct
		{
			get_style_context().add_class("directory-button-setting");

			button.tooltip_text = _("Open directory");
			button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			button.can_focus = false;

			button.clicked.connect(() => {
				Utils.open_uri(directory.get_uri());
			});

			setting_activated.connect(() => {
				button.clicked();
			});
		}
	}

	public class DirectoriesMenuSetting: BaseSetting
	{
		public MenuButton? button { get { return widget as MenuButton; } }
		public ArrayList<File> directories { get; construct; }

		public DirectoriesMenuSetting(string title, string? description = null, ArrayList<File> directories)
		{
			Object(title: title, description: description, widget: new MenuButton(), directories: directories, activatable: true, selectable: false);
		}

		public DirectoriesMenuSetting.paths(string title, string? description = null, ArrayList<string> paths)
		{
			var directories = new ArrayList<File>();
			foreach(var path in paths)
			{
				directories.add(FS.file(path));
			}
			Object(title: title, description: description, widget: new MenuButton(), directories: directories, activatable: true, selectable: false);
		}

		construct
		{
			get_style_context().add_class("directories-menu-setting");

			button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			button.can_focus = false;

			var menu = new Gtk.Menu();
			menu.reserve_toggle_size = false;
			menu.halign = Align.END;

			foreach(var dir in directories)
			{
				var dir_item = new Gtk.MenuItem.with_label(dir.get_path());
				if(dir.query_exists())
				{
					dir_item.activate.connect(() => {
						Utils.open_uri(dir.get_uri());
					});
				}
				else
				{
					dir_item.sensitive = false;
				}
				menu.add(dir_item);
			}

			menu.show_all();
			button.popup = menu;

			setting_activated.connect(() => {
				button.clicked();
			});
		}
	}

	namespace InlineWidgets
	{
		public const int ENTRY_WIDTH = 320;

		public Entry entry(string? icon=null)
		{
			var entry = new Entry();
			entry.set_size_request(ENTRY_WIDTH, -1);
			entry.primary_icon_name = icon;
			entry.primary_icon_activatable = false;
			return entry;
		}

		public VariableEntry variable_entry(ArrayList<VariableEntry.Variable>? variables=null, string? icon=null)
		{
			var entry = new VariableEntry(variables);
			entry.set_size_request(ENTRY_WIDTH, -1);
			entry.primary_icon_name = icon;
			entry.primary_icon_activatable = false;
			return entry;
		}

		public FileChooserEntry file_chooser(string text, FileChooserAction mode, bool create=true, string? icon=null, bool allow_url=false, bool allow_executable=false, string? root_dir_prefix=null)
		{
			var chooser = new FileChooserEntry(text, mode, icon, null, allow_url, allow_executable, root_dir_prefix);
			chooser.chooser.create_folders = create;
			chooser.chooser.show_hidden = true;
			chooser.set_size_request(ENTRY_WIDTH, -1);
			return chooser;
		}
	}
}
