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


using GameHub.Data;
using GameHub.Utils;
using GameHub.UI.Widgets;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.General
{
	public class Collection: SettingsDialogPage
	{
		private FSUtils.Paths.Collection collection;
		private FSUtils.Paths.Collection.GOG gog;
		private FSUtils.Paths.Collection.Humble humble;

		private FileChooserEntry collection_root;

		private Entry gog_game_dir;
		private Entry gog_installers;
		private Entry gog_dlc;
		private Entry gog_bonus;

		private Entry humble_game_dir;
		private Entry humble_installers;

		private int syntax_info_grid_rows = 0;
		private Grid syntax_info_grid;

		public Collection(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				header: _("General"),
				title: _("Collection"),
				description: _("Empty"),
				icon_name: "folder-download"
			);
			status = description;
		}

		construct
		{
			collection = FSUtils.Paths.Collection.instance;
			gog = FSUtils.Paths.Collection.GOG.instance;
			humble = FSUtils.Paths.Collection.Humble.instance;

			collection_root = add_file_chooser(_("Collection directory"), FileChooserAction.SELECT_FOLDER, collection.root, v => { collection.root = v; update(); }).get_children().last().data as FileChooserEntry;

			add_separator();

			add_header("GOG");
			gog_game_dir = add_entry(_("Game directory") + " ($game_dir)", gog.game_dir, v => { gog.game_dir = v; update(); }, "source-gog-symbolic").get_children().last().data as Entry;
			gog_installers = add_entry(_("Installers"), gog.installers, v => { gog.installers = v; update(); }, "source-gog-symbolic").get_children().last().data as Entry;
			gog_dlc = add_entry(_("DLC"), gog.dlc, v => { gog.dlc = v; update(); }, "folder-download-symbolic").get_children().last().data as Entry;
			gog_bonus = add_entry(_("Bonus content"), gog.bonus, v => { gog.bonus = v; update(); }, "folder-music-symbolic").get_children().last().data as Entry;

			add_separator();

			add_header("Humble Bundle");
			humble_game_dir = add_entry(_("Game directory") + " ($game_dir)", humble.game_dir, v => { humble.game_dir = v; update(); }, "source-humble-symbolic").get_children().last().data as Entry;
			humble_installers = add_entry(_("Installers"), humble.installers, v => { humble.installers = v; update(); }, "source-humble-symbolic").get_children().last().data as Entry;

			syntax_info_grid = new Grid();
			syntax_info_grid.column_spacing = 72;

			syntax_info_label(_("Variable syntax: <b>$var</b> or <b>${var}</b>"));
			syntax_info_label("<b>•</b> $<b>root</b>", _("Collection directory"));
			syntax_info_label("<b>•</b> $<b>game</b>", _("Game name"));
			syntax_info_label("<b>•</b> $<b>game_dir</b>", _("Game directory"));
			syntax_info_label("<b>•</b> $<b>platform</b>, $<b>platform_name</b>", _("Platform"));

			var syntax_info = new InfoBar();
			syntax_info.get_style_context().add_class(Gtk.STYLE_CLASS_FRAME);
			syntax_info.get_style_context().add_class("settings-info");
			syntax_info.message_type = MessageType.INFO;
			syntax_info.get_content_area().add(syntax_info_grid);

			add_widget(syntax_info);
			syntax_info.margin = 0;

			update();
		}

		private void update()
		{
			var game = "Game";

			gog_game_dir.tooltip_text = FSUtils.Paths.Collection.GOG.expand_game_dir(game);
			gog_installers.tooltip_text = FSUtils.Paths.Collection.GOG.expand_installers(game, null, Platform.CURRENT);
			gog_dlc.tooltip_text = FSUtils.Paths.Collection.GOG.expand_dlc(game);
			gog_bonus.tooltip_text = FSUtils.Paths.Collection.GOG.expand_bonus(game);

			humble_game_dir.tooltip_text = FSUtils.Paths.Collection.Humble.expand_game_dir(game);
			humble_installers.tooltip_text = FSUtils.Paths.Collection.Humble.expand_installers(game);

			Utils.thread("CollectionDiskUsage", () => {
				try
				{
					FileMeasureProgressCallback callback = (reporting, size, dirs, files) => {
						Idle.add(() => {
							status = description = format_size(size);
							return Source.REMOVE;
						});
					};
					uint64 size, dirs, files;
					FSUtils.file(collection.root).measure_disk_usage(FileMeasureFlags.NONE, null, callback, out size, out dirs, out files);
					callback(true, size, dirs, files);
				}
				catch(Error e){}
			});
		}

		private void syntax_info_label(string variable, string? description=null)
		{
			var var_label = new Label(variable);
			var_label.xalign = 0;
			var_label.use_markup = true;
			syntax_info_grid.attach(var_label, 0, syntax_info_grid_rows, description == null ? 2 : 1, 1);

			if(description != null)
			{
				var desc_label = new Label(description);
				desc_label.xalign = 0;
				syntax_info_grid.attach(desc_label, 1, syntax_info_grid_rows);
			}

			syntax_info_grid_rows++;
		}
	}
}
