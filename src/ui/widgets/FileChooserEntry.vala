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

		public FileChooser       chooser          { get; protected set; }

		public FileChooserEntry(string? title, FileChooserAction action, string? icon=null, string? hint=null, bool allow_url=false, bool allow_executable=false)
		{
			Object(title: title, action: action, allow_url: allow_url, allow_executable: allow_executable);
			placeholder_text = primary_icon_tooltip_text = hint;
			primary_icon_name = icon ?? (directory_mode ? "folder" : "application-x-executable");
			primary_icon_activatable = false;
			secondary_icon_name = "folder-symbolic";
			secondary_icon_activatable = true;
			secondary_icon_tooltip_text = directory_mode ? _("Select directory") : _("Select file");
		}

		construct
		{
			#if GTK_3_22
			chooser = new FileChooserNative(title ?? _("Select file"), GameHub.UI.Windows.MainWindow.instance, action, _("Select"), _("Cancel"));
			#else
			chooser = new FileChooserDialog(title ?? _("Select file"), GameHub.UI.Windows.MainWindow.instance, action, _("Select"), ResponseType.ACCEPT, _("Cancel"), ResponseType.CANCEL);
			#endif

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
			else if(path.has_prefix("/"))
			{
				file = File.new_for_path(path);
				uri = file.get_uri();
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
					file = File.new_for_path("/usr/bin/" + text);
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
				text = file.get_path();
			}

			if(allow_url)
			{
				text = uri ?? "";
			}

			scroll_to_end();

			file_set();
			uri_set();
		}

		public void select_file(File? f)
		{
			select_file_path(f != null ? f.get_path() : null);
		}

		public void reset()
		{
			select_file_path(null);
		}

		private int run_chooser()
		{
			#if GTK_3_22
			return (chooser as FileChooserNative).run();
			#else
			return (chooser as FileChooserDialog).run();
			#endif
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
