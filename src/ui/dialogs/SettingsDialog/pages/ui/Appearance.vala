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

		private ModeButton grid_size_presets;

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

			add_separator();

			var tabs_switcher = add_widget(new StackSwitcher());
			tabs_switcher.halign = Align.CENTER;

			var tabs_stack = add_widget(new Stack());
			tabs_stack.margin = 0;

			tabs_switcher.stack = tabs_stack;

			var tab_grid = new Box(Orientation.VERTICAL, 4);
			tab_grid.margin = 4;

			tab_grid.add(Styled.H4Label(_("Game card")));

			add_checkbox(_("Show platform icons"), settings.grid_platform_icons, v => { settings.grid_platform_icons = v; }, tab_grid);

			var grid_size_separator = new Separator(Orientation.HORIZONTAL);
			grid_size_separator.margin_top = grid_size_separator.margin_bottom = 4;
			tab_grid.add(grid_size_separator);

			var grid_size_wrap_hbox = new Box(Orientation.HORIZONTAL, 12);
			var grid_size_hbox = new Box(Orientation.HORIZONTAL, 8);

			var grid_width_spinbutton = add_spinbutton(settings.grid_card_width, v => { settings.grid_card_width = v; update_grid_size_presets(); }, grid_size_hbox);
			grid_size_hbox.add(new Label("×"));
			var grid_height_spinbutton = add_spinbutton(settings.grid_card_height, v => { settings.grid_card_height = v; update_grid_size_presets(); }, grid_size_hbox);

			var grid_size_label = new Label(C_("grid_size", "Card size"));
			grid_size_label.halign = Align.START;
			grid_size_label.hexpand = true;

			grid_size_wrap_hbox.add(grid_size_label);
			grid_size_wrap_hbox.add(grid_size_hbox);

			tab_grid.add(grid_size_wrap_hbox);

			grid_size_presets = new ModeButton();
			StyleClass.add(grid_size_presets, "icons-modebutton");
			grid_size_presets.halign = Align.END;

			foreach(var preset in Settings.UI.Appearance.GameGridSizePreset.PRESETS)
			{
				grid_size_presets.append_icon(preset.icon(), IconSize.BUTTON, preset.description(), true);
			}

			var grid_size_presets_label = new Label(C_("grid_size_preset", "Presets"));
			grid_size_presets_label.halign = Align.START;
			grid_size_presets_label.hexpand = true;

			var grid_size_presets_hbox = new Box(Orientation.HORIZONTAL, 12);
			grid_size_presets_hbox.add(grid_size_presets_label);
			grid_size_presets_hbox.add(grid_size_presets);
			tab_grid.add(grid_size_presets_hbox);

			var tab_list = new Box(Orientation.HORIZONTAL, 8);
			tab_list.margin = 4;

			var list_installed = new Box(Orientation.VERTICAL, 4);
			list_installed.hexpand = true;

			var list_uninstalled = new Box(Orientation.VERTICAL, 4);
			list_uninstalled.hexpand = true;

			tab_list.add(list_installed);
			tab_list.add(new Separator(Orientation.VERTICAL));
			tab_list.add(list_uninstalled);

			list_installed.add(Styled.H4Label(_("Games list: installed")));
			list_uninstalled.add(Styled.H4Label(_("Games list: not installed")));

			add_list_style_checkbox(C_("list_style", "Show icon"), "installed-icon", list_installed);
			add_list_style_checkbox(C_("list_style", "Bold title"), "installed-title-bold", list_installed);
			add_list_style_checkbox(C_("list_style", "Show status"), "installed-status", list_installed);

			add_list_style_checkbox(C_("list_style", "Show icon"), "uninstalled-icon", list_uninstalled);
			add_list_style_checkbox(C_("list_style", "Bold title"), "uninstalled-title-bold", list_uninstalled);
			add_list_style_checkbox(C_("list_style", "Show status"), "uninstalled-status", list_uninstalled);
			add_list_style_checkbox(C_("list_style", "Dim"), "uninstalled-dim", list_uninstalled);

			tabs_stack.add_titled(tab_grid, "grid", _("Grid options"));
			tabs_stack.add_titled(tab_list, "list", _("List options"));

			grid_size_presets.mode_changed.connect(() => {
				var preset = Settings.UI.Appearance.GameGridSizePreset.PRESETS[grid_size_presets.selected];
				if(preset != Settings.UI.Appearance.GameGridSizePreset.CUSTOM)
				{
					grid_width_spinbutton.value = preset.width();
					grid_height_spinbutton.value = preset.height();
				}
			});

			update_grid_size_presets();
		}

		private void update_grid_size_presets()
		{
			grid_size_presets.selected = (int) Settings.UI.Appearance.GameGridSizePreset.from_size(settings.grid_card_width, settings.grid_card_height);
		}

		private CheckButton add_checkbox(string label, bool active, owned SettingsDialogPage.SwitchAction action, Box parent)
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

		delegate void SpinButtonAction(int value);
	}
}
