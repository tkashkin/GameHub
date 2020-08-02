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
	public class Humble: SettingsDialogPage
	{
		private Settings.Auth.Humble humble_auth = Settings.Auth.Humble.instance;
		private Settings.Paths.Humble humble_paths = Settings.Paths.Humble.instance;

		private Button? logout_btn;

		public Humble(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: "Humble Bundle",
				description: _("Disabled"),
				icon_name: "source-humble-symbolic",
				has_active_switch: true
			);
		}

		construct
		{
			humble_auth.bind_property("enabled", this, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

			if(humble_auth.access_token != null)
			{
				var sgrp_account = new SettingsGroup();

				var account_actions_box = new Box(Orientation.HORIZONTAL, 12);
				logout_btn = new Button.from_icon_name("system-log-out-symbolic", IconSize.BUTTON);
				logout_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
				logout_btn.tooltip_text = _("Logout");
				logout_btn.clicked.connect(() => {
					humble_auth.authenticated = false;
					humble_auth.access_token = "";
					request_restart();
					update();
				});
				var account_link = new LinkButton.with_label("https://humblebundle.com/home/library", _("View library"));
				account_actions_box.add(logout_btn);
				account_actions_box.add(account_link);

				var account_setting = sgrp_account.add_setting(new BaseSetting(_("Authenticated"), null, account_actions_box));
				account_setting.icon_name = "avatar-default-symbolic";
				account_setting.activatable = true;
				account_setting.setting_activated.connect(() => account_link.clicked());
				account_link.can_focus = false;
				add_widget(sgrp_account);
			}

			var sgrp_trove = new SettingsGroup();
			sgrp_trove.add_setting(new SwitchSetting.bind(_("Import games from Humble Trove"), _("Humble Trove requires an active subscription to use"), humble_auth, "load-trove-games"));
			add_widget(sgrp_trove);

			var sgrp_game_dirs = new SettingsGroupBox(_("Game directories"));
			var game_dirs_list = sgrp_game_dirs.add_widget(new DirectoriesList.with_array(humble_paths.game_directories, humble_paths.default_game_directory, null, false));
			add_widget(sgrp_game_dirs);

			game_dirs_list.notify["directories"].connect(() => {
				humble_paths.game_directories = game_dirs_list.directories_array;
			});

			game_dirs_list.directory_selected.connect(dir => {
				humble_paths.default_game_directory = dir;
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
				logout_btn.sensitive = humble_auth.authenticated && humble_auth.access_token.length > 0;
			}

			/*if(" " in FS.Paths.Settings.instance.humble_games)
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
