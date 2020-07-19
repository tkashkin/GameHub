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
using GameHub.UI.Widgets.Tweaks;

using GameHub.Data;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.General
{
	public class Tweaks: SettingsDialogPage
	{
		public Tweaks(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				title: _("Tweaks"),
				icon_name: "gh-settings-cogs-symbolic"
			);
		}

		construct
		{
			var dirs = FS.get_data_dirs("tweaks", true);
			var last_dir = dirs.last();

			var sgrp_dirs = new SettingsGroup();
			var dirs_btn = new MenuButton();
			dirs_btn.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
			dirs_btn.tooltip_text = _("Tweak directories");
			dirs_btn.can_focus = false;

			var dirs_setting = sgrp_dirs.add_setting(new BaseSetting(
				_("Tweak directories"),
				_("Tweaks are loaded from these directories in order\nLast tweak overrides previous tweaks with same identifiers"),
				dirs_btn
			));

			var dirs_menu = new Gtk.Menu();
			dirs_menu.halign = Align.END;

			foreach(var dir in dirs)
			{
				var dir_item = new Gtk.MenuItem.with_label(dir.get_path());
				if(dir.query_exists())
				{
					dir_item.activate.connect(() => {
						Utils.open_uri(dir.get_uri());
					});
				}
				else
				{
					dir_item.sensitive = false;
				}
				dirs_menu.add(dir_item);
			}

			dirs_menu.show_all();
			dirs_btn.popup = dirs_menu;

			dirs_setting.activatable = true;
			dirs_setting.setting_activated.connect(() => {
				#if GTK_3_22
				dirs_menu.popup_at_widget(dirs_btn, Gdk.Gravity.SOUTH_EAST, Gdk.Gravity.NORTH_EAST);
				#else
				dirs_menu.popup(null, null, null, 0, get_current_event_time());
				#endif
			});
			add_widget(sgrp_dirs);

			var sgrp_tweaks = new SettingsGroupBox();
			sgrp_tweaks.container.get_style_context().remove_class(Gtk.STYLE_CLASS_VIEW);
			sgrp_tweaks.add_widget(new TweaksList());
			add_widget(sgrp_tweaks);
		}
	}
}
