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

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Sources
{
	public class GOG: SettingsDialogPage
	{
		private Settings.Auth.GOG gog_auth = Settings.Auth.GOG.instance;
		private Settings.Paths.GOG gog_paths = Settings.Paths.GOG.instance;

		private Button logout_btn;
		private DirectoriesList game_dirs_list;

		public GOG(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: "GOG",
				description: _("Disabled"),
				icon_name: "source-gog-symbolic",
				activatable: true
			);
			status = description;
		}

		construct
		{
			root_grid.margin = 0;
			header_grid.margin = 12;
			content_area.margin = 0;

			action_area.margin = 12;
			action_area.margin_top = 0;

			var game_dirs_header = add_header(_("Game directories"));
			game_dirs_header.margin_start = game_dirs_header.margin_end = 12;

			var game_dirs_list = add_widget(new DirectoriesList.with_array(gog_paths.game_directories, gog_paths.default_game_directory, null, false));

			game_dirs_list.margin_start = 7;
			game_dirs_list.margin_end = 3;
			game_dirs_list.margin_top = 0;
			game_dirs_list.margin_bottom = 0;

			game_dirs_list.notify["directories"].connect(() => {
				warning("[dirs] '%s'", string.joinv("', '", game_dirs_list.directories_array));
				gog_paths.game_directories = game_dirs_list.directories_array;
			});

			game_dirs_list.directory_selected.connect(dir => {
				gog_paths.default_game_directory = dir;
			});

			status_switch.active = gog_auth.enabled;
			status_switch.notify["active"].connect(() => {
				gog_auth.enabled = status_switch.active;
				request_restart();
				update();
			});

			logout_btn = new Button.with_label(_("Logout"));
			action_area.add(logout_btn);

			logout_btn.clicked.connect(() => {
				gog_auth.authenticated = false;
				gog_auth.access_token = "";
				gog_auth.refresh_token = "";
				request_restart();
				update();
			});

			update();
		}

		private void update()
		{
			content_area.sensitive = gog_auth.enabled;
			logout_btn.sensitive = gog_auth.authenticated && gog_auth.access_token.length > 0;

			/*if(" " in FS.Paths.Settings.instance.gog_games)
			{
				games_dir_chooser.get_style_context().add_class(Gtk.STYLE_CLASS_ERROR);
				status_type = StatusType.ERROR;
			}
			else
			{
				games_dir_chooser.get_style_context().remove_class(Gtk.STYLE_CLASS_ERROR);
				status_type = restart_requested ? StatusType.WARNING : StatusType.NONE;
			}
			dialog.update_games_dir_space_message();*/

			if(!gog_auth.enabled)
			{
				status = description = _("Disabled");
			}
			else if(!gog_auth.authenticated || gog_auth.access_token.length == 0)
			{
				status = description = _("Not authenticated");
			}
			else
			{
				var user_name = GameHub.Data.Sources.GOG.GOG.instance.user_name;
				status = description = user_name != null ? _("Authenticated as <b>%s</b>").printf(user_name) : _("Authenticated");
			}
		}
	}
}
