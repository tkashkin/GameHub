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

using GameHub.Data;
using GameHub.Data.Compat;

using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Sources
{
	public class Steam: SettingsDialogPage
	{
		private Settings.Auth.Steam steam_auth = Settings.Auth.Steam.instance;
		private Settings.Paths.Steam steam_paths = Settings.Paths.Steam.instance;

		private SettingsGroup sgrp_proton;

		public Steam(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				header: _("Game sources"),
				title: "Steam",
				icon_name: "source-steam-symbolic",
				has_active_switch: true
			);
		}

		construct
		{
			var steam = GameHub.Data.Sources.Steam.Steam.instance;

			steam_auth.bind_property("enabled", this, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);

			if(steam.user_id != null)
			{
				var sgrp_account = new SettingsGroup();
				var account_link = new LinkButton.with_label("steam://url/SteamIDMyProfile", _("View profile"));
				var account_setting = sgrp_account.add_setting(new BaseSetting(steam.user_name != null ? _("Authenticated as <b>%s</b>").printf(steam.user_name) : _("Authenticated"), steam.user_id, account_link));
				account_setting.icon_name = "avatar-default-symbolic";
				account_setting.activatable = true;
				account_setting.setting_activated.connect(() => account_link.clicked());
				account_link.can_focus = false;
				add_widget(sgrp_account);
			}

			var sgrp_dirs = new SettingsGroup();
			sgrp_dirs.add_setting(
				new FileSetting.bind(
					_("Installation directory"), null,
					InlineWidgets.file_chooser(_("Select Steam installation directory"), FileChooserAction.SELECT_FOLDER),
					steam_paths, "home"
				)
			);
			sgrp_dirs.add_setting(
				new DirectoriesMenuSetting.paths(
					_("Steam library directories"),
					_("Steam library directories that are configured in the Steam client"),
					GameHub.Data.Sources.Steam.Steam.LibraryFolders
				)
			);
			add_widget(sgrp_dirs);

			var sgrp_api_key = new SettingsGroup();
			sgrp_api_key.add_setting(new EntrySetting(_("API key"), null, get_steam_apikey_entry()));
			sgrp_api_key.add_setting(new LinkLabelSetting(_("Provide your API key to access private Steam profile or if default key does not work"), _("Generate key"), "steam://openurl/https://steamcommunity.com/dev/apikey"));
			add_widget(sgrp_api_key);

			sgrp_proton = new SettingsGroup("Proton");
			add_widget(sgrp_proton);

			notify["active"].connect(() => {
				update();
				//request_restart();
			});

			update();
		}

		private void update()
		{
			sgrp_proton.settings.foreach(r => {
				if(r != null) r.destroy();
			});

			foreach(var tool in CompatTools)
			{
				if(tool is Proton)
				{
					var proton = tool as Proton;
					if(proton != null && !proton.is_latest)
					{
						Button? install = null;
						var description = _("Not installed");
						if(proton.installed && proton.executable != null)
						{
							description = proton.executable.get_path();
						}
						else
						{
							install = new Button.with_label(_("Install"));
							install.clicked.connect(() => {
								install.sensitive = false;
								request_restart();
								proton.install_app();
							});
						}
						sgrp_proton.add_setting(new BaseSetting("""%s<span alpha="75%"> • %s</span>""".printf(proton.name, proton.appid), description, install)).icon_name = proton.icon;
					}
				}
			}

			sgrp_proton.show_all();
		}

		private Entry get_steam_apikey_entry()
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
			entry.set_size_request(InlineWidgets.ENTRY_WIDTH, -1);

			entry.notify["text"].connect(() => { steam_auth.api_key = entry.text; request_restart(); });
			entry.icon_press.connect((pos, e) => {
				if(pos == EntryIconPosition.SECONDARY)
				{
					entry.text = "";
				}
			});

			return entry;
		}
	}
}
