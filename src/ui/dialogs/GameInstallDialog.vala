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
using Gdk;
using GLib;
using Gee;
using GameHub.Utils;
using GameHub.UI.Widgets;

using GameHub.Data;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;

namespace GameHub.UI.Dialogs
{
	public class GameInstallDialog: Dialog
	{
		private const int RESPONSE_IMPORT = 123;

		public signal void import();
		public signal void install(Game.Installer installer, CompatTool? tool);
		public signal void cancelled();

		private Box content;
		private Label title_label;
		private Label subtitle_label;

		private ListBox installers_list;

		private bool is_finished = false;

		private CompatToolPicker compat_tool_picker;
		private CompatToolOptions opts_list;

		public GameInstallDialog(Game game, ArrayList<Game.Installer> installers)
		{
			Object(transient_for: Windows.MainWindow.instance, resizable: false, title: _("Install"));

			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			modal = true;

			var hbox = new Box(Orientation.HORIZONTAL, 8);
			hbox.margin_start = hbox.margin_end = 5;

			content = new Box(Orientation.VERTICAL, 0);

			var icon = new AutoSizeImage();
			icon.set_constraint(48, 48, 1);
			icon.set_size_request(48, 48);

			title_label = new Label(null);
			title_label.margin_start = title_label.margin_end = 8;
			title_label.halign = Align.START;
			title_label.hexpand = true;
			title_label.get_style_context().add_class(Granite.STYLE_CLASS_H2_LABEL);

			subtitle_label = new Label(null);
			subtitle_label.margin_start = subtitle_label.margin_end = 8;
			subtitle_label.halign = Align.START;
			subtitle_label.hexpand = true;

			hbox.add(icon);
			hbox.add(content);

			content.add(title_label);
			content.add(subtitle_label);

			title_label.label = game.name;
			Utils.load_image.begin(icon, game.icon, "icon");

			installers_list = new ListBox();
			installers_list.margin_top = 4;
			installers_list.get_style_context().add_class("installers-list");

			installers_list.set_sort_func((row1, row2) => {
				var item1 = row1 as InstallerRow;
				var item2 = row2 as InstallerRow;
				if(item1 != null && item2 != null)
				{
					var i1 = item1.installer;
					var i2 = item2.installer;

					if(i1.platform.id() == CurrentPlatform.id() && i2.platform.id() != CurrentPlatform.id()) return -1;
					if(i1.platform.id() != CurrentPlatform.id() && i2.platform.id() == CurrentPlatform.id()) return 1;

					return i1.name.collate(i2.name);
				}
				return 0;
			});

			var sys_langs = Intl.get_language_names();

			var compatible_installers = new ArrayList<Game.Installer>();

			foreach(var installer in installers)
			{
				if(installer.platform.id() != CurrentPlatform.id() && !Settings.UI.get_instance().show_unsupported_games && !Settings.UI.get_instance().use_compat) continue;

				compatible_installers.add(installer);
				var row = new InstallerRow(game, installer);
				installers_list.add(row);

				if(installer is GOGGame.Installer && (installer as GOGGame.Installer).lang in sys_langs)
				{
					installers_list.select_row(row);
				}
				else if(installers_list.get_selected_row() == null && installer.platform.id() == CurrentPlatform.id())
				{
					installers_list.select_row(row);
				}
			}

			if(compatible_installers.size > 1)
			{
				subtitle_label.label = _("Select game installer");
				content.add(installers_list);
			}
			else
			{
				subtitle_label.label = _("Installer size: %s").printf(fsize(compatible_installers[0].full_size));
			}

			if(Settings.UI.get_instance().show_unsupported_games || Settings.UI.get_instance().use_compat)
			{
				var compat_tool_revealer = new Revealer();

				var compat_tool_box = new Box(Orientation.VERTICAL, 4);

				compat_tool_picker = new CompatToolPicker(game, true);
				compat_tool_picker.margin_start = 4;
				compat_tool_picker.margin_top = 8;

				compat_tool_box.add(compat_tool_picker);
				compat_tool_revealer.add(compat_tool_box);

				if(compatible_installers.size > 1)
				{
					compat_tool_revealer.reveal_child = false;

					installers_list.row_selected.connect(r => {
						var row = r as InstallerRow;
						if(row == null)
						{
							compat_tool_revealer.reveal_child = false;
						}
						else
						{
							compat_tool_revealer.reveal_child = row.installer.platform == Platform.WINDOWS;
						}
					});
				}
				else
				{
					compat_tool_revealer.reveal_child = !game.is_supported(null, false) && game.is_supported(null, true);
				}

				content.add(compat_tool_revealer);

				opts_list = new CompatToolOptions(game, compat_tool_picker, true);
				compat_tool_box.add(opts_list);
			}

			destroy.connect(() => { if(!is_finished) cancelled(); });

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CLOSE:
						destroy();
						break;

					case GameInstallDialog.RESPONSE_IMPORT:
						is_finished = true;
						import();
						destroy();
						break;

					case ResponseType.ACCEPT:
						var installer = compatible_installers[0];
						if(compatible_installers.size > 1)
						{
							var row = installers_list.get_selected_row() as InstallerRow;
							installer = row.installer;
						}
						is_finished = true;
						if(opts_list != null)
						{
							opts_list.save_options();
						}
						install(installer, compat_tool_picker != null ? compat_tool_picker.selected : null);
						destroy();
						break;
				}
			});

			add_button(_("Import"), GameInstallDialog.RESPONSE_IMPORT);

			var install_btn = add_button(_("Install"), ResponseType.ACCEPT);
			install_btn.get_style_context().add_class(STYLE_CLASS_SUGGESTED_ACTION);
			install_btn.grab_default();

			get_content_area().add(hbox);
			get_content_area().set_size_request(380, 96);
			show_all();
		}

		public static string fsize(int64 size)
		{
			if(size > 0)
			{
				return format_size(size);
			}
			return _("Unknown");
		}

		private class InstallerRow: ListBoxRow
		{
			public Game game;
			public Game.Installer installer;

			public InstallerRow(Game game, Game.Installer installer)
			{
				this.game = game;
				this.installer = installer;

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 4;

				var icon = new Image.from_icon_name(installer.platform.icon(), IconSize.BUTTON);

				var name = new Label(installer.name);
				name.hexpand = true;
				name.halign = Align.START;

				var size = new Label(fsize(installer.full_size));
				size.halign = Align.END;

				box.add(icon);
				box.add(name);
				box.add(size);
				child = box;
			}
		}
	}
}
