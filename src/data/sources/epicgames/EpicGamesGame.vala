/*
This file is part of GameHub.
Copyright (C) 2018-2019 Anatoliy Kashkin
Copyright (C) 2020 Adam Jordanek

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
using GameHub.Data.DB;
using GameHub.Utils;

using GameHub.Utils.Downloader;

namespace GameHub.Data.Sources.EpicGames
{
	public class EpicGamesGame: Game
	{
		public ArrayList<Runnable.Installer>? installers { get; protected set; default = new ArrayList<Runnable.Installer>(); }

		public EpicGamesGame(EpicGames src, string nameP, string idP)
		{
			source = src;
			name = nameP;
			id = idP;
			icon = "";
			image = src.legendary_wrapper.get_image(id);
			platforms.add(Platform.LINUX);

			install_dir = null;
			executable_path = "$game_dir/start.sh";
			work_dir_path = "$game_dir";
			info_detailed = @"{}";

			mount_overlays.begin();
			update_status();
		}

		public override void update_status()
		{
			var state = Game.State.UNINSTALLED;
			if (((EpicGames) source).legendary_wrapper.is_installed(id)) {
				state = Game.State.INSTALLED;
				debug ("New installed game: \tname = %s\t", name);
			} else {
				debug ("New not installed game: \tname = %s\t", name);
			}
			
			if(state == Game.State.INSTALLED)
			{
				remove_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				add_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
			else
			{
				add_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				remove_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
			status = new Game.Status(state, this);
		}

		public EpicGamesGame.from_db(EpicGames src, Sqlite.Statement s)
		{
			source = src;
			id = Tables.Games.ID.get(s);
			name = Tables.Games.NAME.get(s);
			info = Tables.Games.INFO.get(s);
			info_detailed = Tables.Games.INFO_DETAILED.get(s);
			icon = Tables.Games.ICON.get(s);
			image = src.legendary_wrapper.get_image(id);//Tables.Games.IMAGE.get(s);
			install_dir = Tables.Games.INSTALL_PATH.get(s) != null ? FSUtils.file(Tables.Games.INSTALL_PATH.get(s)) : null;
			executable_path = Tables.Games.EXECUTABLE.get(s);
			work_dir_path = Tables.Games.WORK_DIR.get(s);
			compat_tool = Tables.Games.COMPAT_TOOL.get(s);
			compat_tool_settings = Tables.Games.COMPAT_TOOL_SETTINGS.get(s);
			arguments = Tables.Games.ARGUMENTS.get(s);
			last_launch = Tables.Games.LAST_LAUNCH.get_int64(s);
			playtime_source = Tables.Games.PLAYTIME_SOURCE.get_int64(s);
			playtime_tracked = Tables.Games.PLAYTIME_TRACKED.get_int64(s);
			image_vertical = Tables.Games.IMAGE_VERTICAL.get(s);

			platforms.clear();
			var pls = Tables.Games.PLATFORMS.get(s).split(",");
			foreach(var pl in pls)
			{
				foreach(var p in Platform.PLATFORMS)
				{
					if(pl == p.id())
					{
						platforms.add(p);
						break;
					}
				}
			}
			installers.add(new EpicGamesGame.EpicGamesInstaller(this, id));
			update_status();
		}

		public override async void install(Runnable.Installer.InstallMode install_mode=Runnable.Installer.InstallMode.INTERACTIVE)
		{
			new GameHub.UI.Dialogs.InstallDialog(this, installers, install_mode, install.callback);
			yield;
			update_status();
		}
		public override async void uninstall()
		{
			((EpicGames) source).legendary_wrapper.uninstall(id);
			update_status();
		}

		public override async void run()
		{
			((EpicGames) source).legendary_wrapper.run(id);
		
		}

		public override void import(bool update=true)
		{
			var chooser = new FileChooserDialog(_("Select directory"), GameHub.UI.Windows.MainWindow.instance, FileChooserAction.SELECT_FOLDER);

			chooser.add_button(_("Cancel"), ResponseType.CANCEL);
			var select_btn = chooser.add_button(_("Select"), ResponseType.ACCEPT);

			select_btn.get_style_context().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
			select_btn.grab_default();

			if(chooser.run() == ResponseType.ACCEPT)
			{
				install_dir = chooser.get_file();
				((EpicGames) source).legendary_wrapper.import_game(id, install_dir.get_path());

				if(update) {
					update_status();
					save();
				}
			}

			chooser.destroy();
		}

		public class EpicGamesInstaller: Runnable.Installer
		{
			private FSUtils.Paths.Settings paths = FSUtils.Paths.Settings.instance;
			public EpicGamesGame game;
			private EpicGames epic;
			public override string name { owned get { return game.name; } }

			private int64 _full_size = 0;
			public override int64 full_size { 
				get { 
					if(_full_size != 0) return _full_size;
					else {
						var size = epic.legendary_wrapper.get_install_size (game.id);
						_full_size = size;
						return _full_size;
					}
					
				}
				set {}
			}
	
			public EpicGamesInstaller(EpicGamesGame game, string id)
			{
				this.game = game;
				id = id;
				platform = Platform.CURRENT;
				epic = (EpicGames)(game.source);
			}

			public override async void install(Runnable runnable, CompatTool? tool=null)
			{
				
				EpicGamesGame? game = null;
				if(runnable is EpicGamesGame)
				{
					game = runnable as EpicGamesGame;
				}

				Utils.thread("EpicGamesGame.Installer", () => {

					EpicDownload ed = new EpicDownload(game.id);
					game.status = new Game.Status(Game.State.DOWNLOADING, game, ed);
				
					ed.cancelled.connect(() => {
						epic.legendary_wrapper.cancel_installation();
					});
					
					var game_folder = (paths.epic_games == null || paths.epic_games == "") ? null : paths.epic_games;
					epic.legendary_wrapper.install(game.id, game_folder, progress => {
						ed.status = new EpicDownload.EpicStatus(progress / 100);
						game.status = new Game.Status(Game.State.DOWNLOADING, game, ed);
					});

					Idle.add(install.callback);
				});
				yield;

				if(game != null) game.status = new Game.Status(Game.State.INSTALLED, game, null);
				game.update_status();
			}
		}
	}




}
