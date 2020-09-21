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

using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.UI
{
	public class Behavior: SettingsDialogPage
	{
		public Behavior(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Behavior"),
				description: _("Behavior settings"),
				icon_name: "preferences-system"
			);
			status = description;
		}

		construct
		{
			var settings = Settings.UI.Behavior.instance;

			add_switch(_("Run games with double click"), settings.grid_doubleclick, v => { settings.grid_doubleclick = v; });

			add_separator();

			add_switch(_("Merge games from different sources"), settings.merge_games, v => { settings.merge_games = v; request_restart(); });

			add_separator();

			add_switch(_("Use imported tags"), settings.import_tags, v => { settings.import_tags = v; });

			add_separator();

			add_switch(_("Show tray icon"), settings.use_app_indicator, v => {
				settings.use_app_indicator = v;
				if (v)
				{
					Application.app_indicator = new GameHub.UI.Widgets.AppIndicator();
				}
				else
				{
					Application.app_indicator = null;
				}
			});
		}
	}
}
