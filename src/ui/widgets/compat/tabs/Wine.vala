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
using GameHub.Data.Compat.Tools.Wine;
using GameHub.Data.Runnables;

using GameHub.Utils;

namespace GameHub.UI.Widgets.Compat.Tabs
{
	public class Wine: CompatToolsGroupTab
	{
		protected ArrayList<VariableEntry.Variable> prefix_variables = new ArrayList<VariableEntry.Variable>();

		public Wine(Traits.SupportsCompatTools? runnable = null, CompatToolsList.Mode mode = CompatToolsList.Mode.RUN)
		{
			Object(title: "Wine", runnable: runnable, mode: mode);
		}

		construct
		{
			prefix_variables.add(new VariableEntry.Variable("${compat_shared}", _("Shared compatibility data directory")));
			prefix_variables.add(new VariableEntry.Variable("${tool_type}", _("Type of compatibility layer (\"wine\" for Wine)")));
			prefix_variables.add(new VariableEntry.Variable("${tool_id}", _("Identifier of compatibility layer")));
			prefix_variables.add(new VariableEntry.Variable("${tool_version}", _("Version of compatibility layer")));
			prefix_variables.add(new VariableEntry.Variable("${install_dir}", _("Installation directory of the game")));
			prefix_variables.add(new VariableEntry.Variable("${id}", _("Identifier of the game")));
			prefix_variables.add(new VariableEntry.Variable("${compat}", _("Compatibility data subdirectory")));

			update();
		}

