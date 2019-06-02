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
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Sources
{
	public class GOG: SettingsDialogPage
	{
		private Settings.Auth.GOG gog_auth;
		private Button logout_btn;
		private FileChooserEntry games_dir_chooser;

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
			var paths = FSUtils.Paths.Settings.get_instance();

			gog_auth = Settings.Auth.GOG.get_instance();

			games_dir_chooser = add_file_chooser(_("Games directory"), FileChooserAction.SELECT_FOLDER, paths.gog_games, v => { paths.gog_games = v; request_restart(); update(); }).get_children().last().data as FileChooserEntry;

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

			if(" " in FSUtils.Paths.Settings.get_instance().gog_games)
			{
				games_dir_chooser.get_style_context().add_class(Gtk.STYLE_CLASS_ERROR);
				status_type = StatusType.ERROR;
			}
			else
			{
				games_dir_chooser.get_style_context().remove_class(Gtk.STYLE_CLASS_ERROR);
				status_type = restart_requested ? StatusType.WARNING : StatusType.NONE;
			}
			dialog.update_games_dir_space_message();

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
