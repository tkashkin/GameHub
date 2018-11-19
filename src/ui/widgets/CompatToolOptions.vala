/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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
using Granite;

using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Widgets
{
	public class CompatToolOptions: ListBox
	{
		private CompatToolPicker compat_tool_picker;
		private Runnable game;
		private bool install;
		private string settings_key;

		public CompatToolOptions(Runnable game, CompatToolPicker picker, bool install = false)
		{
			this.game = game;
			this.compat_tool_picker = picker;
			this.install = install;
			this.settings_key = install ? "install_options" : "options";
			visible = false;
			get_style_context().add_class("tags-list");
			selection_mode = SelectionMode.NONE;
			update_options();
			compat_tool_picker.notify["selected"].connect(update_options);
		}

		public void update_options()
		{
			this.foreach(r => r.destroy());
			visible = false;

			if(compat_tool_picker == null || compat_tool_picker.selected == null) return;
			var options = install ? compat_tool_picker.selected.install_options : compat_tool_picker.selected.options;
			if(options == null) return;

			var tool_settings = game.get_compat_settings(compat_tool_picker.selected);
			var ts_options = tool_settings.has_member(settings_key) ? tool_settings.get_object_member(settings_key) : new Json.Object();

			foreach(var opt in options)
			{
				if(ts_options != null && ts_options.has_member(opt.name))
				{
					if(opt is CompatTool.BoolOption)
					{
						((CompatTool.BoolOption) opt).enabled = ts_options.get_boolean_member(opt.name);
					}
					else if(opt is CompatTool.FileOption)
					{
						((CompatTool.FileOption) opt).file = FSUtils.file(ts_options.get_string_member(opt.name));
					}
					else if(opt is CompatTool.ComboOption)
					{
						var val = ts_options.get_string_member(opt.name);
						if(val == null || val in ((CompatTool.ComboOption) opt).options)
						{
							((CompatTool.ComboOption) opt).value = val;
						}
					}
					else if(opt is CompatTool.StringOption)
					{
						((CompatTool.StringOption) opt).value = ts_options.get_string_member(opt.name);
					}
				}
				add(new OptionRow(opt));
			}

			show_all();
		}

		public void save_options()
		{
			game.compat_options_saved = true;

			if(compat_tool_picker == null || compat_tool_picker.selected == null) return;
			var options = install ? compat_tool_picker.selected.install_options : compat_tool_picker.selected.options;
			if(options == null) return;

			var tool_settings = game.get_compat_settings(compat_tool_picker.selected);
			var ts_options = tool_settings.has_member(settings_key) ? tool_settings.get_object_member(settings_key) : new Json.Object();

			foreach(var opt in options)
			{
				if(opt is CompatTool.BoolOption)
				{
					ts_options.set_boolean_member(opt.name, ((CompatTool.BoolOption) opt).enabled);
				}
				else if(opt is CompatTool.FileOption)
				{
					var file = ((CompatTool.FileOption) opt).file;
					if(file != null && file.query_exists())
					{
						ts_options.set_string_member(opt.name, file.get_path());
					}
					else
					{
						ts_options.remove_member(opt.name);
					}
				}
				else if(opt is CompatTool.ComboOption)
				{
					var val = ((CompatTool.ComboOption) opt).value;
					if(val != null && val in ((CompatTool.ComboOption) opt).options)
					{
						ts_options.set_string_member(opt.name, val);
					}
					else
					{
						ts_options.remove_member(opt.name);
					}
				}
				else if(opt is CompatTool.StringOption)
				{
					var val = ((CompatTool.StringOption) opt).value;
					if(val != null)
					{
						ts_options.set_string_member(opt.name, val);
					}
					else
					{
						ts_options.remove_member(opt.name);
					}
				}
			}
			tool_settings.set_object_member(settings_key, ts_options);
			game.set_compat_settings(compat_tool_picker.selected, tool_settings);
		}

		public class OptionRow: ListBoxRow
		{
			public CompatTool.Option option { get; construct; }

			public OptionRow(CompatTool.Option option)
			{
				Object(option: option);
			}

			construct
			{
				var ebox = new EventBox();
				ebox.above_child = true;

				var box = new Box(Orientation.HORIZONTAL, 6);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 6;

				var name = new Label(option.description);
				name.halign = Align.START;
				name.xalign = 0;
				name.hexpand = true;

				ebox.tooltip_text = option.name;

				Widget? option_widget = null;

				if(option is CompatTool.BoolOption)
				{
					var bool_option = (CompatTool.BoolOption) option;

					var check = new CheckButton();
					check.margin_end = 2;
					check.active = bool_option.enabled;
					box.add(check);

					ebox.add_events(EventMask.ALL_EVENTS_MASK);
					ebox.button_release_event.connect(e => {
						if(e.button == 1)
						{
							check.active = !check.active;
							bool_option.enabled = check.active;
						}
						return true;
					});
				}
				else if(option is CompatTool.FileOption)
				{
					var file_option = (CompatTool.FileOption) option;

					var icon = new Image.from_icon_name("document-open-symbolic", IconSize.MENU);
					box.add(icon);

					ebox.above_child = false;
					box.margin_top = box.margin_bottom = 2;
					box.margin_end = 0;

					var chooser = new FileChooserButton(file_option.description, FileChooserAction.OPEN);
					chooser.show_hidden = true;
					chooser.set_size_request(170, -1);
					if(file_option.file != null || file_option.directory != null)
					{
						try
						{
							chooser.select_file(file_option.file ?? file_option.directory);
							chooser.tooltip_text = chooser.get_filename();
						}
						catch(Error e)
						{
							warning(e.message);
						}
					}
					chooser.file_set.connect(() => {
						file_option.file = chooser.get_file();
						chooser.tooltip_text = chooser.get_filename();
					});
					option_widget = chooser;
				}
				else if(option is CompatTool.ComboOption)
				{
					var combo_option = (CompatTool.ComboOption) option;

					var icon = new Image.from_icon_name("view-sort-descending-symbolic", IconSize.MENU);
					box.add(icon);

					ebox.above_child = false;
					box.margin_top = box.margin_bottom = 2;
					box.margin_end = 0;

					var model = new Gtk.ListStore(1, typeof(string));
					Gtk.TreeIter iter;

					foreach(var opt in combo_option.options)
					{
						model.append(out iter);
						model.set(iter, 0, opt);
					}

					var combo = new ComboBox.with_model(model);
					combo.set_size_request(170, -1);

					var renderer = new CellRendererText();
					combo.pack_start(renderer, true);
					combo.add_attribute(renderer, "text", 0);
					combo.changed.connect(() => {
						Value v;
						combo.get_active_iter(out iter);
						model.get_value(iter, 0, out v);
						combo_option.value = v as string;
					});
					combo.active = combo_option.value in combo_option.options ? combo_option.options.index_of(combo_option.value) : 0;
					option_widget = combo;
				}
				else if(option is CompatTool.StringOption)
				{
					var string_option = (CompatTool.StringOption) option;

					var icon = new Image.from_icon_name("insert-text-symbolic", IconSize.MENU);
					box.add(icon);

					ebox.above_child = false;
					box.margin_top = box.margin_bottom = 2;
					box.margin_end = 0;

					var entry = new Entry();
					entry.set_size_request(170, -1);
					if(string_option.value != null)
					{
						entry.text = string_option.value;
					}
					entry.notify["text"].connect(() => { string_option.value = entry.text; });
					option_widget = entry;
				}

				box.add(name);

				if(option_widget != null) box.add(option_widget);

				ebox.add(box);

				child = ebox;
			}
		}
	}
}
