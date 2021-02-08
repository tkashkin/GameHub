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
using GameHub.UI.Widgets;
using GameHub.Data.Sources.EpicGames;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Sources
{
	public class EpicGames: SettingsDialogPage
	{

		private LegendaryWrapper? legendary_wrapper { get; private set; }
		private Settings.Auth.EpicGames epicgames_auth;
		private GameHub.Data.Sources.EpicGames.EpicGames epic = GameHub.Data.Sources.EpicGames.EpicGames.instance;

		private Button logout_btn;

		public EpicGames(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: "EpicGames",
				description: _("Disabled"),
				icon_name: "source-epicgames-symbolic",
				activatable: true
			);
			status = description;
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.instance;
			epicgames_auth = Settings.Auth.EpicGames.instance;

			status_switch.active = epicgames_auth.enabled;
			status_switch.notify["active"].connect(() => {
				epicgames_auth.enabled = status_switch.active;
				request_restart();
				update();
			});

			logout_btn = new Button.with_label(_("Logout"));
			action_area.add(logout_btn);

			logout_btn.clicked.connect(() => {
				epicgames_auth.authenticated = false;
				epicgames_auth.sid = "";
				request_restart();
				update();
			});

			add_entry("Legendary client command", paths.legendary_command, (command) => {
				paths.legendary_command = command;
			});

			var game_default_folder = (paths.epic_games == null || paths.epic_games == "") ? _("Default") : paths.epic_games;
			add_file_chooser(_("Games directory"), FileChooserAction.SELECT_FOLDER, game_default_folder, v => { paths.epic_games = v; request_restart(); }, false);
			update();
		}

		private void update()
		{
			content_area.sensitive = epicgames_auth.enabled;
			logout_btn.sensitive = epicgames_auth.authenticated;

			if(!epicgames_auth.enabled)
			{
				status = description = _("Disabled");
			}
			else if(!epic.is_installed())
			{
				status = description = _("Missing Legendary");
			}
			else if(!epicgames_auth.authenticated)
			{
				status = description = _("Not authenticated");
			}
			else
			{
				var user_name = GameHub.Data.Sources.EpicGames.EpicGames.instance.user_name;
				status = description = user_name != null ? _("Authenticated as <b>%s</b>").printf(user_name) : _("Authenticated");
			}
		}

	}
}
