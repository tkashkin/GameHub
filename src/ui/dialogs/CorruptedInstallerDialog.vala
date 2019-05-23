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
using GameHub.Data.Sources.Steam;

namespace GameHub.UI.Dialogs
{
	public class CorruptedInstallerDialog: Dialog
	{
		private const int RESPONSE_SHOW   = 10;
		private const int RESPONSE_BACKUP = 11;
		private const int RESPONSE_REMOVE = 12;

		public Runnable game { get; construct; }
		public File installer { get; construct; }

		private Box content;
		private Label title_label;
		private Label subtitle_label;
		private Label message_label;

		public CorruptedInstallerDialog(Runnable game, File installer)
		{
			Object(game: game, installer: installer, transient_for: Windows.MainWindow.instance, resizable: false, title: _("%s: corrupted installer").printf(game.name));
		}

		construct
		{
			get_style_context().add_class("rounded");
			get_style_context().add_class(Gtk.STYLE_CLASS_FLAT);

			modal = true;

			var hbox = new Box(Orientation.HORIZONTAL, 8);
			hbox.margin_start = hbox.margin_end = 5;

			content = new Box(Orientation.VERTICAL, 0);
			content.margin_bottom = 8;

			title_label = new Label(game.name);
			title_label.margin_start = 8;
			title_label.halign = Align.START;
			title_label.valign = Align.START;
			title_label.hexpand = true;
			title_label.get_style_context().add_class(Granite.STYLE_CLASS_H2_LABEL);
			content.add(title_label);

			subtitle_label = new Label(_("Corrupted installer: checksum mismatch in"));
			subtitle_label.margin_start = 8;
			subtitle_label.halign = Align.START;
			subtitle_label.valign = Align.START;
			subtitle_label.hexpand = true;
			content.add(subtitle_label);

			message_label = new Label(installer.get_basename());
			message_label.margin_start = 8;
			message_label.halign = Align.START;
			message_label.valign = Align.START;
			message_label.hexpand = true;
			message_label.get_style_context().add_class("category-label");
			content.add(message_label);

			if(game is Game && (game as Game).icon != null)
			{
				var icon = new AutoSizeImage();
				icon.valign = Align.START;
				icon.set_constraint(48, 48, 1);
				icon.set_size_request(48, 48);
				icon.load((game as Game).icon, "icon");
				hbox.add(icon);
			}

			hbox.add(content);

			response.connect((source, response_id) => {
				var action = Application.ACTION_CORRUPTED_INSTALLER_SHOW;
				switch(response_id)
				{
					case CorruptedInstallerDialog.RESPONSE_SHOW:
						action = Application.ACTION_CORRUPTED_INSTALLER_SHOW;
						break;

					case CorruptedInstallerDialog.RESPONSE_BACKUP:
						action = Application.ACTION_CORRUPTED_INSTALLER_BACKUP;
						break;

					case CorruptedInstallerDialog.RESPONSE_REMOVE:
						action = Application.ACTION_CORRUPTED_INSTALLER_REMOVE;
						break;

					default:
						return;
				}
				string id = (game is Game) ? (game as Game).full_id : game.id;
				Application.instance.activate_action(action, new Variant("(ss)", id, installer.get_path()));
				if(action != Application.ACTION_CORRUPTED_INSTALLER_SHOW)
				{
					destroy();
				}
			});

			var show_btn = add_button(_("Show file"), CorruptedInstallerDialog.RESPONSE_SHOW);

			var backup_btn = add_button(_("Backup"), CorruptedInstallerDialog.RESPONSE_BACKUP);
			backup_btn.get_style_context().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
			backup_btn.grab_default();

			var remove_btn = add_button(_("Remove"), CorruptedInstallerDialog.RESPONSE_REMOVE);
			remove_btn.get_style_context().add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

			var bbox = show_btn.get_parent() as ButtonBox;
			if(bbox != null)
			{
				bbox.set_child_secondary(show_btn, true);
				bbox.set_child_non_homogeneous(show_btn, true);
			}

			get_content_area().add(hbox);
			get_content_area().set_size_request(340, 96);

			show_all();
		}
	}
}
