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
using Gdk;

using GameHub.Utils;

namespace GameHub.UI.Widgets
{
	public class FileChooserEntry: Entry
	{
		public signal void file_set();
		public signal void uri_set();

		public File?             file             { get; protected set; }
		public string?           uri              { get; protected set; }

		public string?           title            { get; construct; }
		public FileChooserAction action           { get; construct; }
		public bool              allow_url        { get; construct; }
		public bool              allow_executable { get; construct; }
		public string?           root_dir_prefix  { get; set; }

		public FileChooserNative chooser          { get; protected set; }

		public string? file_path
		{
			get { return text; }
			set { select_file_path(value); }
		}

		public FileChooserEntry(string? title, FileChooserAction action, string? icon=null, string? hint=null, bool allow_url=false, bool allow_executable=false, string? root_dir_prefix=null)
		{
			Object(title: title, action: action, allow_url: allow_url, allow_executable: allow_executable, root_dir_prefix: root_dir_prefix);
			placeholder_text = primary_icon_tooltip_text = hint;
			primary_icon_name = icon ?? (directory_mode ? "folder" : "application-x-executable");
			primary_icon_activatable = false;
			secondary_icon_name = "folder-symbolic";
			secondary_icon_activatable = true;
			secondary_icon_tooltip_text = directory_mode ? _("Select directory") : _("Select file");
		}

		construct
		{
			chooser = new FileChooserNative(title ?? _("Select file"), GameHub.UI.Windows.MainWindow.instance, action, _("Select"), _("Cancel"));

			activate.connect(() => {
				select_file_path(text);
			});
			focus_out_event.connect(() => {
				select_file_path(text);
				return false;
			});

			icon_press.connect((icon, event) => {
				if(icon == EntryIconPosition.SECONDARY && ((EventButton) event).button == 1)
				{
					if(run_chooser() == ResponseType.ACCEPT)
					{
						select_file(chooser.get_file());
					}
				}
			});
		}

		public void select_file_path(string? path_or_uri)
		{
			if(path_or_uri == null || path_or_uri.strip().length == 0)
			{
				text = "";
				chooser.unselect_all();
				file = null;
				uri = null;
				file_set();
				uri_set();
				return;
			}

			var path = path_or_uri.strip();

			if(allow_url && (path.has_prefix("file://") || path.has_prefix("https://") || path.has_prefix("http://") || path.has_prefix("ftp://")))
			{
				uri = path;
				if(text.has_prefix("file://"))
				{
					file = File.new_for_uri(uri);
				}
			}
			else if(path.has_prefix("/") || path.has_prefix("~"))
			{
				file = FS.file(path);
				uri = file.get_uri();
			}
			else if(root_dir_prefix != null && (path == "." || path.has_prefix("./")))
			{
				select_file_path(Utils.replace_prefix(path, ".", root_dir_prefix));
				return;
			}
			else if(allow_executable && path.length > 0)
			{
				var executable = Utils.find_executable(path);
				if(executable != null && executable.query_exists())
				{
					file = executable;
				}
				else
				{
					file = FS.file("/usr/bin", text);
				}
				uri = file.get_uri();
			}

			text = "";

			if(file != null)
			{
				if(file.query_exists())
				{
					try
					{
						chooser.select_file(file);
					}
					catch(Error e)
					{
						warning("[FileChooserEntry.select_file_path] %s", e.message);
					}
				}
				else
				{
					chooser.unselect_all();
				}
				if(root_dir_prefix != null && file.get_path().has_prefix(root_dir_prefix))
				{
					text = file.get_path().replace(root_dir_prefix, ".");
				}
				else
				{
					text = file.get_path();
				}
			}

			if(allow_url)
			{
				text = uri ?? "";
			}

			scroll_to_end();

			file_set();
			uri_set();
			notify_property("file-path");
		}

		public void select_file(File? f)
		{
			select_file_path(f != null ? f.get_path() : null);
		}

		public void set_default_directory(File? directory)
		{
			if(directory != null && directory.query_exists())
			{
				try
				{
					chooser.set_current_folder_file(directory);
				}
				catch(Error e)
				{
					warning("[FileChooserEntry.set_default_directory] %s", e.message);
				}
			}
		}

		public void reset()
		{
			select_file_path(null);
		}

		private int run_chooser()
		{
			return chooser.run();
		}

		private void scroll_to_end()
		{
			if(cursor_position < text.length)
			{
				move_cursor(MovementStep.BUFFER_ENDS, 1, false);
			}
		}

		private bool directory_mode
		{
			get
			{
				return action == FileChooserAction.SELECT_FOLDER || action == FileChooserAction.CREATE_FOLDER;
			}
		}
	}
}
