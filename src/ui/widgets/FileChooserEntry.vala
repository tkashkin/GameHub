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

			activate.connect(() => update(false));
			focus_out_event.connect(() => { update(false); return false; });
			chooser.selection_changed.connect(() => update(true));

			icon_press.connect((icon, event) => {
				if(icon == EntryIconPosition.SECONDARY && ((EventButton) event).button == 1)
				{
					if(run_chooser() == ResponseType.ACCEPT)
					{
						update(true);
					}
				}
			});
		}

		private void update(bool from_chooser)
		{
			try
			{
				if(!from_chooser)
				{
					text = text.strip();
					scroll_to_end();
					if(allow_url)
					{
						if(text.has_prefix("file://"))
						{
							chooser.select_uri(text);
						}
						uri = text;
						uri_set();
					}
					else if(text.has_prefix("/"))
					{
						chooser.select_filename(text);
						file = chooser.get_file();
						file_set();
					}
					else if(allow_executable && text.length > 0)
					{
						var executable = Utils.find_executable(text);
						if(executable != null && executable.query_exists())
						{
							chooser.select_file(executable);
						}
						else
						{
							chooser.select_filename("/usr/bin/" + text);
						}
						file = chooser.get_file();
						file_set();
					}
				}
				else
				{
					var f = chooser.get_file();

					if(f != null)
					{
						text = allow_url ? f.get_uri() : f.get_path();
						scroll_to_end();
					}

					file = f;
					file_set();

					if(allow_url && f != null)
					{
						uri = f.get_uri();
						uri_set();
					}
				}
			}
			catch(Error e)
			{
				warning("[FileChooserEntry.update] %s", e.message);
			}
		}

		public void select_file(File? f)
		{
			try
			{
				if(f != null)
				{
					chooser.select_file(f);
					text = allow_url ? f.get_uri() : f.get_path();
					scroll_to_end();
				}
				else
				{
					chooser.unselect_all();
				}
			}
			catch(Error e)
			{
				warning("[FileChooserEntry.select_file] %s", e.message);
			}

			update(true);
			file = f;
			file_set();
			if(allow_url && f != null)
			{
				uri = f.get_uri();
				uri_set();
			}
		}

		public void reset()
		{
			chooser.unselect_all();
			text = "";
			update(false);
			file = null;
			uri = null;
			file_set();
			uri_set();
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