		protected virtual void update()
		{
			clear();

			var wine_versions = Tools.Wine.Wine.detect();
			foreach(var wine in wine_versions)
			{
				var is_selected_tool = false;
				if(runnable != null)
				{
					if(mode == CompatToolsList.Mode.RUN && !wine.can_run(runnable))
						continue;
					if(mode == CompatToolsList.Mode.INSTALL && !wine.can_install(runnable))
						continue;
					is_selected_tool = runnable.compat_tool == wine.full_id;
				}
				var row = new CompatToolRow(wine);
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
			var wine = (Tools.Wine.Wine) row.tool;

			Json.Node? options_node = null;
			if(runnable != null)
			{
				options_node = runnable.get_compat_settings(wine);
			}
			var wine_options = new WineOptions.from_json(options_node ?? Parser.parse_json(wine.options));

			var sgrp_info = new SettingsGroup();

			var setting_info = sgrp_info.add_setting(new BaseSetting(row.title, wine.executable.get_path()));
			setting_info.icon_name = wine.icon;

			container.add(sgrp_info);

			create_options_widget_wine(wine_options, container);

			sgrp_info.unrealize.connect(() => {
				var node = wine_options.to_json();
				if(runnable != null)
				{
					runnable.set_compat_settings(wine, node);
				}
				else
				{
					wine.options = Json.to_string(node, false);
					wine.save();
				}
			});

			compat_tool_selected(wine);
		}

		protected void create_options_widget_wine(WineOptions wine_options, Box container)
		{
			var sgrp_prefix = new SettingsGroup(_("Prefix"));

			var prefix_vbox = new Box(Orientation.VERTICAL, 0);
			prefix_vbox.margin_start = prefix_vbox.margin_end = 8;
			prefix_vbox.margin_top = prefix_vbox.margin_bottom = 4;

			var prefix_shared_radio = new RadioButton.with_label_from_widget(null, _("Use shared prefix for all games"));
			var prefix_separate_radio = new RadioButton.with_label_from_widget(prefix_shared_radio, _("Use separate prefix for each game"));
			var prefix_custom_radio = new RadioButton.with_label_from_widget(prefix_shared_radio, _("Use custom prefix"));

			prefix_vbox.add(prefix_shared_radio);
			prefix_vbox.add(prefix_separate_radio);
			prefix_vbox.add(prefix_custom_radio);

			sgrp_prefix.add_setting(new CustomWidgetSetting(prefix_vbox));
			var prefix_custom_path = sgrp_prefix.add_setting(new EntrySetting.bind(_("Prefix path"), null, InlineWidgets.variable_entry(prefix_variables), wine_options.prefix, "custom-path"));

			container.add(sgrp_prefix);

			var sgrp_vdesktop = new SettingsGroup(_("Virtual desktop"));

			var vdesktop_resolution_hbox = new Box(Orientation.HORIZONTAL, 8);
			var vdesktop_resolution_width_spinbutton = new SpinButton.with_range(640, 16384, 100);
			var vdesktop_resolution_height_spinbutton = new SpinButton.with_range(480, 16384, 100);

			vdesktop_resolution_hbox.add(vdesktop_resolution_width_spinbutton);
			vdesktop_resolution_hbox.add(new Label("×"));
			vdesktop_resolution_hbox.add(vdesktop_resolution_height_spinbutton);

			var vdesktop_switch = sgrp_vdesktop.add_setting(new SwitchSetting.bind(_("Emulate a virtual desktop"), null, wine_options.desktop, "enabled"));
			var vdesktop_resolution = sgrp_vdesktop.add_setting(new BaseSetting(_("Resolution"), null, vdesktop_resolution_hbox));

			container.add(sgrp_vdesktop);

			var sgrp_dll_overrides = new SettingsGroup(_("System libraries"));
			sgrp_dll_overrides.add_setting(new SwitchSetting.bind("Gecko", _("HTML rendering engine"), wine_options.libraries, "gecko"));
			sgrp_dll_overrides.add_setting(new SwitchSetting.bind("Mono", _(".NET framework implementation"), wine_options.libraries, "mono"));
			container.add(sgrp_dll_overrides);

			prefix_shared_radio.toggled.connect(() => {
				if(prefix_shared_radio.active)
				{
					wine_options.prefix.default_path = WineOptions.Prefix.DefaultPath.SHARED;
					prefix_custom_path.entry.placeholder_text = wine_options.prefix.path;
				}
			});
			prefix_separate_radio.toggled.connect(() => {
				if(prefix_separate_radio.active)
				{
					wine_options.prefix.default_path = WineOptions.Prefix.DefaultPath.SEPARATE;
					prefix_custom_path.entry.placeholder_text = wine_options.prefix.path;
				}
			});
			prefix_custom_radio.toggled.connect(() => {
				if(prefix_custom_radio.active)
				{
					wine_options.prefix.default_path = WineOptions.Prefix.DefaultPath.CUSTOM;
					prefix_custom_path.entry.placeholder_text = null;
				}
			});

			switch(wine_options.prefix.default_path)
			{
				case WineOptions.Prefix.DefaultPath.SHARED:
					prefix_shared_radio.active = true;
					prefix_custom_path.entry.placeholder_text = wine_options.prefix.path;
					break;
				case WineOptions.Prefix.DefaultPath.SEPARATE:
					prefix_separate_radio.active = true;
					prefix_custom_path.entry.placeholder_text = wine_options.prefix.path;
					break;
				case WineOptions.Prefix.DefaultPath.CUSTOM:
					prefix_custom_radio.active = true;
					prefix_custom_path.entry.placeholder_text = null;
					break;
			}

			prefix_custom_radio.bind_property("active", prefix_custom_path, "sensitive", BindingFlags.SYNC_CREATE);
			vdesktop_switch.switch.bind_property("active", vdesktop_resolution, "sensitive", BindingFlags.SYNC_CREATE);

			wine_options.desktop.bind_property("width", vdesktop_resolution_width_spinbutton, "value", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
			wine_options.desktop.bind_property("height", vdesktop_resolution_height_spinbutton, "value", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
		}

		public override void add_new_tool(Button button)
		{
			var chooser = new FileChooserNative(_("Select Wine executable"), GameHub.UI.Windows.MainWindow.instance, FileChooserAction.OPEN, _("Select"), _("Cancel"));
			if(chooser.run() == ResponseType.ACCEPT)
			{
				var wine_executable = chooser.get_file();
				Tools.Wine.Wine.add_wine_version_from_file(wine_executable, wine_executable.get_parent().get_child("wineserver"));
				update();
			}
		}
	}
}