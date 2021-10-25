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
using GameHub.UI.Widgets.Compat;
using GameHub.UI.Widgets.Settings;

using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.General
{
	public class CompatTools: SettingsDialogPage
	{
		public CompatTools(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Compatibility layers"),
				icon_name: "application-x-executable-symbolic"
			);
		}

		construct
		{
			var sgrp_compat = new SettingsGroupBox();
			sgrp_compat.container.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);
			sgrp_compat.add_widget(new CompatToolsList());
			add_widget(sgrp_compat);
		}
	}
}
