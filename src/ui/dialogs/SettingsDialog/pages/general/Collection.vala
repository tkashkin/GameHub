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
using Granite;

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

		public Collection(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				header: _("General"),
				title: _("Collection"),
				description: "",
				icon_name: "folder-download"
			);
			status = description;
		}

		construct
		{
			collection = FSUtils.Paths.Collection.get_instance();
			gog = FSUtils.Paths.Collection.GOG.get_instance();
			humble = FSUtils.Paths.Collection.Humble.get_instance();

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

			add_separator();

			add_header(_("Variables")).sensitive = false;
			add_label(_("Syntax: <b>$var</b> or <b>${var}</b>"), true);
			add_labels(" <b>•</b> $<b>root</b>", _("Collection directory"), true).sensitive = false;
			add_labels(" <b>•</b> $<b>game</b>", _("Game name"), true).sensitive = false;
			add_labels(" <b>•</b> $<b>game_dir</b>", _("Game directory"), true).sensitive = false;
			add_labels(" <b>•</b> $<b>platform</b>, $<b>platform_name</b>", _("Platform"), true).sensitive = false;

			update();
		}

		private void update()
		{
			var game = "Game";

			gog_game_dir.tooltip_text = FSUtils.Paths.Collection.GOG.expand_game_dir(game);
			gog_installers.tooltip_text = FSUtils.Paths.Collection.GOG.expand_installers(game, null, CurrentPlatform);
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

	}
}
