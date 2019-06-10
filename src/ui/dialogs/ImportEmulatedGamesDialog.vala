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
using Granite;
using GLib;
using Gee;
using GameHub.Utils;
using GameHub.UI.Widgets;

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Data.Compat;
using GameHub.Data.Sources.User;

namespace GameHub.UI.Dialogs
{
	public class ImportEmulatedGamesDialog: Dialog
	{
		private const string[] LIBRETRO_IGNORED_CORES = { "3dengine", "ffmpeg", "dosbox", "dosbox_svn", "dosbox_svn_glide" };
		private const string[] LIBRETRO_IGNORED_FILES = { "bin", "dat", "exe", "zip", "7z", "gz" };

		private const int RESPONSE_IMPORT = 10;

		public signal void game_added(UserGame game);

		private Box content;

		private FileChooserEntry dir_chooser;

		private Label status_label;
		private Spinner status_spinner;

		private ScrolledWindow found_list_scroll;
		private ListBox found_list;

		private CheckButton select_all;
		private Button import_btn;

		public ImportEmulatedGamesDialog()
		{
			Object(transient_for: Windows.MainWindow.instance, resizable: false, title: _("Import emulated games"));
		}

		construct
		{
			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			modal = true;

			content = new Box(Orientation.VERTICAL, 4);
			content.set_size_request(640, 480);
			content.margin = 4;

			var dir_hbox = new Box(Orientation.HORIZONTAL, 12);
			dir_hbox.margin_start = dir_hbox.margin_end = 8;

			dir_chooser = new FileChooserEntry(_("Select directory with emulated games"), FileChooserAction.SELECT_FOLDER);
			dir_chooser.hexpand = true;

			dir_chooser.file_set.connect(start_search);

			dir_hbox.add(new HeaderLabel(_("Directory")));
			dir_hbox.add(dir_chooser);

			var header_label = new HeaderLabel(_("Detected games"));
			header_label.margin_start = header_label.margin_end = 8;
			header_label.xalign = 0;
			header_label.hexpand = true;

			found_list_scroll = new ScrolledWindow(null, null);
			found_list_scroll.expand = true;
			found_list_scroll.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);

			found_list = new ListBox();
			found_list.selection_mode = SelectionMode.NONE;
			found_list.sensitive = false;

			found_list.set_header_func((row, prev) => ((EmulatedGameRow) row).setup_header((EmulatedGameRow) prev));

			found_list_scroll.add(found_list);

			content.add(dir_hbox);
			content.add(header_label);
			content.add(found_list_scroll);

			var status_hbox = new Box(Orientation.HORIZONTAL, 10);
			status_hbox.margin_start = 6;

			select_all = new CheckButton.with_label(_("Select all"));
			select_all.margin_start = 2;
			select_all.active = true;
			select_all.no_show_all = true;
			select_all.visible = false;
			select_all.xalign = 0.5f;
			select_all.toggled.connect(select_all_toggled);

			status_label = new Label(_("Select directory to import"));
			status_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
			status_label.margin_start = 2;
			status_label.xalign = 0;
			status_label.hexpand = true;

			status_spinner = new Spinner();
			status_spinner.halign = Align.END;
			status_spinner.no_show_all = true;
			status_spinner.visible = false;

			status_hbox.add(select_all);
			status_hbox.add(status_spinner);
			status_hbox.add(status_label);

			import_btn = (Button) add_button(_("Import"), RESPONSE_IMPORT);
			import_btn.get_style_context().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
			import_btn.sensitive = false;

			var bbox = (ButtonBox) import_btn.get_parent();
			bbox.margin_end = 8;
			bbox.add(status_hbox);
			bbox.set_child_secondary(status_hbox, true);
			bbox.set_child_non_homogeneous(status_hbox, true);

			response.connect((source, response_id) => {
				switch(response_id)
				{
					case RESPONSE_IMPORT:
						found_list.foreach(r => {
							var row = (EmulatedGameRow) r;
							row.import_as_usergame();
						});
						destroy();
						break;
				}
			});

			delete_event.connect(() => {
				destroy();
			});

			get_content_area().add(content);

