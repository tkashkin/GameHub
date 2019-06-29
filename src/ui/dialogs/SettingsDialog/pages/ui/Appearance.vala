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

using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.UI
{
	public class Appearance: SettingsDialogPage
	{
		private Settings.UI.Appearance settings;

		public Appearance(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				header: _("Interface"),
				title: _("Appearance"),
				description: _("General interface settings"),
				icon_name: "preferences-desktop"
			);
			status = description;
		}

		construct
		{
			settings = Settings.UI.Appearance.instance;

			add_switch(_("Dark theme"), settings.dark_theme, v => { settings.dark_theme = v; });

			var icon_style = new ModeButton();
			icon_style.homogeneous = false;
			icon_style.halign = Align.END;
			icon_style.append_text(C_("icon_style", "Theme-based"));
			icon_style.append_text(C_("icon_style", "Symbolic"));
			icon_style.append_text(C_("icon_style", "Colored"));

			var icon_style_label = new Label(C_("icon_style", "Icon style"));
			icon_style_label.halign = Align.START;
			icon_style_label.hexpand = true;

			var icon_style_hbox = new Box(Orientation.HORIZONTAL, 12);
			icon_style_hbox.add(icon_style_label);
			icon_style_hbox.add(icon_style);
			add_widget(icon_style_hbox);

			icon_style.selected = settings.icon_style;
			icon_style.mode_changed.connect(() => {
				settings.icon_style = (Settings.UI.Appearance.IconStyle) icon_style.selected;
			});

			add_switch(_("Show platform icons in grid view"), settings.grid_platform_icons, v => { settings.grid_platform_icons = v; });

			add_separator();

			var hbox = new Box(Orientation.HORIZONTAL, 8);

			var list_installed = new Box(Orientation.VERTICAL, 4);
			list_installed.hexpand = true;

			var list_uninstalled = new Box(Orientation.VERTICAL, 4);
			list_uninstalled.hexpand = true;

			hbox.add(list_installed);
			hbox.add(new Separator(Orientation.VERTICAL));
			hbox.add(list_uninstalled);

			add_widget(hbox);

			list_installed.add(Styled.H4Label(_("Games list: installed")));
			list_uninstalled.add(Styled.H4Label(_("Games list: not installed")));

			add_list_style_checkbox(C_("list_style", "Show icon"), "installed-icon", list_installed);
			add_list_style_checkbox(C_("list_style", "Bold title"), "installed-title-bold", list_installed);
			add_list_style_checkbox(C_("list_style", "Show status"), "installed-status", list_installed);

			add_list_style_checkbox(C_("list_style", "Show icon"), "uninstalled-icon", list_uninstalled);
			add_list_style_checkbox(C_("list_style", "Bold title"), "uninstalled-title-bold", list_uninstalled);
			add_list_style_checkbox(C_("list_style", "Show status"), "uninstalled-status", list_uninstalled);
			add_list_style_checkbox(C_("list_style", "Dim"), "uninstalled-dim", list_uninstalled);
		}

		private CheckButton add_list_style_checkbox(string label, string style, Box parent)
		{
			var check = new CheckButton.with_label(label);
			StyleClass.add(check, "default-padding");
			parent.add(check);
			check.active = style in settings.list_style;
			check.toggled.connect(() => {
				if(!check.active && style in settings.list_style)
				{
					string[] new_style = {};
					foreach(var s in settings.list_style)
					{
						if(s != style) new_style += s;
					}
					settings.update_list_style(new_style);
				}
				else if(check.active && !(style in settings.list_style))
				{
					string[] new_style = settings.list_style;
					new_style += style;
					settings.update_list_style(new_style);
				}
			});
			return check;
		}
	}
}
