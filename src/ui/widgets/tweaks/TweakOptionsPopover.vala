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
using GameHub.Data.Tweaks;
using GameHub.Data.Runnables;

namespace GameHub.UI.Widgets.Tweaks
{
	public class TweakOptionsPopover: Popover
	{
		public Tweak tweak { get; construct; }

		private Box option_details_hbox;

		public TweakOptionsPopover(Tweak tweak)
		{
			Object(tweak: tweak);
		}

		construct
		{
			get_style_context().add_class("tweak-options-popover");

			if(tweak.options == null || tweak.options.size == 0)
			{
				var options_warning = new AlertView(_("%s: no configurable options").printf(tweak.name), _("This tweak does not have any configurable options"), "dialog-warning-symbolic");
				options_warning.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);
				options_warning.set_size_request(640, 240);
				options_warning.show_all();
				child = options_warning;
				return;
			}

			var hbox = new Box(Orientation.HORIZONTAL, 0);
			hbox.expand = true;
			hbox.set_size_request(640, 480);

			if(tweak.options.size > 1)
			{
				var options_vbox = new Box(Orientation.VERTICAL, 0);
				options_vbox.hexpand = false;
				options_vbox.vexpand = true;

				var options_title = new Label(_("Options"));
				options_title.get_style_context().add_class("list-title");
				options_title.xalign = 0;

				var options_scrolled = new ScrolledWindow(null, null);
				options_scrolled.expand = true;
				options_scrolled.hscrollbar_policy = PolicyType.NEVER;

				var options_list = new ListBox();
				options_list.set_size_request(200, -1);
				options_list.get_style_context().add_class("options-list");
				options_list.selection_mode = SelectionMode.BROWSE;

				options_scrolled.add(options_list);
				options_vbox.add(options_title);
				options_vbox.add(options_scrolled);

				hbox.add(options_vbox);
				hbox.add(new Separator(Orientation.VERTICAL));

				options_list.row_selected.connect(row => {
					select_option(((OptionRow) row).option);
				});

				foreach(var option in tweak.options)
				{
					options_list.add(new OptionRow(option));
				}
			}

			option_details_hbox = new Box(Orientation.HORIZONTAL, 0);
			option_details_hbox.expand = true;

			hbox.add(option_details_hbox);

			hbox.show_all();
			child = hbox;

			select_option(tweak.options.first());
		}

		private void select_option(Tweak.Option? option)
		{
			option_details_hbox.foreach(w => w.destroy());

			if(option == null) return;

			var has_presets = option.presets != null && option.presets.size > 0;
			var has_values = option.values != null && option.values.size > 0;

			if(has_presets)
			{
				var presets_vbox = new Box(Orientation.VERTICAL, 0);
				presets_vbox.expand = true;

				var presets_title = new Label(_("Presets"));
				presets_title.get_style_context().add_class("list-title");
				presets_title.xalign = 0;

				var presets_scrolled = new ScrolledWindow(null, null);
				presets_scrolled.expand = true;
				presets_scrolled.hscrollbar_policy = PolicyType.NEVER;

				var presets_list = new ListBox();
				presets_list.set_size_request(200, -1);
				presets_list.get_style_context().add_class("presets-list");
				presets_list.selection_mode = SelectionMode.NONE;

				presets_scrolled.add(presets_list);
				presets_vbox.add(presets_title);
				presets_vbox.add(presets_scrolled);

				presets_list.row_activated.connect(row => {
					((PresetRow) row).selected = true;
				});

				RadioButton? prev_radio = null;
				foreach(var preset in option.presets)
				{
					var row = new PresetRow(preset, prev_radio);
					presets_list.add(row);
					prev_radio = row.radio;
				}

				option_details_hbox.add(presets_vbox);
			}

			if(has_presets && has_values)
			{
				option_details_hbox.add(new Separator(Orientation.VERTICAL));
			}

			if(has_values)
			{
				var values_vbox = new Box(Orientation.VERTICAL, 0);
				values_vbox.expand = true;

				var values_title = new Label(_("Values"));
				values_title.get_style_context().add_class("list-title");
				values_title.xalign = 0;

				var values_scrolled = new ScrolledWindow(null, null);
				values_scrolled.expand = true;
				values_scrolled.hscrollbar_policy = PolicyType.NEVER;

				var values_list = new ListBox();
				values_list.set_size_request(200, -1);
				values_list.get_style_context().add_class("values-list");
				values_list.selection_mode = SelectionMode.NONE;

				values_scrolled.add(values_list);
				values_vbox.add(values_title);
				values_vbox.add(values_scrolled);

				values_list.row_activated.connect(r => {
					var row = (ValueRow) r;
					row.selected = !row.selected;
				});

				foreach(var value in option.values.entries)
				{
					values_list.add(new ValueRow(value.key, value.value));
				}

				option_details_hbox.add(values_vbox);
			}

			option_details_hbox.show_all();
		}

