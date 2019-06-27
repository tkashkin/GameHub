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

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Sources
{
	public class Steam: SettingsDialogPage
	{
		private Settings.Auth.Steam steam_auth;

		public Steam(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				header: _("Game sources"),
				title: "Steam",
				description: _("Disabled"),
				icon_name: "source-steam-symbolic",
				activatable: true
			);
			status = description;
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.instance;

			steam_auth = Settings.Auth.Steam.instance;

			add_steam_apikey_entry();
			add_labeled_link(_("Steam API keys have limited number of uses per day"), _("Generate key"), "steam://openurl/https://steamcommunity.com/dev/apikey");

			add_separator();
			add_file_chooser(_("Installation directory"), FileChooserAction.SELECT_FOLDER, paths.steam_home, v => { paths.steam_home = v; request_restart(); }, false);

			status_switch.active = steam_auth.enabled;
			status_switch.notify["active"].connect(() => {
				steam_auth.enabled = status_switch.active;
				update();
				request_restart();
			});

			update();
		}

		private void update()
		{
			var steam = GameHub.Data.Sources.Steam.Steam.instance;

			content_area.sensitive = steam.enabled;

			if(!steam.enabled)
			{
				status = description = _("Disabled");
			}
			else if(!steam.is_installed())
			{
				status = description = _("Not installed");
			}
			else if(!steam.is_authenticated_in_steam_client)
			{
				status = description = _("Not authenticated");
			}
			else
			{
				status = description = steam.user_name != null ? _("Authenticated as <b>%s</b>").printf(steam.user_name) : _("Authenticated");
			}
		}

		protected void add_steam_apikey_entry()
		{
			var steam_auth = Settings.Auth.Steam.instance;

			var entry = new Entry();
			entry.placeholder_text = _("Default");
			entry.max_length = 32;
			if(steam_auth.api_key != steam_auth.schema.get_default_value("api-key").get_string())
			{
				entry.text = steam_auth.api_key;
			}
			entry.primary_icon_name = "source-steam-symbolic";
			entry.secondary_icon_name = "edit-delete-symbolic";
			entry.secondary_icon_tooltip_text = _("Restore default API key");
			entry.set_size_request(280, -1);

			entry.notify["text"].connect(() => { steam_auth.api_key = entry.text; request_restart(); });
			entry.icon_press.connect((pos, e) => {
				if(pos == EntryIconPosition.SECONDARY)
				{
					entry.text = "";
				}
			});

			var label = new Label(_("Steam API key"));
			label.halign = Align.START;
			label.hexpand = true;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(entry);
			add_widget(hbox);
		}
	}
}
