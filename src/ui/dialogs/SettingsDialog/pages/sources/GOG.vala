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
using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Sources
{
	public class GOG: SettingsDialogPage
	{
		private Settings.Auth.GOG gog_auth = Settings.Auth.GOG.instance;
		private Settings.Paths.GOG gog_paths = Settings.Paths.GOG.instance;

		private Button? logout_btn;

		public GOG(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: "GOG",
				icon_name: "source-gog-symbolic",
				has_active_switch: true
			);
		}

		construct
		{
			var gog = GameHub.Data.Sources.GOG.GOG.instance;

			gog_auth.bind_property("enabled", this, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

			if(gog.user_id != null)
			{
				var sgrp_account = new SettingsGroup();

				var account_actions_box = new Box(Orientation.HORIZONTAL, 12);
				logout_btn = new Button.from_icon_name("system-log-out-symbolic", IconSize.BUTTON);
				logout_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				logout_btn.tooltip_text = _("Logout");
				logout_btn.clicked.connect(() => {
					gog_auth.authenticated = false;
					gog_auth.access_token = "";
					gog_auth.refresh_token = "";
					request_restart();
					update();
				});
				var account_link = new LinkButton.with_label("https://gog.com/u/%s".printf(gog.user_name), _("View profile"));
				account_actions_box.add(logout_btn);
				account_actions_box.add(account_link);

				var account_setting = sgrp_account.add_setting(new BaseSetting(gog.user_name != null ? _("Authenticated as <b>%s</b>").printf(gog.user_name) : _("Authenticated"), gog.user_id, account_actions_box));
				account_setting.icon_name = "avatar-default-symbolic";
				account_setting.activatable = true;
				account_setting.setting_activated.connect(() => account_link.clicked());
				account_link.can_focus = false;
				add_widget(sgrp_account);
			}

			var sgrp_game_dirs = new SettingsGroupBox(_("Game directories"));
			var game_dirs_list = sgrp_game_dirs.add_widget(new DirectoriesList.with_array(gog_paths.game_directories, gog_paths.default_game_directory, null, false));
			add_widget(sgrp_game_dirs);

			game_dirs_list.notify["directories"].connect(() => {
				gog_paths.game_directories = game_dirs_list.directories_array;
			});

			game_dirs_list.directory_selected.connect(dir => {
				gog_paths.default_game_directory = dir;
			});

			notify["active"].connect(() => {
				//request_restart();
				update();
			});

			update();
		}

		private void update()
		{
			if(logout_btn != null)
			{
				logout_btn.sensitive = gog_auth.authenticated && gog_auth.access_token.length > 0;
			}

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
		}
	}
}
