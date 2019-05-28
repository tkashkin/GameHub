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

		public Controller(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Controller"),
				icon_name: "gamehub-symbolic",
				activatable: true
			);
		}

		construct
		{
			settings = Settings.Controller.get_instance();

			add_switch(_("Focus GameHub window with Guide button"), settings.focus_window, v => { settings.focus_window = v; update(); request_restart(); });

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
			status = settings.enabled ? _("Enabled") : _("Disabled");
		}
	}
}
