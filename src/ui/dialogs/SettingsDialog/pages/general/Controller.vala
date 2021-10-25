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
using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.General
{
	public class Controller: SettingsDialogPage
	{
		private Settings.Controller settings;
		private SettingsGroup sgrp_controllers;
		private Grid shortcuts_grid;

		public Controller(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Controller"),
				icon_name: "gamehub-symbolic",
				has_active_switch: Gamepad.is_supported()
			);
		}

		construct
		{
			settings = Settings.Controller.instance;

			if(has_active_switch)
			{
				settings.bind_property("enabled", this, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

				var sgrp_controller_options = new SettingsGroup();
				sgrp_controller_options.add_setting(new SwitchSetting.bind(_("Focus GameHub window with Guide button"), null, settings, "focus-window"));
				add_widget(sgrp_controller_options);

				sgrp_controllers = new SettingsGroup(_("Controllers"));
				add_widget(sgrp_controllers);

				shortcuts_grid = add_widget(new Grid());
				shortcuts_grid.valign = Align.END;
				shortcuts_grid.column_spacing = 12;
				shortcuts_grid.margin_top = 12;
				shortcuts_grid.margin_start = 18;
				shortcuts_grid.margin_end = 18;
				shortcuts_grid.margin_bottom = 6;
				shortcuts_grid.expand = true;

				add_shortcut(0, 0, _("Move focus"), "trigger-left", "/", "trigger-right");
				shortcuts_grid.add(new Separator(Orientation.VERTICAL));
				add_shortcut(2, 0, _("Quit GameHub"), "guide", "+", "b");

				update();
			}
			else
			{
				var xorg_warning = new AlertView(_("Controllers are not supported"), _("GameHub currently only supports controllers when running under X.Org display server"), "dialog-warning-symbolic");
				xorg_warning.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);
				add_widget(xorg_warning);
			}
		}

		private void update()
		{
			sgrp_controllers.settings.foreach(r => {
				if(r != null) r.destroy();
			});

			if(settings.known_controllers.length == 0)
			{
				sgrp_controllers.add_setting(new LabelSetting(_("No controllers detected. Connected controllers will appear here")));
			}
			else
			{
				foreach(var controller in settings.known_controllers)
				{
					sgrp_controllers.add_setting(new ControllerSetting(controller, !(controller in settings.ignored_controllers), this));
				}
			}
		}

		private class ControllerSetting: SwitchSetting, ActivatableSetting
		{
			public string controller { get; construct; }
			public bool enabled { get; construct set; }

			public Controller page { get; construct; }

			public ControllerSetting(string controller, bool enabled, Controller page)
			{
				Object(controller: controller, enabled: enabled, page: page, title: controller, widget: new Switch(), activatable: true, selectable: false);
			}

			construct
			{
				get_style_context().add_class("controller-setting");
				icon_name = "gamehub-symbolic";

				@switch.can_focus = false;
				bind_property("enabled", @switch, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

				notify["enabled"].connect(() => {
					var settings = Settings.Controller.instance;
					var ignored = settings.ignored_controllers;
					if(enabled && controller in ignored)
					{
						string[] new_controllers = {};
						foreach(var c in ignored)
						{
							if(c != controller) new_controllers += c;
						}
						settings.ignored_controllers = new_controllers;
						page.request_restart();
					}
					else if(!enabled && !(controller in ignored))
					{
						ignored += controller;
						settings.ignored_controllers = ignored;
						page.request_restart();
					}
				});
			}
		}

		private void add_shortcut(int x, int y, string action, ...)
		{
			var buttons = va_list();

			var label = new Label(action);
			label.halign = Align.START;
			label.hexpand = true;

			var bbox = new Box(Orientation.HORIZONTAL, 8);
			bbox.halign = Align.END;

			for(string? btn = buttons.arg<string?>(); btn != null; btn = buttons.arg<string?>())
			{
				if(btn == "+" || btn == "/" || btn == ",")
				{
					bbox.add(new Label(btn));
				}
				else
				{
					var image = new Image.from_icon_name("controller-button-" + btn, IconSize.LARGE_TOOLBAR);
					bbox.add(image);
				}
			}

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(bbox);

			shortcuts_grid.attach(hbox, x, y);
		}
	}
}