			show_all();
		}

		private bool is_toggling_selection = false;
		private bool is_updating_selection = false;
		private void select_all_toggled()
		{
			if(is_toggling_selection || is_updating_selection) return;
			is_toggling_selection = true;

			select_all.inconsistent = false;
			found_list.foreach(r => {
				var row = (EmulatedGameRow) r;
				row.import.active = select_all.active;
			});

			is_toggling_selection = false;

			update_selection();
		}

		private void update_selection()
		{
			if(is_updating_selection || is_toggling_selection) return;
			is_updating_selection = true;

			bool all_selected = true;
			bool none_selected = true;

			found_list.foreach(r => {
				var row = (EmulatedGameRow) r;
				all_selected = all_selected && row.import.active;
				none_selected = none_selected && !row.import.active;
			});

			select_all.active = all_selected;
			select_all.inconsistent = !all_selected && !none_selected;

			import_btn.sensitive = !none_selected;

			is_updating_selection = false;
		}

		private void add_row(EmulatedGameRow row)
		{
			found_list.add(row);
			row.game_added.connect(g => game_added(g));
			row.import.toggled.connect(update_selection);
		}

		private void start_search()
		{
			if(!dir_chooser.sensitive || dir_chooser.file == null) return;

			dir_chooser.sensitive = false;
			select_all.visible = false;
			found_list.sensitive = false;
			status_spinner.visible = true;
			status_spinner.start();

			Utils.thread("ImportEmulatedGamesDialogSearch", () => {
				debug("[ImportEmulatedGamesDialog] Starting search in '%s'", dir_chooser.file.get_path());

				search_emulators();
				search_retroarch();

				Idle.add(() => {
					select_all.visible = true;
					found_list.sensitive = true;
					status_spinner.visible = false;
					status_spinner.stop();
					status_label.label = null;
					update_selection();
					return Source.REMOVE;
				});
			});
		}

		private void search_emulators()
		{
			var root = dir_chooser.file;

			var emulators = Tables.Emulators.get_all();
			foreach(var emu in emulators)
			{
				var pattern = emu.game_executable_pattern;
				if(pattern != null) pattern = pattern.strip();

				if(pattern.length > 0)
				{
					var subpatterns = pattern.split("|");
					foreach(var sp in subpatterns)
					{
						var files_list = Utils.run({ "find", root.get_path(), "-path", "*/" + sp }, null, null, false, true, false);
						var files = files_list.split("\n");

						foreach(var file in files)
						{
							debug("[search_emulators] %s: %s", emu.name, file);
							var game = new EmulatedGame(FSUtils.file(file), emu);
							Idle.add(() => {
								add_row(new EmulatedGameRow(game));
								return Source.REMOVE;
							});
						}
					}
				}
			}
		}

		private void search_retroarch()
		{
			var root = dir_chooser.file;

			var retroarch = RetroArch.instance;
			if(!retroarch.installed)
			{
				warning("[search_retroarch] RetroArch is not installed");
				return;
			}
			if(!retroarch.has_cores)
			{
				warning("[search_retroarch] No libretro cores found");
				return;
			}

			var core_info_dir = FSUtils.file(FSUtils.Paths.Settings.get_instance().libretro_core_info_dir);

			if(core_info_dir == null || !core_info_dir.query_exists())
			{
				warning("[search_retroarch] libretro core info dir does not exist");
				return;
			}

			foreach(var core in retroarch.cores)
			{
				if(core in LIBRETRO_IGNORED_CORES) continue;

				var info = core_info_dir.get_child(core + RetroArch.LIBRETRO_CORE_INFO_SUFFIX);

				if(info == null || !info.query_exists()) continue;

				status_label.label = "RetroArch: " + core;

				try
				{
					string full_info;
					FileUtils.get_contents(info.get_path(), out full_info);

					if(!("supported_extensions = \"" in full_info)) continue;

					string? display_name = null;

					var lines = full_info.split("\n");
					foreach(var line in lines)
					{
						if("display_name = \"" in line)
						{
							display_name = line.replace("display_name = \"", "").replace("\"", "").strip();
							status_label.label = "RetroArch: " + display_name;
						}
						else if("supported_extensions = \"" in line)
						{
							var exts_list = line.replace("supported_extensions = \"", "").replace("\"", "").strip();
							if(exts_list.length > 0)
							{
								var exts = exts_list.split("|");
								foreach(var ext in exts)
								{
									if(ext in LIBRETRO_IGNORED_FILES) continue;

									var files_list = Utils.run({ "find", root.get_path(), "-path", "*/*." + ext }, null, null, false, true, false);
									var files = files_list.split("\n");

									foreach(var file in files)
									{
										debug("[search_retroarch] %s: %s", core, file);
										var game = new EmulatedGame.libretro(FSUtils.file(file), core, display_name);
										Idle.add(() => {
											add_row(new EmulatedGameRow(game));
											return Source.REMOVE;
										});
									}
								}
							}
							break;
						}
					}
				}
				catch(Error e)
				{
					warning("[search_retroarch] Error while reading core info: %s", e.message);
				}
			}
		}