		private class OptionRow: ListBoxRow
		{
			public Tweak.Option option { get; construct; }

			public OptionRow(Tweak.Option option)
			{
				Object(option: option);
			}

			construct
			{
				get_style_context().add_class("option");

				var vbox = new Box(Orientation.VERTICAL, 0);
				vbox.hexpand = true;
				vbox.valign = Align.CENTER;

				var title = new Label(option.name ?? option.id);
				title.get_style_context().add_class("title");
				title.hexpand = true;
				title.ellipsize = Pango.EllipsizeMode.END;
				title.xalign = 0;
				vbox.add(title);

				if(option.description != null)
				{
					var description = new Label(option.description);
					description.get_style_context().add_class("description");
					description.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
					description.tooltip_text = description.label;
					description.hexpand = true;
					description.ellipsize = Pango.EllipsizeMode.END;
					description.xalign = 0;
					vbox.add(description);
				}

				child = vbox;
			}
		}

		private class PresetRow: ListBoxRow
		{
			public Tweak.Option.Preset preset { get; construct; }

			public bool selected { get; set; }
			public RadioButton? radio { get; construct; }

			public PresetRow(Tweak.Option.Preset preset, RadioButton? prev_radio = null)
			{
				Object(preset: preset, radio: new RadioButton.from_widget(prev_radio), selectable: false, activatable: true);
			}

			construct
			{
				get_style_context().add_class("preset");

				var grid = new Grid();
				grid.hexpand = true;
				grid.valign = Align.CENTER;

				radio.set_events(0);
				radio.can_focus = false;
				radio.valign = Align.CENTER;

				var title = new Label(preset.name ?? preset.id);
				title.get_style_context().add_class("title");
				title.hexpand = true;
				title.ellipsize = Pango.EllipsizeMode.END;
				title.xalign = 0;

				grid.attach(title, 0, 0);

				if(preset.description != null)
				{
					var description = new Label(preset.description);
					description.get_style_context().add_class("description");
					description.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
					description.tooltip_text = description.label;
					description.hexpand = true;
					description.ellipsize = Pango.EllipsizeMode.END;
					description.xalign = 0;

					grid.attach(description, 0, 1);
					grid.attach(radio, 1, 0, 1, 2);
				}
				else
				{
					grid.attach(radio, 1, 0);
				}

				bind_property("selected", radio, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

				child = grid;
			}
		}

		private class ValueRow: ListBoxRow
		{
			public string value { get; construct; }
			public string description { get; construct; }

			public bool selected { get; set; }

			public ValueRow(string value, string description)
			{
				Object(value: value, description: description, selectable: false, activatable: true);
			}

			construct
			{
				get_style_context().add_class("value");

				var grid = new Grid();
				grid.hexpand = true;
				grid.valign = Align.CENTER;

				var selected = new CheckButton();
				selected.set_events(0);
				selected.can_focus = false;
				selected.valign = Align.CENTER;

				var title = new Label(this.value);
				title.get_style_context().add_class("title");
				title.hexpand = true;
				title.ellipsize = Pango.EllipsizeMode.END;
				title.xalign = 0;

				grid.attach(title, 0, 0);

				var description = new Label(this.description);
				description.get_style_context().add_class("description");
				description.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				description.tooltip_text = description.label;
				description.hexpand = true;
				description.ellipsize = Pango.EllipsizeMode.END;
				description.xalign = 0;

				grid.attach(description, 0, 1);
				grid.attach(selected, 1, 0, 1, 2);

				bind_property("selected", selected, "active", BindingFlags.SYNC_CREATE);

				child = grid;
			}
		}
	}
}
