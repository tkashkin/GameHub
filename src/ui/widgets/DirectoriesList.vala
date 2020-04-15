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
using Gee;

using GameHub.Utils;

namespace GameHub.UI.Widgets
{
	public class DirectoriesList: Box
	{
		public ArrayList<string> directories { get; construct set; }
		public string? selected_directory { get; construct set; default = null; }
		public string? subdir_suffix { get; construct set; default = null; }
		public bool is_readonly { get; construct; default = false; }

		public signal void directory_selected(string? directory);
		public signal void directory_activated(string? directory);

		private ListBox list { get; protected set; }
		private FileChooserEntry? new_dir_entry;

		public DirectoriesList(ArrayList<string>? directories, string? selected_directory=null, string? subdir_suffix=null, bool is_readonly=true)
		{
			Object(directories: directories ?? new ArrayList<string>(), selected_directory: selected_directory, subdir_suffix: subdir_suffix, is_readonly: is_readonly);
		}

		public DirectoriesList.with_array(string[]? directories, string? selected_directory=null, string? subdir_suffix=null, bool is_readonly=true)
		{
			Object(directories: directories != null ? new ArrayList<string>.wrap(directories) : new ArrayList<string>(), selected_directory: selected_directory, subdir_suffix: subdir_suffix, is_readonly: is_readonly);
		}

		public DirectoriesList.with_files(ArrayList<File>? directories, File? selected_directory=null, string? subdir_suffix=null, bool is_readonly=true)
		{
			ArrayList<string>? dirs = null;
			if(directories != null)
			{
				dirs = new ArrayList<string>();
				foreach(var dir in directories)
				{
					dirs.add(dir.get_path());
				}
			}
			Object(directories: dirs, selected_directory: selected_directory != null ? selected_directory.get_path() : null, subdir_suffix: subdir_suffix, is_readonly: is_readonly);
		}

		public string[] directories_array
		{
			owned get
			{
				string[] dirs = {};
				if(selected_directory != null)
				{
					dirs += selected_directory;
				}
				foreach(var dir in directories)
				{
					if(!(dir in dirs))
					{
						dirs += dir;
					}
				}
				return dirs;
			}
		}

		construct
		{
			orientation = Orientation.VERTICAL;
			get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);

			var scroll = new ScrolledWindow(null, null);
			scroll.hscrollbar_policy = PolicyType.NEVER;
			scroll.expand = true;

			list = new ListBox();
			list.selection_mode = SelectionMode.SINGLE;
			list.get_style_context().add_class("separated-list-all");

			list.row_selected.connect(row => {
				if(row != null)
				{
					selected_directory = ((DirectoryRow) row).directory;
					directory_selected(selected_directory);
				}
			});

			list.row_activated.connect(row => {
				if(row != null)
				{
					selected_directory = ((DirectoryRow) row).directory;
					directory_selected(selected_directory);
					directory_activated(selected_directory);
				}
			});

			scroll.add(list);

			add(scroll);

			if(!is_readonly)
			{
				new_dir_entry = new FileChooserEntry(_("Add game directory"), FileChooserAction.SELECT_FOLDER, "list-add-symbolic", _("Add game directory"));
				new_dir_entry.margin_start = new_dir_entry.margin_end = 3;
				new_dir_entry.hexpand = true;

				new_dir_entry.file_set.connect(() => {
					if(new_dir_entry.file != null)
					{
						dir_add(new_dir_entry.file.get_path());
						new_dir_entry.reset();
					}
				});

				var actionbar = new ActionBar();
				actionbar.add(new_dir_entry);
				add(actionbar);
			}

			update();
		}

		private void update()
		{
			list.foreach(r => r.destroy());

			if(directories != null)
			{
				foreach(var dir in directories)
				{
					row_add(dir);
				}
			}

			show_all();
		}

		private void row_add(string dir)
		{
			var row = new DirectoryRow(dir, this);
			list.add(row);
			if(dir == selected_directory)
			{
				list.select_row(row);
			}
		}

