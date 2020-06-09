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

using GameHub.Data;
using GameHub.Data.Compat;

using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.Sources
{
	public class Steam: SettingsDialogPage
	{
		private Settings.Auth.Steam steam_auth;

		private ListBox proton;

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
			root_grid.margin = 0;
			header_grid.margin = 12;
			header_grid.margin_bottom = 0;
			content_area.margin = 0;

			var paths = FSUtils.Paths.Settings.instance;

			steam_auth = Settings.Auth.Steam.instance;

			add_steam_apikey_entry();
			adjust_margins(add_labeled_link(_("Steam API keys have limited number of uses per day"), _("Generate key"), "steam://openurl/https://steamcommunity.com/dev/apikey"));

			adjust_margins(add_separator());

			adjust_margins(add_file_chooser(_("Installation directory"), FileChooserAction.SELECT_FOLDER, paths.steam_home, v => { paths.steam_home = v; request_restart(); }, false));

			var proton_header = add_header("Proton");
			proton_header.margin_start = proton_header.margin_end = 12;

			var proton_scroll = add_widget(new ScrolledWindow(null, null));
			proton_scroll.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			proton_scroll.hscrollbar_policy = PolicyType.NEVER;

			proton_scroll.margin_start = 7;
			proton_scroll.margin_end = 3;
			proton_scroll.margin_top = 0;
			proton_scroll.margin_bottom = 6;

			proton = new ListBox();
			proton.selection_mode = SelectionMode.NONE;
			proton.get_style_context().add_class("separated-list");

			proton_scroll.add(proton);

			#if GTK_3_22
			proton_scroll.propagate_natural_width = true;
			proton_scroll.propagate_natural_height = true;
			#else
			proton_scroll.expand = true;
			#endif

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

			proton.foreach(r => {
				if(r != null) r.destroy();
			});

			foreach(var tool in CompatTools)
			{
				if(tool is Proton)
				{
					var p = tool as Proton;
					if(p != null && !p.is_latest)
					{
						proton.add(new ProtonRow(p, this));
					}
				}
			}

			proton.show_all();
		}

		private class ProtonRow: ListBoxRow
		{
			public Proton proton { get; construct; }

			public Steam page { private get; construct; }

			public ProtonRow(Proton proton, Steam page)
			{
				Object(proton: proton, page: page);
			}

			construct
			{
				var grid = new Grid();
				grid.column_spacing = 12;
				grid.margin_start = grid.margin_end = 8;
				grid.margin_top = grid.margin_bottom = 4;

				var icon = new Image.from_icon_name("source-steam-symbolic", IconSize.LARGE_TOOLBAR);
				icon.valign = Align.CENTER;

				var name = new Label(proton.name);
				name.get_style_context().add_class("category-label");
				name.set_size_request(96, -1);
				name.hexpand = false;
				name.xalign = 0;
				name.valign = Align.CENTER;

				var appid = new Label(proton.appid);
				appid.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				appid.hexpand = true;
				appid.xalign = 0;
				appid.valign = Align.CENTER;

				var status = new Label(_("Not installed"));
				status.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				status.hexpand = true;
				status.ellipsize = Pango.EllipsizeMode.MIDDLE;
				status.xalign = 0;
				status.valign = Align.CENTER;

				var install = new Button.with_label(_("Install"));
				install.valign = Align.CENTER;
				install.sensitive = false;

				grid.attach(icon, 0, 0, 1, 2);
				grid.attach(name, 1, 0);
				grid.attach(appid, 2, 0);
				grid.attach(status, 1, 1, 2, 1);

				if(proton.installed && proton.executable != null)
				{
					status.label = status.tooltip_text = proton.executable.get_path();
				}
				else
				{
					install.sensitive = true;
					grid.attach(install, 3, 0, 1, 2);

					install.clicked.connect(() => {
						install.sensitive = false;
						page.request_restart();
						
						try
						{
							proton.install_app();
						}
						catch(Utils.RunError error)
						{
							//FIXME [DEV-ART]: Replace this with inline error display?
							GameHub.UI.Dialogs.QuickErrorDialog.display_and_log.begin(
								this, error, Log.METHOD,
								_("Installing Proton failed")
							);
						}
					});
				}

				child = grid;
			}
		}

		protected Box add_steam_apikey_entry()
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

			adjust_margins(hbox);

			return hbox;
		}

		private void adjust_margins(Widget w)
		{
			w.margin_start = 16;
			w.margin_end = 12;
		}
	}
}
