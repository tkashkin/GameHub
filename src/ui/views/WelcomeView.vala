/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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
using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Views
{
	public class WelcomeView: BaseView
	{
		private Stack stack;
		private Granite.Widgets.AlertView empty_alert;
		private Granite.Widgets.Welcome welcome;

		private Button skip_btn;
		private Button settings;

		private bool is_updating = false;

		construct
		{
			var ui_settings = GameHub.Settings.UI.get_instance();

			stack = new Stack();
			stack.transition_type = StackTransitionType.CROSSFADE;

			var spinner = new Spinner();
			spinner.active = true;
			spinner.set_size_request(36, 36);
			spinner.halign = Align.CENTER;
			spinner.valign = Align.CENTER;
			stack.add(spinner);

			empty_alert = new Granite.Widgets.AlertView(_("No enabled game sources"), _("Enable some game sources in settings"), "dialog-warning");
			empty_alert.show_action(_("Settings"));

			stack.add(empty_alert);

			welcome = new Granite.Widgets.Welcome(_("All your games in one place"), _("Let's get started"));

			welcome.activated.connect(index => {
				on_entry_clicked.begin(index);
			});

			stack.add(welcome);

			add(stack);

			titlebar.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			welcome.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);
			empty_alert.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);

			skip_btn = new Button.with_label(_("Skip"));
			skip_btn.clicked.connect(open_games_view);
			skip_btn.halign = Align.CENTER;
			skip_btn.valign = Align.CENTER;

			settings = new Button();
			settings.tooltip_text = _("Settings");
			settings.image = new Image.from_icon_name("open-menu", IconSize.LARGE_TOOLBAR);

			settings.clicked.connect(() => new Dialogs.SettingsDialog.SettingsDialog());
			empty_alert.action_activated.connect(() => settings.clicked());

			titlebar.pack_end(settings);
			titlebar.pack_end(skip_btn);

			settings.opacity = 0;
			settings.sensitive = false;
			skip_btn.opacity = 0;
			skip_btn.sensitive = false;

			foreach(var src in GameSources)
			{
				welcome.append(src.icon, src.name, "");
			}

			update_entries.begin();
		}

		public override void on_window_focus()
		{
			update_entries.begin();
		}

		private void open_games_view()
		{
			window.add_view(new GamesView.GamesView());
		}

		private async void update_entries()
		{
			if(is_updating) return;
			is_updating = true;

			skip_btn.sensitive = false;
			var all_authenticated = true;
			int enabled_sources = 0;

			for(int index = 0; index < GameSources.length; index++)
			{
				var src = GameSources[index];

				var btn = welcome.get_button_from_index(index);

				welcome.set_item_visible(index, !(src is Sources.Humble.Trove) && !(src is Sources.User.User) && src.enabled);

				if(src is Sources.Humble.Trove || src is Sources.User.User || !src.enabled) continue;
				enabled_sources++;

				if(src.is_installed(true))
				{
					btn.title = src.name;

					if(src.is_authenticated())
					{
						btn.description = _("Ready");
						welcome.set_item_sensitivity(index, false);
						skip_btn.sensitive = true;
					}
					else
					{
						btn.description = _("Authentication required") + src.auth_description;
						all_authenticated = false;

						if(src.can_authenticate_automatically())
						{
							btn.description = _("Authenticating...");
							welcome.set_item_sensitivity(index, false);
							yield src.authenticate();
							is_updating = false;
							update_entries.begin();
							return;
						}
					}
				}
				else
				{
					btn.title = _("Install %s").printf(src.name);
					btn.description = _("Return to GameHub after installing");
					all_authenticated = false;
				}
			}

			if(enabled_sources > 0 && all_authenticated)
			{
				Idle.add(() => { open_games_view(); return false; });
				return;
			}

			if(enabled_sources == 0)
			{
				settings.opacity = 0;
				settings.sensitive = false;
				skip_btn.opacity = 0;
				stack.set_visible_child(empty_alert);
				empty_alert.show_all();
			}
			else
			{
				settings.opacity = 1;
				settings.sensitive = true;
				skip_btn.opacity = 1;
				stack.set_visible_child(welcome);
				welcome.show_all();
			}

			is_updating = false;
		}

		private async void on_entry_clicked(int index)
		{
			welcome.set_item_sensitivity(index, false);

			GameSource src = GameSources[index];
			var installed = src.is_installed();

			if(installed)
			{
				if(!src.is_authenticated())
				{
					if(!(yield src.authenticate()))
					{
						welcome.set_item_sensitivity(index, true);
						return;
					}
				}
				yield update_entries();
			}
			else
			{
				yield src.install();
				welcome.set_item_sensitivity(index, true);
			}
		}
	}
}