		private class EmulatedGame
		{
			public File file;

			public Emulator? emulator = null;

			public string? libretro_core = null;
			public bool uses_libretro = false;

			public string header;
			public string? header_subtitle;

			public EmulatedGame(File file, Emulator emulator)
			{
				this.file = file;
				this.emulator = emulator;
				this.uses_libretro = false;
				this.header = emulator.name;
			}

			public EmulatedGame.libretro(File file, string core, string? display_name)
			{
				this.file = file;
				this.libretro_core = core;
				this.uses_libretro = true;
				this.header = "RetroArch: " + display_name ?? core;
				if(display_name != null) this.header_subtitle = core;
			}
		}

		private class EmulatedGameRow: ListBoxRow
		{
			public signal void game_added(UserGame game);

			public EmulatedGame game;
			public CheckButton import;
			public Entry title;

			public EmulatedGameRow(EmulatedGame game)
			{
				this.game = game;

				var hbox = new Box(Orientation.HORIZONTAL, 8);
				hbox.margin_start = hbox.margin_end = 8;
				hbox.margin_top = hbox.margin_bottom = 4;

				import = new CheckButton();
				import.active = true;

				title = new Entry();
				title.expand = true;
				title.xalign = 0;

				title.text = game.file.get_basename();

				var ext_index = title.text.last_index_of_char('.');
				if(ext_index > 0)
				{
					title.text = title.text.substring(0, ext_index);
				}

				tooltip_text = game.file.get_path();

				import.toggled.connect(() => {
					title.sensitive = import.active;
				});

				hbox.add(import);
				hbox.add(title);

				child = hbox;
				show_all();
			}

			public void setup_header(EmulatedGameRow? prev)
			{
				if(prev == null || prev.game.header != game.header)
				{
					var hbox = new Box(Orientation.HORIZONTAL, 8);
					var header = new HeaderLabel(game.header);
					header.expand = true;
					hbox.add(header);
					if(game.header_subtitle != null)
					{
						var subtitle = new Label(game.header_subtitle);
						subtitle.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
						subtitle.margin_start = subtitle.margin_end = 8;
						hbox.add(subtitle);
					}
					hbox.show_all();
					set_header(hbox);
				}
				else
				{
					set_header(null);
				}
			}

			public void import_as_usergame()
			{
				if(!import.active) return;

				var g = new UserGame(title.text.strip() + " [%s]".printf(game.uses_libretro ? game.libretro_core : game.header), game.file.get_parent(), game.file, "", false);

				if(game.uses_libretro)
				{
					g.compat_tool = "retroarch";
					g.compat_tool_settings = "{\"compat_options_saved\":true,\"force_compat\":true,\"retroarch\":{\"options\":{\"core\":\"" + game.libretro_core + "\"}}}";
				}
				else
				{
					g.compat_tool = "emulator";
					g.compat_tool_settings = "{\"compat_options_saved\":true,\"force_compat\":true,\"emulator\":{\"options\":{\"emulator\":\"" + game.emulator.name + "\"}}}";
				}

				g.save();
				game_added(g);
			}
		}
	}
}
