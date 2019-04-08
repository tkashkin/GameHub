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

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class Controller: SettingsDialogTab
	{
		private Settings.Controller settings;
		private Box enabled_box;

		public Controller(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			settings = Settings.Controller.get_instance();

			enabled_box = add_switch(_("Enable controller support"), settings.enabled, v => { settings.enabled = v; update(); dialog.show_restart_message(); });
			add_switch(_("Focus GameHub window with Guide button"), settings.focus_window, v => { settings.focus_window = v; update(); dialog.show_restart_message(); });

			update();
		}

		private void update()
		{
			this.foreach(w => {
				if(w != enabled_box) w.sensitive = settings.enabled;
			});
		}
	}
}
