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

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.UI
{
	public class Behavior: SettingsDialogPage
	{
		public Behavior(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Behavior"),
				status: _("Behavior settings"),
				icon_name: "preferences-system"
			);
		}

		construct
		{
			var ui = Settings.UI.get_instance();

			add_switch(_("Run games with double click"), ui.grid_doubleclick, v => { ui.grid_doubleclick = v; });

			add_separator();

			add_switch(_("Merge games from different sources"), ui.merge_games, v => { ui.merge_games = v; request_restart(); });

			add_separator();

			add_switch(_("Show non-native games"), ui.show_unsupported_games, v => { ui.show_unsupported_games = v; });
			add_switch(_("Use compatibility layers and consider Windows games compatible"), ui.use_compat, v => { ui.use_compat = v; });

			add_separator();

			add_switch(_("Use imported tags"), ui.use_imported_tags, v => { ui.use_imported_tags = v; });
		}
	}
}
