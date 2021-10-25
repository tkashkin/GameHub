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
using GameHub.UI.Widgets.Tweaks;

using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.General
{
	public class Tweaks: SettingsDialogPage
	{
		public Tweaks(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Tweaks"),
				icon_name: "gh-settings-cogs-symbolic"
			);
		}

		construct
		{
			var sgrp_tweaks = new SettingsGroupBox();
			sgrp_tweaks.container.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);
			sgrp_tweaks.add_widget(new TweaksList());
			add_widget(sgrp_tweaks);

			var sgrp_dirs = new SettingsGroup();
			sgrp_dirs.add_setting(
				new DirectoriesMenuSetting(
					_("Tweak directories"),
					_("Tweaks are loaded from the listed directories in order\nLast tweak overrides previous tweaks with the same id"),
					FS.get_data_dirs("tweaks", true)
				)
			);
			add_widget(sgrp_dirs);
		}
	}
}
