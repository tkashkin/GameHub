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

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Emulators
{
	public class RetroArch: SettingsDialogPage
	{
		private Settings.Compat.RetroArch settings;

		public RetroArch(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				header: _("Emulators"),
				description: _("Not installed"),
				title: "RetroArch",
				icon_name: "emu-retroarch-symbolic"
			);
			status = description;
		}

		construct
		{
			settings = Settings.Compat.RetroArch.instance;

			add_file_chooser(_("Libretro core directory"), FileChooserAction.SELECT_FOLDER, settings.core_dir, v => { settings.core_dir = v; update(); request_restart(); });
			add_file_chooser(_("Libretro core info directory"), FileChooserAction.SELECT_FOLDER, settings.core_info_dir, v => { settings.core_info_dir = v; request_restart(); });

			add_separator();

			add_header(_("Ignored libretro cores"));
			var cores_blacklist = add_entry(null, settings.cores_blacklist, v => { settings.cores_blacklist = v; update(); }, "application-x-executable-symbolic").get_children().last().data as Entry;
			cores_blacklist.placeholder_text = settings.schema.get_default_value("cores-blacklist").get_string();

			add_header(_("Ignored game file extensions"));
			var game_executable_extensions_blacklist = add_entry(null, settings.game_executable_extensions_blacklist, v => { settings.game_executable_extensions_blacklist = v; update(); }, "package-x-generic-symbolic").get_children().last().data as Entry;
			game_executable_extensions_blacklist.placeholder_text = settings.schema.get_default_value("game-executable-extensions-blacklist").get_string();

			update();
		}

		private void update()
		{
			var retroarch = GameHub.Data.Compat.RetroArch.instance;
			if(retroarch.installed)
			{
				status = description = _("No cores found");
				if(retroarch.has_cores)
				{
					var cores = retroarch.cores.size;
					status = description = ngettext("%u core found", "%u cores found", cores).printf(cores);
				}
			}
			else
			{
				status = description = _("Not installed");
			}
		}
	}
}
