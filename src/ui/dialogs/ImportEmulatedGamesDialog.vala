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
using GameHub.Data.DB;
using GameHub.Data.Compat;
using GameHub.Data.Sources.User;

namespace GameHub.UI.Dialogs
{
	public class ImportEmulatedGamesDialog: Dialog
	{
		private const int RESPONSE_IMPORT = 10;

		public signal void game_added(UserGame game);

		private HashMap<string, EmulatedGame> detected_games;

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
			get_style_context().add_class("import-emulated-games-dialog");

			modal = true;

			content = new Box(Orientation.VERTICAL, 4);
			content.set_size_request(640, 480);
			content.margin = 4;

			var dir_hbox = new Box(Orientation.HORIZONTAL, 12);
			dir_hbox.margin_start = dir_hbox.margin_end = 8;

			dir_chooser = new FileChooserEntry(_("Select directory with emulated games"), FileChooserAction.SELECT_FOLDER);
			dir_chooser.hexpand = true;

			dir_chooser.file_set.connect(start_search);

			dir_hbox.add(Styled.H4Label(_("Directory")));
			dir_hbox.add(dir_chooser);

			var header_label = Styled.H4Label(_("Detected games"));
			header_label.margin_start = header_label.margin_end = 8;
			header_label.xalign = 0;
			header_label.hexpand = true;

			found_list_scroll = new ScrolledWindow(null, null);
			found_list_scroll.expand = true;
			found_list_scroll.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);

			found_list = new ListBox();
			found_list.selection_mode = SelectionMode.NONE;
			found_list.sensitive = false;

			found_list.set_sort_func((row, row2) => ((EmulatedGameRow) row).sort((EmulatedGameRow) row2));
			found_list.set_header_func((row, prev) => ((EmulatedGameRow) row).header((EmulatedGameRow) prev));

			found_list_scroll.add(found_list);

			content.add(dir_hbox);
			content.add(header_label);
			content.add(found_list_scroll);

			var status_hbox = new Box(Orientation.HORIZONTAL, 10);

			select_all = new CheckButton.with_label(_("Select all"));
			select_all.get_style_context().add_class("select-all");
			select_all.active = true;
			select_all.no_show_all = true;
			select_all.visible = false;
			select_all.xalign = 0.5f;
			select_all.toggled.connect(select_all_toggled);

			status_label = new Label(_("Select directory to import"));
			status_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
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

			detected_games = new HashMap<string, EmulatedGame>();

			found_list.foreach(r => r.destroy());

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

					foreach(var game in detected_games.values)
					{
						add_row(new EmulatedGameRow(game));
					}

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
						sp = sp.strip();
						bool is_dir_based = sp.has_prefix("./");

						if(is_dir_based)
						{
							if(sp == "./") continue;
							sp = sp.substring(sp.index_of_nth_char(2));
						}

						var files_list = Utils.run({"find", root.get_path(), "-path", "*/" + sp, "-type", "f"}).log(false).run_sync_nofail(true).output;
						var files = files_list.split("\n");

