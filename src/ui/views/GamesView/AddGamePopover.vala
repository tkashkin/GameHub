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
using Gee;
using Granite;
using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Utils;
using GameHub.UI.Widgets;

using GameHub.Data.Sources.User;

namespace GameHub.UI.Views.GamesView
{
	public class AddGamePopover: Popover
	{
		public signal void game_added(UserGame game);

		private Grid grid;
		private int rows = 0;

		private bool suppress_updates = false;

		private Granite.Widgets.ModeButton mode;

		private new Entry name;
		private FileChooserEntry gamedir;
		private FileChooserEntry executable;
		private Label executable_label;
		private Entry arguments;
		private Label arguments_label;
		private new Button add;

		public AddGamePopover(Widget? relative_to)
		{
			Object(relative_to: relative_to);
		}

		construct
		{
			grid = new Grid();
			grid.margin = 8;
			grid.row_spacing = 4;
			grid.column_spacing = 4;

			mode = new Granite.Widgets.ModeButton();
			mode.margin_bottom = 8;
			mode.halign = Align.CENTER;
			mode.append_text(_("Executable"));
			mode.append_text(_("Installer"));
			mode.selected = 0;
			grid.attach(mode, 0, rows, 2, 1);
			rows++;

			name = add_entry(_("Name"), "insert-text-symbolic", true);

			add_separator();

			executable = add_filechooser(_("Executable"), _("Select game executable"), FileChooserAction.OPEN, true, out executable_label);
			arguments = add_entry(_("Arguments"), "utilities-terminal-symbolic", false, out arguments_label);

			add_separator();

			gamedir = add_filechooser(_("Directory"), _("Select game directory"), FileChooserAction.SELECT_FOLDER, true);

			add = new Button.with_label(_("Add game"));
			add.margin_top = 8;
			add.get_style_context().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
			add.sensitive = false;

			grid.attach(add, 0, rows, 2, 1);

			mode.mode_changed.connect(update);
			name.changed.connect(update);
			executable.file_set.connect(update);
			gamedir.file_set.connect(update);
			arguments.changed.connect(update);

			update();

			add.clicked.connect(add_game);

			child = grid;
			grid.show_all();

			name.grab_focus();
		}

		private void update()
		{
			if(suppress_updates) return;

			if(mode.selected == 0 && executable.file != null && gamedir.file == null)
			{
				suppress_updates = true;
				gamedir.select_file(executable.file.get_parent());
				suppress_updates = false;
			}

			add.sensitive = name.text.strip().length > 0
				&& executable.file != null && executable.file.query_exists()
				&& gamedir.file != null && gamedir.file.query_exists();

			executable_label.label = mode.selected == 0 ? _("Executable") : _("Installer");
			arguments.sensitive = arguments_label.sensitive = mode.selected == 0;
		}

		private void add_game()
		{
			var game = new UserGame(name.text.strip(), gamedir.file, executable.file, arguments.text.strip(), mode.selected != 0);
			name.text = "";
			executable.reset();
			gamedir.reset();
			arguments.text = "";
			update();
			game.save();
			game_added(game);
			#if GTK_3_22
			popdown();
			#else
			hide();
			#endif
			executable.reset();
			gamedir.reset();
			if(mode.selected != 0)
			{
				game.install.begin();
			}
		}

		private Entry add_entry(string text, string icon, bool required=true, out Label label=null)
		{
			label = new Label(text);
			label.set_size_request(72, -1);
			label.halign = Align.END;
			label.xalign = 1;
			label.margin = 4;
			if(required)
			{
				label.get_style_context().add_class("category-label");
			}
			var entry = new Entry();
			entry.primary_icon_name = icon;
			entry.primary_icon_activatable = false;
			entry.set_size_request(180, -1);
			grid.attach(label, 0, rows);
			grid.attach(entry, 1, rows);
			rows++;
			return entry;
		}

		private FileChooserEntry add_filechooser(string text, string title, FileChooserAction action=FileChooserAction.OPEN, bool required=true, out Label label=null)
		{
			label = new Label(text);
			label.set_size_request(72, -1);
			label.halign = Align.END;
			label.xalign = 1;
			label.margin = 4;
			if(required)
			{
				label.get_style_context().add_class("category-label");
			}
			var entry = new FileChooserEntry(title, action, null, null, false, action == FileChooserAction.OPEN);
			entry.set_size_request(180, -1);
			grid.attach(label, 0, rows);
			grid.attach(entry, 1, rows);
			rows++;
			return entry;
		}

		private void add_separator()
		{
			var separator = new Separator(Orientation.HORIZONTAL);
			separator.margin_top = separator.margin_bottom = 4;
			grid.attach(separator, 0, rows, 2, 1);
			rows++;
		}
	}
}
