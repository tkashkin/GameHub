/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class RetroArch: SettingsDialogTab
	{
		public RetroArch(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.get_instance();

			add_file_chooser(_("Libretro core directory"), FileChooserAction.SELECT_FOLDER, paths.libretro_core_dir, v => { paths.libretro_core_dir = v; dialog.show_restart_message(); });
			add_file_chooser(_("Libretro core info directory"), FileChooserAction.SELECT_FOLDER, paths.libretro_core_info_dir, v => { paths.libretro_core_info_dir = v; dialog.show_restart_message(); });
		}

	}
}