						foreach(var file_path in files)
						{
							var file = FSUtils.file(file_path);

							var dir = file.get_parent();
							var name = file.get_basename();

							if(is_dir_based)
							{
								if("/" in sp)
								{
									var sp_parts = sp.split("/");
									for(int i = 0; i < sp_parts.length - 1; i++)
									{
										dir = dir.get_parent();
									}
								}
								name = dir.get_basename();
							}
							else
							{
								var ext_index = name.last_index_of_char('.');
								if(ext_index > 0)
								{
									name = name.substring(0, ext_index);
								}
							}

							debug("[search_emulators: %s] '%s': %s [%s]", emu.name, name, file.get_path(), dir.get_path());

							var tool = new EmulatedGame.Tool(emu);
							var game = detected_games.has_key(file_path) ? detected_games.get(file_path) : new EmulatedGame(name, file, dir, is_dir_based ? dir.get_parent() : dir);
							game.tools.add(tool);
							detected_games.set(file_path, game);
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

			var core_info_dir = FSUtils.file(Settings.Compat.RetroArch.instance.core_info_dir);

			if(core_info_dir == null || !core_info_dir.query_exists())
			{
				warning("[search_retroarch] libretro core info dir does not exist");
				return;
			}

			var ignored_cores = Settings.Compat.RetroArch.instance.cores_blacklist.split("|");
			var ignored_extensions = Settings.Compat.RetroArch.instance.game_executable_extensions_blacklist.split("|");

			foreach(var core in retroarch.cores)
			{
				if(core in ignored_cores) continue;

				var info = core_info_dir.get_child(core + RetroArch.LIBRETRO_CORE_INFO_SUFFIX);

				if(info == null || !info.query_exists()) continue;

				status_label.label = "RetroArch: " + core;

				try
				{
					string full_info;
					FileUtils.get_contents(info.get_path(), out full_info);

					if(!("supported_extensions = \"" in full_info)) continue;

					string? core_name = null;
					string? display_name = null;
					string? supported_extensions = null;

					var lines = full_info.split("\n");
					foreach(var line in lines)
					{
						if("corename = \"" in line)
						{
							core_name = line.replace("corename = \"", "").replace("\"", "").strip();
						}
						else if("display_name = \"" in line)
						{
							display_name = line.replace("display_name = \"", "").replace("\"", "").strip();
							status_label.label = "RetroArch: " + display_name;
						}
						else if("supported_extensions = \"" in line)
						{
							supported_extensions = line.replace("supported_extensions = \"", "").replace("\"", "").strip();
						}
					}

					if(supported_extensions != null && supported_extensions.length > 0)
					{
						var exts = supported_extensions.split("|");
						foreach(var ext in exts)
						{
							ext = ext.strip();
							if(ext in ignored_extensions) continue;

							var files_list = Utils.run({"find", root.get_path(), "-path", "*/*." + ext, "-type", "f"}).log(false).run_sync_nofail(true).output;
							var files = files_list.split("\n");

							foreach(var file_path in files)
							{
								var file = FSUtils.file(file_path);

								var dir = file.get_parent();
								var name = file.get_basename();

								var ext_index = name.last_index_of_char('.');
								if(ext_index > 0)
								{
									name = name.substring(0, ext_index);
								}

								debug("[search_retroarch: %s] '%s': %s [%s]", core, name, file.get_path(), dir.get_path());

								var tool = new EmulatedGame.Tool.libretro(core, core_name, display_name);
								var game = detected_games.has_key(file_path) ? detected_games.get(file_path) : new EmulatedGame(name, file, dir, dir);
								game.tools.add(tool);
								detected_games.set(file_path, game);
							}
						}
					}
				}
				catch(Error e)
				{
					warning("[search_retroarch] Error while reading core info: %s", e.message);
				}
			}
		}

		private class EmulatedGame: Object
		{
			public string name;
			public File file;
			public File directory;
			public File parent_directory;
			public ArrayList<Tool> tools;

			public EmulatedGame(string name, File file, File directory, File parent_directory)
			{
				this.name = name;
				this.file = file;
				this.directory = directory;
				this.parent_directory = parent_directory;
				this.tools = new ArrayList<Tool>();
			}

			public class Tool: Object
			{
				public string short_name;
				public string name;
				public Emulator? emulator = null;
				public string? libretro_core = null;
				public bool uses_libretro = false;

				public Tool(Emulator emulator)
				{
					this.short_name = this.name = emulator.name;
					this.emulator = emulator;
					this.uses_libretro = false;
				}

				public Tool.libretro(string core, string? core_name, string? display_name)
				{
					this.short_name = "RetroArch: " + (core_name != null ? core_name : core);
					this.name = "RetroArch: " + (display_name != null ? display_name : (core_name != null ? core_name : core));
					this.libretro_core = core;
					this.uses_libretro = true;
				}
			}
		}

		private class EmulatedGameRow: ListBoxRow
		{
			public signal void game_added(UserGame game);

			public EmulatedGame game;
			public CheckButton import;
			public Entry title;

			private Gtk.ListStore tools_model;
			private int tools_model_size = 0;
			private Gtk.TreeIter tools_iter;
			public ComboBox tools;

			public EmulatedGame.Tool selected_tool;

			public EmulatedGameRow(EmulatedGame game)
			{
				this.game = game;

				var grid = new Grid();
				grid.column_spacing = 8;
				grid.margin_start = grid.margin_end = 8;
				grid.margin_top = grid.margin_bottom = 4;

				import = new CheckButton();
				import.active = true;

				var title_hbox = new Box(Orientation.HORIZONTAL, 0);
				title_hbox.expand = true;
				title_hbox.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);

				title = new Entry();
				title.expand = true;
				title.xalign = 0;

				title_hbox.add(title);

