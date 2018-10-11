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
using Granite;
using GameHub.Utils;

namespace GameHub.UI.Dialogs.SettingsDialog.Tabs
{
	public class Collection: SettingsDialogTab
	{
		private FileChooserButton collection_root;

		private Entry gog_game_dir;
		private Entry gog_installers;
		private Entry gog_dlc;
		private Entry gog_bonus;

		private Entry humble_game_dir;
		private Entry humble_installers;

		public Collection(SettingsDialog dlg)
		{
			Object(orientation: Orientation.VERTICAL, dialog: dlg);
		}

		construct
		{
			var collection = FSUtils.Paths.Collection.get_instance();
			var gog = FSUtils.Paths.Collection.GOG.get_instance();
			var humble = FSUtils.Paths.Collection.Humble.get_instance();

			collection_root = add_file_chooser(_("Collection directory"), FileChooserAction.SELECT_FOLDER, collection.root, v => { collection.root = v; update_hints(); }).get_children().last().data as FileChooserButton;

			add_separator();

			add_header("GOG");
			gog_game_dir = add_entry(_("Game directory") + " ($game_dir)", gog.game_dir, v => { gog.game_dir = v; update_hints(); }, "source-gog-symbolic").get_children().last().data as Entry;
			gog_installers = add_entry(_("Installers"), gog.installers, v => { gog.installers = v; update_hints(); }, "source-gog-symbolic").get_children().last().data as Entry;
			gog_dlc = add_entry(_("DLC"), gog.dlc, v => { gog.dlc = v; update_hints(); }, "folder-download-symbolic").get_children().last().data as Entry;
			gog_bonus = add_entry(_("Bonus content"), gog.bonus, v => { gog.bonus = v; update_hints(); }, "folder-music-symbolic").get_children().last().data as Entry;

			add_separator();

			add_header("Humble Bundle");
			humble_game_dir = add_entry(_("Game directory") + " ($game_dir)", humble.game_dir, v => { humble.game_dir = v; update_hints(); }, "source-humble-symbolic").get_children().last().data as Entry;
			humble_installers = add_entry(_("Installers"), humble.installers, v => { humble.installers = v; update_hints(); }, "source-humble-symbolic").get_children().last().data as Entry;

			add_separator();

			add_header(_("Variables")).sensitive = false;
			add_labels("• $root", _("Collection directory")).sensitive = false;
			add_labels("• $game", _("Game name")).sensitive = false;
			add_labels("• $game_dir", _("Game directory")).sensitive = false;

			update_hints();
		}

		private void update_hints()
		{
			var game = "VVVVVV";

			collection_root.tooltip_text = FSUtils.Paths.Collection.expand_root();

			gog_game_dir.tooltip_text = FSUtils.Paths.Collection.GOG.expand_game_dir(game);
			gog_installers.tooltip_text = FSUtils.Paths.Collection.GOG.expand_installers(game);
			gog_dlc.tooltip_text = FSUtils.Paths.Collection.GOG.expand_dlc(game);
			gog_bonus.tooltip_text = FSUtils.Paths.Collection.GOG.expand_bonus(game);

			humble_game_dir.tooltip_text = FSUtils.Paths.Collection.Humble.expand_game_dir(game);
			humble_installers.tooltip_text = FSUtils.Paths.Collection.Humble.expand_installers(game);
		}

	}
}
