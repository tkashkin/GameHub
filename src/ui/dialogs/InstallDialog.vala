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
	public class InstallDialog: Dialog
	{
		private const int RESPONSE_IMPORT = 10;
		private const int RESPONSE_DOWNLOAD = 11;

		private Box content;
		private Label title_label;
		private Label subtitle_label;

		private ModeButton platforms_list;
		private ListBox installers_list;

		private CompatToolPicker compat_tool_picker;
		private CompatToolOptions opts_list;

		public Runnable runnable { get; construct; }
		public Runnable.Installer.InstallMode install_mode { get; construct; }
		private SourceFunc? callback = null;

		public InstallDialog(Runnable runnable, ArrayList<Runnable.Installer> installers, Runnable.Installer.InstallMode install_mode=Runnable.Installer.InstallMode.INTERACTIVE, owned SourceFunc? callback=null)
		{
			Object(transient_for: Windows.MainWindow.instance, resizable: false, title: _("Install"), runnable: runnable, install_mode: install_mode);
			this.callback = (owned) callback;

			Game? game = null;

			if(runnable is Game)
			{
				game = runnable as Game;
			}

			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			modal = true;

			var hbox = new Box(Orientation.HORIZONTAL, 8);
			hbox.margin_start = hbox.margin_end = 5;

			content = new Box(Orientation.VERTICAL, 0);

			title_label = Styled.H2Label(null);
			title_label.margin_start = title_label.margin_end = 4;
			title_label.halign = Align.START;
			title_label.xalign = 0;
			title_label.wrap = true;
			title_label.max_width_chars = 36;

			var subtitle_hbox = new Box(Orientation.HORIZONTAL, 8);

			subtitle_label = new Label(null);
			subtitle_label.margin_start = subtitle_label.margin_end = 4;
			subtitle_label.halign = Align.START;
			subtitle_label.valign = Align.CENTER;
			subtitle_label.hexpand = true;

			if(game != null && game.icon != null)
			{
				var icon = new AutoSizeImage();
				icon.valign = Align.START;
				icon.set_constraint(48, 48, 1);
				icon.set_size_request(48, 48);
				icon.load(game.icon, null, @"games/$(game.source.id)/$(game.id)/icons/");
				hbox.add(icon);
				title_label.margin_start = title_label.margin_end = 8;
				subtitle_label.margin_start = subtitle_label.margin_end = 8;
			}

			hbox.add(content);

			subtitle_hbox.add(subtitle_label);

			content.add(title_label);
			content.add(subtitle_hbox);

			title_label.label = runnable.name;

			var import_btn = add_button(_("Import"), InstallDialog.RESPONSE_IMPORT);
			var dl_btn = add_button(_("Download"), InstallDialog.RESPONSE_DOWNLOAD);
			var install_btn = add_button(_("Install"), ResponseType.ACCEPT);
			install_btn.get_style_context().add_class(STYLE_CLASS_SUGGESTED_ACTION);
			install_btn.grab_default();

			var bbox = import_btn.get_parent() as ButtonBox;
			if(bbox != null)
			{
				bbox.set_child_secondary(import_btn, true);
				bbox.set_child_non_homogeneous(import_btn, true);
			}

			platforms_list = new ModeButton();
			platforms_list.get_style_context().add_class("installer-platforms-list");
			platforms_list.halign = Align.END;
			platforms_list.valign = Align.CENTER;

			installers_list = new ListBox();
			installers_list.get_style_context().add_class("installers-list");
			installers_list.margin_top = 4;

			installers_list.set_sort_func((row1, row2) => {
				var item1 = row1 as InstallerRow;
				var item2 = row2 as InstallerRow;
				if(item1 != null && item2 != null)
				{
					var i1 = item1.installer;
					var i2 = item2.installer;

					if(i1.platform.id() == Platform.CURRENT.id() && i2.platform.id() != Platform.CURRENT.id()) return -1;
					if(i1.platform.id() != Platform.CURRENT.id() && i2.platform.id() == Platform.CURRENT.id()) return 1;

					return i1.name.collate(i2.name);
				}
				return 0;
			});

			var sys_langs = Intl.get_language_names();

			var compatible_platforms = new ArrayList<Platform>();

			foreach(var installer in installers)
			{
				var row = new InstallerRow(runnable, installer);
				installers_list.add(row);

				if(!(installer.platform in compatible_platforms))
				{
					compatible_platforms.add(installer.platform);
				}

				if(installer is GOGGame.Installer && (installer as GOGGame.Installer).lang in sys_langs)
				{
					installers_list.select_row(row);
				}
				else if(installers_list.get_selected_row() == null && installer.platform.id() == Platform.CURRENT.id())
				{
					installers_list.select_row(row);
				}
			}

			installers_list.set_filter_func(installers_filter);

			platforms_list.mode_changed.connect(() => {
				installers_list.invalidate_filter();
				foreach(var r in installers_list.get_children())
				{
					var row = r as InstallerRow;
					var selected_row = installers_list.get_selected_row() as InstallerRow;
					if(selected_row == null || !installers_filter(selected_row))
					{
						if(installers_filter(row) && (!(row.installer is GOGGame.Installer) || (row.installer as GOGGame.Installer).lang in sys_langs))
						{
							installers_list.select_row(row);
							break;
						}
					}
				}
				install_btn.sensitive = platforms_list.selected >= 0 && platforms_list.selected < Platform.PLATFORMS.length && Platform.PLATFORMS[platforms_list.selected] != Platform.MACOS;
			});

			platforms_list.selected = -1;
			for(int i = 0; i < Platform.PLATFORMS.length; i++)
			{
				var icon = new Image.from_icon_name(Platform.PLATFORMS[i].icon(), IconSize.BUTTON);
				icon.tooltip_text = Platform.PLATFORMS[i].name();
				platforms_list.append(icon);
				var is_compatible = Platform.PLATFORMS[i] in compatible_platforms;
				platforms_list.set_item_visible(i, is_compatible);
				if(is_compatible && platforms_list.selected < 0)
				{
					platforms_list.selected = i;
				}
			}

			if(installers.size > 1)
			{
				subtitle_label.label = _("Select installer");
				content.add(installers_list);
				if(compatible_platforms.size > 1)
				{
					subtitle_hbox.add(platforms_list);
				}
			}
			else
			{
				subtitle_label.label = _("Installer size: calculating...");
				Utils.thread("CalculatingFileSize", () => {
					subtitle_label.label = _("Installer size: %s").printf(fsize(installers[0].full_size));
				});
				
			}

			Revealer? compat_tool_revealer = new Revealer();

			var compat_tool_box = new Box(Orientation.VERTICAL, 4);

			compat_tool_picker = new CompatToolPicker(runnable, true);
			compat_tool_picker.margin_start = game != null && game.icon != null ? 4 : 0;
			compat_tool_picker.margin_top = 8;

			compat_tool_box.add(compat_tool_picker);
			compat_tool_revealer.add(compat_tool_box);

			if(installers.size > 1)
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
						var installer = row.installer;
						compat_tool_revealer.reveal_child = installer.platform == Platform.WINDOWS;
						dl_btn.sensitive = installer is Runnable.DownloadableInstaller;
					}
				});
			}
			else
			{
				compat_tool_revealer.reveal_child = installers[0].platform == Platform.WINDOWS;
				dl_btn.sensitive = installers[0] is Runnable.DownloadableInstaller;
			}

			content.add(compat_tool_revealer);

			opts_list = new CompatToolOptions(runnable, compat_tool_picker, true);
			compat_tool_box.add(opts_list);

			if(game is GameHub.Data.Sources.User.UserGame || runnable is GameHub.Data.Emulator)
			{
				subtitle_label.no_show_all = true;
				subtitle_label.visible = false;
				dl_btn.no_show_all = true;
				dl_btn.visible = false;
				import_btn.no_show_all = true;
				import_btn.visible = false;
				compat_tool_revealer.reveal_child = true;
			}

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case ResponseType.CLOSE:
						destroy();
						if(callback != null) callback();
						break;

					case InstallDialog.RESPONSE_IMPORT:
						runnable.import();
						destroy();
						if(callback != null) callback();
						break;

					case ResponseType.ACCEPT:
					case InstallDialog.RESPONSE_DOWNLOAD:
						var installer = installers[0];
						if(installers.size > 1)
						{
							var row = installers_list.get_selected_row() as InstallerRow;
							if(row != null) installer = row.installer;
						}
						if(opts_list != null)
						{
							opts_list.save_options();
						}
						install_or_download.begin(response_id, installer, compat_tool_picker != null ? compat_tool_picker.selected : null);
						destroy();
						break;
				}
			});

			get_content_area().add(hbox);
			get_content_area().set_size_request(380, 96);

			if(install_mode != Runnable.Installer.InstallMode.INTERACTIVE)
			{
				Idle.add(() => {
					response(install_mode == Runnable.Installer.InstallMode.AUTOMATIC ? ResponseType.ACCEPT : InstallDialog.RESPONSE_DOWNLOAD);
					hide();
					return Source.REMOVE;
				});
				return;
			}

			if(install_mode == Runnable.Installer.InstallMode.INTERACTIVE)
			{
				show_all();
				present();
			}
		}

		private async void install_or_download(int response_id, Runnable.Installer installer, CompatTool? tool=null)
		{
			if(installer is Runnable.DownloadableInstaller)
			{
				var dl_installer = (Runnable.DownloadableInstaller) installer;

				yield dl_installer.fetch_parts();

				if(response_id == InstallDialog.RESPONSE_DOWNLOAD)
				{
					yield dl_installer.download(runnable);
				}
			}
			if(response_id == ResponseType.ACCEPT)
			{
				yield installer.install(runnable, tool);
			}
			if(callback != null) callback();
		}

		public static string fsize(int64 size)
		{
			if(size > 0)
			{
				return format_size(size);
			}
			return _("Unknown");
		}

		private bool installers_filter(ListBoxRow row)
		{
			var item = row as InstallerRow;
			return item != null && platforms_list.selected >= 0 && platforms_list.selected < Platform.PLATFORMS.length && item.installer.platform == Platform.PLATFORMS[platforms_list.selected];
		}

		private class InstallerRow: ListBoxRow
		{
			public Runnable runnable;
			public Runnable.Installer installer;

			public InstallerRow(Runnable runnable, Runnable.Installer installer)
			{
				this.runnable = runnable;
				this.installer = installer;

				var box = new Box(Orientation.HORIZONTAL, 8);
				box.margin_start = box.margin_end = 8;
				box.margin_top = box.margin_bottom = 4;

				var icon = new Image.from_icon_name(installer.platform.icon(), IconSize.BUTTON);

				var name = new Label(installer.name);
				name.hexpand = true;
				name.halign = Align.START;

				var size = new Label("calculating...");
				Utils.thread("CalculatingFileSize", () => {
					size.label = fsize(installer.full_size);
				});

				size.halign = Align.END;

				box.add(icon);
				box.add(name);
				box.add(size);
				child = box;
			}
		}
	}
}
