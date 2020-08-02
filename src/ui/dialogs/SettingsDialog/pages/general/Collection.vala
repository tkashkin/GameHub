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
using GameHub.UI.Widgets;
using GameHub.UI.Widgets.Settings;

using GameHub.Data;
using GameHub.Utils;
using GameHub.Settings;

namespace GameHub.UI.Dialogs.SettingsDialog.Pages.General
{
	public class Collection: SettingsDialogPage
	{
		private const string EXAMPLE_GAME_NAME = "Factorio";

		private Paths.Collection collection;
		private Paths.Collection.GOG gog;
		private Paths.Collection.Humble humble;

		private FileSetting collection_root;

		private EntrySetting gog_game_dir;
		private EntrySetting gog_installers;
		private EntrySetting gog_dlc;
		private EntrySetting gog_bonus;

		private EntrySetting humble_game_dir;
		private EntrySetting humble_installers;

		private int syntax_info_grid_rows = 0;
		private Grid syntax_info_grid;

		public Collection(SettingsDialog dlg)
		{
			Object(
				dialog: dlg,
				header: _("General"),
				title: _("Collection"),
				description: _("Empty"),
				icon_name: "gh-settings-folder-symbolic"
			);
		}

		construct
		{
			collection = Paths.Collection.instance;
			gog = Paths.Collection.GOG.instance;
			humble = Paths.Collection.Humble.instance;

			var sgrp_collection = new SettingsGroup();
			collection_root = sgrp_collection.add_setting(
				new FileSetting.bind(
					_("Collection directory") + """<span alpha="75%"> • $root</span>""", _("Installers and bonus content will be downloaded in the collection directory"),
					file_chooser(_("Select collection root directory"), FileChooserAction.SELECT_FOLDER),
					collection, "root"
				)
			);
			add_widget(sgrp_collection);

			var sgrp_gog = new SettingsGroup("GOG");
			gog_game_dir = sgrp_gog.add_setting(new EntrySetting.bind(_("Game directory") + """<span alpha="75%"> • $game_dir</span>""", null, entry("source-gog-symbolic"), gog, "game-dir"));
			gog_installers = sgrp_gog.add_setting(new EntrySetting.bind(_("Installers directory"), null, entry("source-gog-symbolic"), gog, "installers"));
			gog_dlc = sgrp_gog.add_setting(new EntrySetting.bind(_("DLC directory"), null, entry("folder-download-symbolic"), gog, "dlc"));
			gog_bonus = sgrp_gog.add_setting(new EntrySetting.bind(_("Bonus content directory"), null, entry("folder-music-symbolic"), gog, "bonus"));
			add_widget(sgrp_gog);

			var sgrp_humble = new SettingsGroup("Humble Bundle");
			humble_game_dir = sgrp_humble.add_setting(new EntrySetting.bind(_("Game directory") + """<span alpha="75%"> • $game_dir</span>""", null, entry("source-humble-symbolic"), humble, "game-dir"));
			humble_installers = sgrp_humble.add_setting(new EntrySetting.bind(_("Installers directory"), null, entry("source-humble-symbolic"), humble, "installers"));
			add_widget(sgrp_humble);

			gog_game_dir.ellipsize_description = gog_installers.ellipsize_description = gog_dlc.ellipsize_description = gog_bonus.ellipsize_description = Pango.EllipsizeMode.START;
			humble_game_dir.ellipsize_description = humble_installers.ellipsize_description = Pango.EllipsizeMode.START;

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
			syntax_info.margin_start = syntax_info.margin_end = 18;

			gog.notify["game-dir"].connect(() => gog_game_dir.description = Paths.Collection.GOG.expand_game_dir(EXAMPLE_GAME_NAME));
			gog.notify["installers"].connect(() => gog_installers.description = Paths.Collection.GOG.expand_installers(EXAMPLE_GAME_NAME, null, Platform.CURRENT));
			gog.notify["dlc"].connect(() => gog_dlc.description = Paths.Collection.GOG.expand_dlc(EXAMPLE_GAME_NAME));
			gog.notify["bonus"].connect(() => gog_bonus.description = Paths.Collection.GOG.expand_bonus(EXAMPLE_GAME_NAME));

			humble.notify["game-dir"].connect(() => humble_game_dir.description = Paths.Collection.Humble.expand_game_dir(EXAMPLE_GAME_NAME));
			humble.notify["installers"].connect(() => humble_installers.description = Paths.Collection.Humble.expand_installers(EXAMPLE_GAME_NAME, Platform.CURRENT));

			collection.notify["root"].connect(update);

			update();
		}

		private void update()
		{
			gog_game_dir.description = Paths.Collection.GOG.expand_game_dir(EXAMPLE_GAME_NAME);
			gog_installers.description = Paths.Collection.GOG.expand_installers(EXAMPLE_GAME_NAME, null, Platform.CURRENT);
			gog_dlc.description = Paths.Collection.GOG.expand_dlc(EXAMPLE_GAME_NAME);
			gog_bonus.description = Paths.Collection.GOG.expand_bonus(EXAMPLE_GAME_NAME);

			humble_game_dir.description = Paths.Collection.Humble.expand_game_dir(EXAMPLE_GAME_NAME);
			humble_installers.description = Paths.Collection.Humble.expand_installers(EXAMPLE_GAME_NAME, Platform.CURRENT);

			Utils.thread("CollectionDiskUsage", () => {
				try
				{
					FileMeasureProgressCallback callback = (reporting, size, dirs, files) => {
						Idle.add(() => {
							description = format_size(size);
							return Source.REMOVE;
						});
					};
					uint64 size, dirs, files;
					FS.file(collection.root).measure_disk_usage(FileMeasureFlags.NONE, null, callback, out size, out dirs, out files);
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
