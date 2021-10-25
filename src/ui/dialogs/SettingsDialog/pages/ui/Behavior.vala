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

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.UI
{
	public class Behavior: SettingsDialogPage
	{
		public Behavior(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Behavior"),
				icon_name: "gh-settings-cog-symbolic"
			);
		}

		construct
		{
			var settings = Settings.UI.Behavior.instance;

			var sgrp_ui = new SettingsGroup();
			sgrp_ui.add_setting(new SwitchSetting.bind(_("Run games with double click"), null, settings, "grid-doubleclick"));
			sgrp_ui.add_setting(new SwitchSetting.bind(_("Merge games from different sources"), _("Merge games with matching names into one entry"), settings, "merge-games"));
			add_widget(sgrp_ui);

			var sgrp_tags = new SettingsGroup(_("Tags"));
			sgrp_tags.add_setting(new SwitchSetting.bind(_("Import tags from sources"), null, settings, "import-tags"));
			add_widget(sgrp_tags);

			var sgrp_system = new SettingsGroup(_("System"));
			sgrp_system.add_setting(new SwitchSetting.bind(_("Inhibit screensaver while game is running"), _("Request session manager to prevent suspending while game is running"), settings, "inhibit-screensaver"));
			add_widget(sgrp_system);
		}
	}
}
