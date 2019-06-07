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
using Granite;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.General
{
	public class Controller: SettingsDialogPage
	{
		private Settings.Controller settings;
		private ListBox controllers;
		private Grid shortcuts_grid;

		public Controller(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Controller"),
				description: _("Enabled"),
				icon_name: "gamehub-symbolic",
				activatable: true
			);
			status = description;
		}

		construct
		{
			root_grid.margin = 0;
			header_grid.margin = 12;
			header_grid.margin_bottom = 0;
			content_area.margin = 0;

			settings = Settings.Controller.get_instance();

			var focus_switch = add_switch(_("Focus GameHub window with Guide button"), settings.focus_window, v => { settings.focus_window = v; update(); request_restart(); });
			focus_switch.margin_start = 16;
			focus_switch.margin_end = 12;

			var controllers_header = add_header(_("Controllers"));
			controllers_header.margin_start = controllers_header.margin_end = 12;

			controllers = add_widget(new ListBox());
			controllers.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			controllers.expand = true;

			controllers.margin_start = 7;
			controllers.margin_end = 3;
			controllers.margin_top = 0;
			controllers.margin_bottom = 6;

			shortcuts_grid = add_widget(new Grid());
			shortcuts_grid.column_spacing = 12;
			shortcuts_grid.margin_start = 16;
			shortcuts_grid.margin_end = 12;

			add_shortcut(0, 0, _("Move focus"), "trigger-left", "/", "trigger-right");
			shortcuts_grid.add(new Separator(Orientation.VERTICAL));
			add_shortcut(2, 0, _("Exit"), "guide", "+", "b");

			status_switch.active = settings.enabled;
			status_switch.notify["active"].connect(() => {
				settings.enabled = status_switch.active;
				update();
				request_restart();
			});

			update();
		}

		private void update()
		{
			content_area.sensitive = settings.enabled;
			status = description = settings.enabled ? _("Enabled") : _("Disabled");

			controllers.foreach(r => {
				if(r != null) r.destroy();
			});

			foreach(var controller in settings.known_controllers)
			{
				controllers.add(new ControllerRow(controller, !(controller in settings.ignored_controllers), this));
			}
		}

		private class ControllerRow: ListBoxRow
		{
			public string controller { get; construct; }
			public bool enabled { get; construct set; }

			public Controller page { get; construct; }

			public ControllerRow(string controller, bool enabled, Controller page)
			{
				Object(controller: controller, enabled: enabled, page: page);
			}

			construct
			{
				var settings = Settings.Controller.get_instance();

				var hbox = new Box(Orientation.HORIZONTAL, 8);
				hbox.margin_start = hbox.margin_end = 8;
				hbox.margin_top = hbox.margin_bottom = 4;

				var icon = new Image.from_icon_name("gamehub-symbolic", IconSize.SMALL_TOOLBAR);
				icon.valign = Align.CENTER;

				var name = new Label(controller);
				name.get_style_context().add_class("category-label");
				name.hexpand = true;
				name.xalign = 0;
				name.valign = Align.CENTER;

				var enabled_switch = new Switch();
				enabled_switch.active = enabled;
				enabled_switch.valign = Align.CENTER;

				hbox.add(icon);
				hbox.add(name);
				hbox.add(enabled_switch);

				child = hbox;

				enabled_switch.notify["active"].connect(() => {
					enabled = enabled_switch.active;
				});

				notify["enabled"].connect(() => {
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
