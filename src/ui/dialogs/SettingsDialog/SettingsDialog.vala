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
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog
{
	public class SettingsDialog: Dialog
	{
		private static bool restart_msg_shown = false;

		private InfoBar restart_msg;

		private Stack tabs;

		private string default_tab;

		public SettingsDialog(string tab="ui")
		{
			Object(transient_for: Windows.MainWindow.instance, resizable: false, title: _("Settings"));
			default_tab = tab;
		}

		construct
		{
			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			gravity = Gdk.Gravity.NORTH;
			modal = true;

			var content = get_content_area();
			content.set_size_request(480, -1);

			restart_msg = new InfoBar();
			restart_msg.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			restart_msg.get_content_area().add(new Label(_("Some settings will be applied after application restart")));
			restart_msg.message_type = MessageType.WARNING;
			restart_msg.margin_bottom = 8;
			update_restart_message();

			tabs = new Stack();
			tabs.homogeneous = false;
			tabs.interpolate_size = true;

			var tabs_switcher = new StackSwitcher();
			tabs_switcher.stack = tabs;
			tabs_switcher.halign = Align.CENTER;
			tabs_switcher.margin_bottom = 16;

			add_tab("ui", new Tabs.UI(this), _("Interface"));
			add_tab("collection", new Tabs.Collection(this), _("Collection"));
			add_tab("gs/steam", new Tabs.Steam(this), "Steam", "source-steam-symbolic");
			add_tab("gs/gog", new Tabs.GOG(this), "GOG", "source-gog-symbolic");
			add_tab("gs/humble", new Tabs.Humble(this), "Humble Bundle", "source-humble-symbolic");
			add_tab("emu/retroarch", new Tabs.RetroArch(this), "RetroArch", "emu-retroarch-symbolic");
			add_tab("emu/custom", new Tabs.Emulators(this), _("Emulators"));

			content.pack_start(restart_msg, false, false, 0);
			content.pack_start(tabs_switcher, false, false, 0);
			content.pack_start(tabs, false, false, 0);

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CLOSE:
						destroy();
						break;
				}
			});

			show_all();

			tabs.visible_child_name = default_tab;
		}

		private void add_tab(string id, SettingsDialogTab tab, string title, string? icon=null)
		{
			tabs.add_titled(tab, id, title);
			tabs.child_set_property(tab, "icon-name", icon);
		}

		public void show_restart_message()
		{
			restart_msg_shown = true;
			update_restart_message();
		}

		private void update_restart_message()
		{
			#if GTK_3_22
			restart_msg.revealed = restart_msg_shown;
			#else
			restart_msg.visible = restart_msg_shown;
			restart_msg.no_show_all = !restart_msg_shown;
			#endif
		}
	}
}