				tools_model = new Gtk.ListStore(2, typeof(string), typeof(EmulatedGame.Tool));
				foreach(var tool in game.tools)
				{
					tools_model.append(out tools_iter);
					tools_model.set(tools_iter, 0, tool.short_name);
					tools_model.set(tools_iter, 1, tool);
					tools_model_size++;
				}

				tools = new ComboBox.with_model(tools_model);
				tools.set_size_request(128, -1);
				tools.popup_fixed_width = false;

				CellRendererText r_name = new CellRendererText();
				r_name.ellipsize = Pango.EllipsizeMode.END;
				r_name.width_chars = r_name.max_width_chars = 20;
				r_name.xpad = 4;
				tools.pack_start(r_name, true);
				tools.add_attribute(r_name, "text", 0);

				tools.changed.connect(() => {
					if(tools_model_size == 0) return;
					Value v;
					tools.get_active_iter(out tools_iter);
					tools_model.get_value(tools_iter, 1, out v);
					selected_tool = v as EmulatedGame.Tool;
					tools.tooltip_text = selected_tool.name;
				});

				tools.active = 0;
				tools.sensitive = tools_model_size > 1;

				title_hbox.add(tools);

				title.text = game.name;
				tooltip_text = game.file.get_path();

				import.toggled.connect(() => {
					title_hbox.sensitive = import.active;
				});

				grid.attach(import, 0, 0);
				grid.attach(title_hbox, 1, 0);

				child = grid;
				show_all();
			}

			public int sort(EmulatedGameRow other)
			{
				var dir = game.parent_directory.get_path();
				var other_dir = other.game.parent_directory.get_path();
				return strcmp(dir.collate_key_for_filename(), other_dir.collate_key_for_filename());
			}

			public void header(EmulatedGameRow? prev)
			{
				if(prev == null || prev.game.parent_directory.get_path() != game.parent_directory.get_path())
				{
					var header = Styled.H4Label(game.parent_directory.get_path());
					header.margin_end = 8;
					header.ellipsize = Pango.EllipsizeMode.START;
					header.tooltip_text = header.label;
					header.expand = false;
					header.show_all();
					set_header(header);
				}
				else
				{
					set_header(null);
				}
			}

			public void import_as_usergame()
			{
				if(!import.active) return;

				var g = new UserGame(title.text.strip(), game.directory, game.file, "", false);

				if(selected_tool.uses_libretro)
				{
					g.compat_tool = "retroarch";
					g.compat_tool_settings = "{\"compat_options_saved\":true,\"force_compat\":true,\"retroarch\":{\"options\":{\"core\":\"" + selected_tool.libretro_core + "\"}}}";
				}
				else
				{
					g.compat_tool = "emulator";
					g.compat_tool_settings = "{\"compat_options_saved\":true,\"force_compat\":true,\"emulator\":{\"options\":{\"emulator\":\"" + selected_tool.emulator.name + "\"}}}";

					var basename = game.file.get_basename();
					var ext_index = basename.last_index_of_char('.');
					if(ext_index > 0)
					{
						basename = basename.substring(0, ext_index);
					}

					var image = find_by_pattern(selected_tool.emulator.game_image_pattern, game.directory, basename);
					var icon  = find_by_pattern(selected_tool.emulator.game_icon_pattern,  game.directory, basename);

					if(image != null)
					{
						g.image = image.get_uri();
					}
					if(icon != null)
					{
						g.icon = icon.get_uri();
					}
				}

				g.platforms.clear();
				g.platforms.add(Platform.EMULATED);

				g.save();
				User.instance.add_game(g);
				game_added(g);
			}

			private File? find_by_pattern(string? pattern, File directory, string basename)
			{
				if(pattern != null)
				{
					var subpatterns = pattern.split("|");
					foreach(var sp in subpatterns)
					{
						sp = sp.strip();

						if(sp.has_prefix("./"))
						{
							if(sp == "./") continue;
							sp = sp.substring(sp.index_of_nth_char(2));
						}

						sp = sp.replace("${basename}", basename).replace("$basename", basename);

						var files_list = Utils.run({"find", directory.get_path(), "-path", "*/" + sp}).log(false).run_sync_nofail(true).output;
						var files = files_list.split("\n");

						foreach(var file_path in files)
						{
							var file = FSUtils.file(file_path);
							if(file != null && file.query_exists())
							{
								return file;
							}
						}
					}
				}

				return null;
			}
		}
	}
}
