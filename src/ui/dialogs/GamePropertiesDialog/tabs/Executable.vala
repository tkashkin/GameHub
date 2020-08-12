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

using GameHub.Data;
using GameHub.Data.Runnables;

using GameHub.Utils;
using GameHub.Utils.FS;

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Tweaks;
using GameHub.UI.Widgets.Settings;

namespace GameHub.UI.Dialogs.GamePropertiesDialog.Tabs
{
	private class Executable: GamePropertiesDialogTab
	{
		public Traits.HasExecutableFile game { get; construct; }

		private ListBox env_variables_list;

		public Executable(Traits.HasExecutableFile game)
		{
			Object(
				game: game,
				title: _("Launch options"),
				orientation: Orientation.VERTICAL
			);
		}

		construct
		{
			var sgrp_executable = new SettingsGroup();
			var executable_setting = sgrp_executable.add_setting(
				new FileSetting(
					_("Executable"), _("Game's main executable file"),
					InlineWidgets.file_chooser(_("Select the main executable file of the game"), FileChooserAction.OPEN, false, null, false, true),
					game.executable != null ? game.executable.get_path() : null
				)
			);
			executable_setting.chooser.file_set.connect(() => game.executable = executable_setting.chooser.file);
			sgrp_executable.add_setting(
				new EntrySetting.bind(
					_("Arguments"), _("Command line arguments passed to the executable"),
					InlineWidgets.entry("utilities-terminal-symbolic"),
					game, "arguments"
				)
			);
			add(sgrp_executable);

			var sgrp_env = new SettingsGroupBox(_("Environment variables"));
			sgrp_env.container.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);

			env_variables_list = new ListBox();
			env_variables_list.selection_mode = SelectionMode.NONE;

			var env_scroll = new ScrolledWindow(null, null);
			env_scroll.hscrollbar_policy = PolicyType.NEVER;
			env_scroll.expand = true;
			env_scroll.add(env_variables_list);

			sgrp_env.add_widget(env_scroll);
			add(sgrp_env);

			update_env_variables();
		}

		private void update_env_variables()
		{
			var rows = env_variables_list.get_children();

			var variables_node = new Json.Node(Json.NodeType.OBJECT);
			var variables_obj = new Json.Object();

			if(rows.length() == 0)
			{
				add_variable();
			}
			else
			{
				foreach(var child in rows)
				{
					var row = (EnvVariableRow) child;
					var variable = row.variable.strip();
					var value = row.value.strip();

					if(variable.length > 0)
					{
						variables_obj.set_string_member(variable, value);

						if(row == rows.last().data)
						{
							add_variable();
						}
					}
				}
			}

			variables_node.set_object(variables_obj);

			debug("[Executable.update_env_variables] %s", Json.to_string(variables_node, false));
		}

		private void add_variable(string? variable = null, string? value = null)
		{
			var row = new EnvVariableRow(variable, value);
			env_variables_list.add(row);
			row.updated.connect(update_env_variables);
			row.destroy.connect(update_env_variables);
		}

		private class EnvVariableRow: ListBoxRow
		{
			public string variable { get; set; default = ""; }
			public string value { get; set; default = ""; }

			public signal void updated();

			private Entry variable_entry;
			private Entry value_entry;

			public EnvVariableRow(string? variable = null, string? value = null)
			{
				Object(variable: variable ?? "", value: value ?? "", activatable: false, selectable: false);
			}

			construct
			{
				get_style_context().add_class("setting");
				get_style_context().add_class("env-variable-setting");

				variable_entry = new Entry();
				variable_entry.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				variable_entry.placeholder_text = _("Variable");
				variable_entry.hexpand = true;

				value_entry = new Entry();
				value_entry.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				value_entry.placeholder_text = _("Value");
				value_entry.hexpand = true;
				value_entry.secondary_icon_name = "edit-delete-symbolic";

				var hbox = new Box(Orientation.HORIZONTAL, 0);
				hbox.add(variable_entry);
				hbox.add(value_entry);

				notify["variable"].connect(() => updated());
				notify["value"].connect(() => updated());
				value_entry.icon_release.connect(() => destroy());

				bind_property("variable", variable_entry, "text", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
				bind_property("value", value_entry, "text", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

				child = hbox;
				show_all();
			}
		}
	}
}
