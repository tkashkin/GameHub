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
	public class Itch: SettingsDialogPage
	{
		private Settings.Auth.Itch itch_auth;

		public Itch(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: "itch.io",
				description: _("Disabled"),
				icon_name: "source-itch-symbolic",
				activatable: true
			);
			status = description;
		}

		construct
		{
			var paths = FSUtils.Paths.Settings.instance;

			itch_auth = Settings.Auth.Itch.instance;

			add_apikey_entry();
			add_link(_("Generate key"), "https://itch.io/api-keys");

			add_separator();

			add_file_chooser(_("Installation directory"), FileChooserAction.SELECT_FOLDER, paths.itch_home, v => { paths.itch_home = v; request_restart(); }, false);

			status_switch.active = itch_auth.enabled;
			status_switch.notify["active"].connect(() => {
				itch_auth.enabled = status_switch.active;
				update();
				request_restart();
			});

			update();
		}

		private void update()
		{
			var itch = GameHub.Data.Sources.Itch.Itch.instance;

			content_area.sensitive = itch.enabled;

			if(!itch.enabled)
			{
				status = description = _("Disabled");
			}
			else if(!itch.is_installed())
			{
				status = description = _("Not installed");
			}
			else if(!itch.is_authenticated())
			{
				status = description = _("Not authenticated");
			}
			else
			{
				status = description = itch.user_name != null ? _("Authenticated as <b>%s</b>").printf(itch.user_name) : _("Authenticated");
			}
		}

		protected void add_apikey_entry()
		{
			var itch_auth = Settings.Auth.Itch.instance;

			var entry = new Entry();
			entry.max_length = 40;
			if(itch_auth.api_key != itch_auth.schema.get_default_value("api-key").get_string())
			{
				entry.text = itch_auth.api_key;
			}
			entry.primary_icon_name = "source-itch-symbolic";
			entry.set_size_request(280, -1);

			entry.notify["text"].connect(() => { itch_auth.api_key = entry.text; request_restart(); });

			var label = new Label(_("API key"));
			label.halign = Align.START;
			label.hexpand = true;

			var hbox = new Box(Orientation.HORIZONTAL, 12);
			hbox.add(label);
			hbox.add(entry);
			add_widget(hbox);
		}
	}
}
