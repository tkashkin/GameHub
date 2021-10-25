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
using Gee;

using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.UI
{
	public class Appearance: SettingsDialogPage
	{
		private Settings.UI.Appearance settings;

		private ModeButton grid_size_presets;
		private BaseSetting setting_card_size_preset;

		public Appearance(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				header: _("Interface"),
				title: _("Appearance"),
				icon_name: "gh-settings-grid-cog-symbolic"
			);
		}

		construct
		{
			settings = Settings.UI.Appearance.instance;

			var grid_size_hbox = new Box(Orientation.HORIZONTAL, 8);
			var grid_width_spinbutton = add_spinbutton(settings.grid_card_width, v => { settings.grid_card_width = v; update_grid_size_presets(); }, grid_size_hbox);
			grid_size_hbox.add(new Label("×"));
			var grid_height_spinbutton = add_spinbutton(settings.grid_card_height, v => { settings.grid_card_height = v; update_grid_size_presets(); }, grid_size_hbox);

			grid_size_presets = new ModeButton();

			foreach(var preset in Settings.UI.Appearance.GameGridSizePreset.PRESETS)
			{
				grid_size_presets.append_icon(preset.icon(), IconSize.BUTTON, preset.description(), true);
			}

			var list_hbox = new Box(Orientation.HORIZONTAL, 8);
			list_hbox.margin_start = list_hbox.margin_end = 8;

			var list_installed = new Box(Orientation.VERTICAL, 4);
			list_installed.hexpand = true;

			var list_uninstalled = new Box(Orientation.VERTICAL, 4);
			list_uninstalled.hexpand = true;

			list_hbox.add(list_installed);
			list_hbox.add(new Separator(Orientation.VERTICAL));
			list_hbox.add(list_uninstalled);

			list_installed.add(Styled.H4Label(_("Installed games")));
			list_uninstalled.add(Styled.H4Label(_("Not installed games")));

			add_list_style_checkbox(C_("list_style", "Show icon"), "installed-icon", list_installed);
			add_list_style_checkbox(C_("list_style", "Bold title"), "installed-title-bold", list_installed);
			add_list_style_checkbox(C_("list_style", "Show status"), "installed-status", list_installed);

			add_list_style_checkbox(C_("list_style", "Show icon"), "uninstalled-icon", list_uninstalled);
			add_list_style_checkbox(C_("list_style", "Bold title"), "uninstalled-title-bold", list_uninstalled);
			add_list_style_checkbox(C_("list_style", "Show status"), "uninstalled-status", list_uninstalled);
			add_list_style_checkbox(C_("list_style", "Dimmed title"), "uninstalled-dim", list_uninstalled);

			var sgrp_appearance = new SettingsGroup();
			sgrp_appearance.add_setting(new SwitchSetting.bind(_("Prefer dark theme"), null, settings, "dark-theme"));
			sgrp_appearance.add_setting(new ModeButtonSetting.bind(_("Icon style"), _("Colored icons may look better for some themes"), { C_("icon_style", "Automatic"), C_("icon_style", "Symbolic"), C_("icon_style", "Colored") }, settings, "icon-style"));
			add_widget(sgrp_appearance);

			var sgrp_grid = new SettingsGroup(_("Grid"));
			sgrp_grid.add_setting(new SwitchSetting.bind(_("Show platform icons"), null, settings, "grid-platform-icons"));
			sgrp_grid.add_setting(new SwitchSetting.bind(_("Show game titles"), null, settings, "grid-titles"));
			sgrp_grid.add_setting(new BaseSetting(_("Card size"), _("Cards may be scaled to fit window"), grid_size_hbox));
			setting_card_size_preset = sgrp_grid.add_setting(new BaseSetting(_("Card size preset"), null, grid_size_presets));
			add_widget(sgrp_grid);

			var sgrp_list = new SettingsGroup(_("List"));
			sgrp_list.add_setting(new CustomWidgetSetting(list_hbox));
			add_widget(sgrp_list);

			grid_size_presets.mode_changed.connect(() => {
				var preset = Settings.UI.Appearance.GameGridSizePreset.PRESETS[grid_size_presets.selected];
				if(preset != Settings.UI.Appearance.GameGridSizePreset.CUSTOM)
				{
					grid_width_spinbutton.value = preset.width();
					grid_height_spinbutton.value = preset.height();
				}
				setting_card_size_preset.description = preset.name();
			});

			update_grid_size_presets();
		}

		private void update_grid_size_presets()
		{
			var index = (int) Settings.UI.Appearance.GameGridSizePreset.from_size(settings.grid_card_width, settings.grid_card_height);
			if(index >= 0 && index < grid_size_presets.n_items)
			{
				grid_size_presets.selected = index;
			}
		}

		private CheckButton add_checkbox(string label, bool active, owned SwitchAction action, Box parent)
		{
			var check = new CheckButton.with_label(label);
			StyleClass.add(check, "default-padding");
			parent.add(check);
			check.active = active;
			check.toggled.connect(() => { action(check.active); });
			return check;
		}

		private CheckButton add_list_style_checkbox(string label, string style, Box parent)
		{
			return add_checkbox(label, style in settings.list_style, active => {
				if(!active && style in settings.list_style)
				{
					string[] new_style = {};
					foreach(var s in settings.list_style)
					{
						if(s != style) new_style += s;
					}
					settings.update_list_style(new_style);
				}
				else if(active && !(style in settings.list_style))
				{
					string[] new_style = settings.list_style;
					new_style += style;
					settings.update_list_style(new_style);
				}
			}, parent);
		}

		private SpinButton add_spinbutton(int value, owned SpinButtonAction action, Box parent)
		{
			var button = new SpinButton.with_range(100, 1000, 10);
			button.value = value;
			button.value_changed.connect(() => { action((int) button.value); });
			parent.add(button);
			return button;
		}


		delegate void SwitchAction(bool active);
		delegate void SpinButtonAction(int value);
	}
}
