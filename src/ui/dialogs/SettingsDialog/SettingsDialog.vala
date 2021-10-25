/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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

namespace GameHub.UI.Dialogs.SettingsDialog
{
	public class SettingsDialog: Dialog
	{
		private static bool restart_msg_shown = false;
		private static bool games_dir_space_msg_shown = false;

		private HeaderBar headerbar;
		private Switch headerbar_page_active_switch;

		private InfoBar restart_msg;
		private InfoBar games_dir_space_msg;

		private Stack pages;

		private string default_page;

		public SettingsDialog(string page="ui/appearance")
		{
			Object(transient_for: Windows.MainWindow.instance, resizable: false, use_header_bar: 1, title: _("Settings"));
			default_page = page;
		}

		construct
		{
			get_style_context().add_class("settings-dialog");
			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			headerbar = (HeaderBar) get_header_bar();
			headerbar.has_subtitle = true;
			headerbar.show_close_button = true;

			headerbar_page_active_switch = new Switch();
			headerbar_page_active_switch.valign = Align.CENTER;
			headerbar_page_active_switch.no_show_all = true;
			headerbar.pack_end(headerbar_page_active_switch);

			var ui_settings = GameHub.Settings.UI.Appearance.instance;
			ui_settings.notify["dark-theme"].connect(() => {
				get_style_context().remove_class("dark");
				if(ui_settings.dark_theme) get_style_context().add_class("dark");
			});
			ui_settings.notify_property("dark-theme");

			gravity = Gdk.Gravity.NORTH;
			modal = true;

			var content = get_content_area();
			content.set_size_request(900, 600);

			restart_msg = new InfoBar();
			restart_msg.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			restart_msg.get_content_area().add(new Label(_("Some settings will be applied after application restart")));
			restart_msg.message_type = MessageType.INFO;
			restart_msg.show_all();

			games_dir_space_msg = new InfoBar();
			games_dir_space_msg.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			games_dir_space_msg.get_content_area().add(new Label(_("Games directory contains space. It may cause problems for some games")));
			games_dir_space_msg.message_type = MessageType.WARNING;
			games_dir_space_msg.show_all();
			games_dir_space_msg.margin_bottom = 8;

			update_messages();

			pages = new Stack();
			pages.homogeneous = false;
			pages.interpolate_size = true;

			pages.notify["visible-child"].connect(() => {
				update_current_page((SettingsSidebar.SettingsPage) pages.visible_child);
			});

			add_page("ui/appearance", new Pages.UI.Appearance(this));
			add_page("ui/behavior", new Pages.UI.Behavior(this));

			add_page("general/collection", new Pages.General.Collection(this));
			#if MANETTE
			add_page("general/controller", new Pages.General.Controller(this));
			#endif
			add_page("general/compat", new Pages.General.CompatTools(this));
			add_page("general/tweaks", new Pages.General.Tweaks(this));

			add_page("sources/steam", new Pages.Sources.Steam(this));
			add_page("sources/gog", new Pages.Sources.GOG(this));
			add_page("sources/humble", new Pages.Sources.Humble(this));
			add_page("sources/itch", new Pages.Sources.Itch(this));

			/*add_page("emulators/retroarch", new Pages.Emulators.RetroArch(this));
			add_page("emulators/custom", new Pages.Emulators.Emulators(this));*/

			add_page("providers/providers", new Pages.Providers.Providers(this));

			add_page("about", new Pages.About(this));

			var sidebar = new SettingsSidebar(pages);
			sidebar.get_style_context().add_class("settings-pages-sidebar");

			var content_hbox = new Box(Orientation.HORIZONTAL, 1);
			var content_root = new Box(Orientation.VERTICAL, 0);

			content_root.add(restart_msg);
			content_root.add(games_dir_space_msg);
			content_root.add(pages);

			content_hbox.add(sidebar);
			content_hbox.add(content_root);

			content.add(content_hbox);

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CLOSE:
						destroy();
						break;
				}
			});

			show_all();

			//get_action_area().visible = false;

			Idle.add(() => {
				sidebar.visible_child_name = default_page;
				return Source.REMOVE;
			});
		}

		private SettingsSidebar.SettingsPage? current_page = null;
		private ulong current_page_title_handler = 0;
		private ulong current_page_desc_handler = 0;
		private ulong current_page_has_active_switch_handler = 0;
		private Binding? current_page_active_binding = null;

		private void update_current_page(SettingsSidebar.SettingsPage page)
		{
			if(current_page != null)
			{
				current_page.disconnect(current_page_title_handler);
				current_page.disconnect(current_page_desc_handler);
				current_page.disconnect(current_page_has_active_switch_handler);
				if(current_page_active_binding != null)
				{
					current_page_active_binding.unbind();
					current_page_active_binding = null;
				}
			}
			current_page = page;
			current_page_title_handler = current_page.notify["title"].connect(update_current_page_title);
			current_page_desc_handler = current_page.notify["description"].connect(update_current_page_title);
			current_page_has_active_switch_handler = current_page.notify["has-active-switch"].connect(update_current_page_active_switch);
			update_current_page_title();
			update_current_page_active_switch();
		}

		private void update_current_page_title()
		{
			if(headerbar == null || current_page == null) return;
			var title = current_page.title;
			var desc = current_page.description;
			if(desc != null)
			{
				headerbar.subtitle = "%s • %s".printf(title, desc);
			}
			else
			{
				headerbar.subtitle = title;
			}
		}

		private void update_current_page_active_switch()
		{
			if(headerbar_page_active_switch == null || current_page == null) return;
			headerbar_page_active_switch.visible = current_page.has_active_switch;
			if(current_page_active_binding != null)
			{
				current_page_active_binding.unbind();
				current_page_active_binding = null;
			}
			if(current_page.has_active_switch)
			{
				current_page_active_binding = current_page.bind_property("active", headerbar_page_active_switch, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
			}
		}

		private void add_page(string id, SettingsSidebar.SettingsPage page)
		{
			pages.add_named(page, id);
		}

		public void show_restart_message()
		{
			restart_msg_shown = true;
			update_messages();
		}

		public void update_games_dir_space_message()
		{
			/*var paths = FS.Paths.Settings.instance;
			games_dir_space_msg_shown = " " in paths.gog_games || " " in paths.humble_games;*/
			update_messages();
		}

		private void update_messages()
		{
			restart_msg.visible = restart_msg_shown;
			restart_msg.no_show_all = !restart_msg_shown;
			games_dir_space_msg.visible = games_dir_space_msg_shown;
			games_dir_space_msg.no_show_all = !games_dir_space_msg_shown;
			restart_msg.revealed = restart_msg_shown;
			games_dir_space_msg.revealed = games_dir_space_msg_shown;
		}
	}
}