		public void dir_add(string directory)
		{
			if(!is_readonly && !(directory in directories))
			{
				directories.add(directory);
				row_add(directory);
				notify_property("directories");
			}
		}

		public void dir_remove(string directory)
		{
			if(is_readonly || directories.size <= 1) return;
			if(directory == selected_directory)
			{
				foreach(var dir in directories)
				{
					if(dir != directory)
					{
						selected_directory = dir;
						break;
					}
				}
			}
			directories.remove(directory);
			notify_property("directories");
			update();
		}

		public class DirectoryRow: ListBoxRow
		{
			public string directory { get; construct set; }
			public DirectoriesList list { get; construct; }

			private Label info_label;

			public DirectoryRow(string directory, DirectoriesList list)
			{
				Object(directory: directory, list: list);
			}

			construct
			{
				var dir = FS.file(directory);

				var grid = new Grid();
				grid.margin_start = grid.margin_end = 8;
				grid.margin_top = grid.margin_bottom = 4;

				var icon = new Image.from_icon_name("folder", IconSize.LARGE_TOOLBAR);
				icon.valign = Align.CENTER;
				icon.margin_end = 12;

				var path_label = new Label(dir.get_path());
				path_label.tooltip_text = dir.get_path();
				path_label.get_style_context().add_class("bold");
				path_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
				path_label.xalign = 0;
				path_label.valign = Align.CENTER;

				info_label = new Label(_("Measuring available disk space…"));
				info_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
				info_label.use_markup = true;
				info_label.hexpand = true;
				info_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
				info_label.xalign = 0;
				info_label.valign = Align.CENTER;

				grid.attach(icon, 0, 0, 1, 2);
				grid.attach(path_label, 1, 0);
				grid.attach(info_label, 1, 1, 2, 1);

				if(list.subdir_suffix != null)
				{
					var subdir_suffix_label = new Label(@"/$(list.subdir_suffix)");
					subdir_suffix_label.get_style_context().add_class(Gtk.STYLE_CLASS_DIM_LABEL);
					subdir_suffix_label.hexpand = true;
					subdir_suffix_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
					subdir_suffix_label.xalign = 0;
					subdir_suffix_label.valign = Align.CENTER;
					grid.attach(subdir_suffix_label, 2, 0);
				}

				if(!list.is_readonly)
				{
					var remove_button = new Button.from_icon_name("edit-delete-symbolic", IconSize.BUTTON);
					remove_button.get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);
					remove_button.valign = Align.CENTER;
					remove_button.tooltip_text = _("Remove");
					remove_button.margin_start = 12;
					remove_button.sensitive = list.directories.size > 1;
					grid.attach(remove_button, 3, 0, 1, 2);

					remove_button.clicked.connect(() => {
						list.dir_remove(directory);
					});
				}

				child = grid;
				show_all();

				measure_disk_space.begin(dir);
			}

			private async void measure_disk_space(File dir)
			{
				var current_dir = dir;
				while(true)
				{
					if(current_dir.query_exists())
					{
						current_dir.query_filesystem_info_async.begin(string.join(",", FileAttribute.FILESYSTEM_FREE, FileAttribute.FILESYSTEM_TYPE), Priority.DEFAULT, null, (obj, res) => {
							try
							{
								var fs_info = current_dir.query_filesystem_info_async.end(res);

								var fs_free = fs_info.get_attribute_uint64(FileAttribute.FILESYSTEM_FREE);
								var fs_type = fs_info.get_attribute_string(FileAttribute.FILESYSTEM_TYPE);

								string[] info_parts = {};

								if(fs_free > 0)
								{
									info_parts += _("Available disk space: %s").printf("<b>" + format_size(fs_free) + "</b>");
								}

								if(fs_type != null)
								{
									info_parts += fs_type;
								}

								Idle.add(() => {
									info_label.label = string.joinv(" • ", info_parts);
									return Source.REMOVE;
								});
								return;
							}
							catch(Error e)
							{
								warning("[DirectoryRow.measure_disk_space] %s", e.message);
							}
						});
						return;
					}
					current_dir = current_dir.get_parent();
				}
			}
		}
	}
}
