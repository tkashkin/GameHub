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

using Gee;
using GameHub.Data.DB;
using GameHub.Utils;

namespace GameHub.Data.Sources.User
{
	public class UserGame: Game, TweakableGame
	{
		public string[]? tweaks { get; set; default = null; }

		private bool is_removed = false;
		public signal void removed();

		private Installer? installer;

		public UserGame(string name, File dir, File exec, string args, bool is_installer)
		{
			source = User.instance;

			this.id = Utils.md5(name + Random.next_int().to_string());
			this.name = name;

			platforms.clear();

			var path = exec.get_path().down();
			platforms.add(path.has_suffix(".exe") || path.has_suffix(".bat") || path.has_suffix(".com") ? Platform.WINDOWS : Platform.LINUX);

			install_dir = dir;
			work_dir = dir;

			arguments = args;

			if(!is_installer)
			{
				executable = exec;
			}
			else
			{
				installer = new Installer(this, exec);
				var root_object = new Json.Object();
				root_object.set_string_member("installer", exec.get_path());
				var root_node = new Json.Node(Json.NodeType.OBJECT);
				root_node.set_object(root_object);
				info = Json.to_string(root_node, false);
				save();
			}

			((User) source).add_game(this);

			mount_overlays.begin();
			update_status();
		}

		public UserGame.from_db(User src, Sqlite.Statement s)
		{
			source = src;
			id = Tables.Games.ID.get(s);
			name = Tables.Games.NAME.get(s);
			info = Tables.Games.INFO.get(s);
			info_detailed = Tables.Games.INFO_DETAILED.get(s);
			icon = Tables.Games.ICON.get(s);
			image = Tables.Games.IMAGE.get(s);
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
			gamerzilla_name = Tables.Games.GAMERZILLA.get(s);

			if((image == null || image == "") && (gamerzilla_name != null && gamerzilla_name != ""))
			{
				int game_id = Gamerzilla.get_game(gamerzilla_name);
				string found = Gamerzilla.get_game_image(game_id);
				image = @"file:///" + found;
				Gamerzilla.free_game(game_id);
			}

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

			tags.clear();
			var tag_ids = (Tables.Games.TAGS.get(s) ?? "").split(",");
			foreach(var tid in tag_ids)
			{
				foreach(var t in Tables.Tags.TAGS)
				{
					if(tid == t.id)
					{
						if(!tags.contains(t)) tags.add(t);
						break;
					}
				}
			}

			var tweaks_string = Tables.Games.TWEAKS.get(s);
			if(tweaks_string != null)
			{
				tweaks = tweaks_string.split(",");
			}

			mount_overlays.begin();
			update_status();
		}

		public override async void update_game_info()
		{
			yield mount_overlays();
			update_status();

			if(installer == null && info != null && info.length > 0)
			{
				var i = Parser.parse_json(info).get_object();
				installer = new Installer(this, File.new_for_path(i.get_string_member("installer")));
			}

			save();
		}

		public override async void install(Runnable.Installer.InstallMode install_mode=Runnable.Installer.InstallMode.INTERACTIVE)
		{
			yield update_game_info();
			if(installer == null) return;
			var installers = new ArrayList<Runnable.Installer>();
			installers.add(installer);
			new GameHub.UI.Dialogs.InstallDialog(this, installers, install_mode, install.callback);
			yield;
		}

		public override async void uninstall()
		{
			yield umount_overlays();
			remove();
		}

		public void remove()
		{
			is_removed = true;
			((User) source).remove_game(this);
			removed();
		}

		public override void save()
		{
			if(!is_removed)
			{
				base.save();
			}
		}

		public override void update_status()
		{
			var exec = executable;
			status = new Game.Status(exec != null && exec.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED, this);
			if(status.state == Game.State.INSTALLED)
			{
				remove_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				add_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
			else
			{
				add_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				remove_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
		}

		private bool loading_achievements = false;
		public override async ArrayList<Game.Achievement>? load_achievements()
		{
			if (gamerzilla_name == null || gamerzilla_name == "")
				return null;
			if(achievements != null || loading_achievements)
			{
				return achievements;
			}

			loading_achievements = true;
			int game_id = Gamerzilla.get_game(gamerzilla_name);
			int num_trophy = Gamerzilla.get_trophy_num(game_id);
			var _achievements = new ArrayList<Game.Achievement>();

			for (int i = 0; i < num_trophy; i++)
			{
				unowned string a_name;
				unowned string a_desc;
				string a_image_unlocked;
				string a_image_locked;
				bool a_unlocked = false;
				Gamerzilla.get_trophy_by_index(game_id, i, out a_name, out a_desc);
				a_image_unlocked = @"file:///" + Gamerzilla.get_trophy_image(game_id, a_name, true);
				a_image_locked = @"file:///" + Gamerzilla.get_trophy_image(game_id, a_name, false);
				Gamerzilla.get_trophy(game_id, a_name, out a_unlocked);
				_achievements.add(new Achievement(a_name, a_name, a_desc, a_image_locked, a_image_unlocked,
				                                  a_unlocked));
			}
			Gamerzilla.free_game(game_id);

			achievements = _achievements;
			loading_achievements = false;
			return achievements;
		}

		public class Installer: Runnable.FileInstaller
		{
			private string game_name;
			public override string name { owned get { return game_name; } }

			public Installer(UserGame game, File installer)
			{
				game_name = game.name;
				id = "installer";
				platform = installer.get_path().down().has_suffix(".exe") ? Platform.WINDOWS : Platform.LINUX;
				file = installer;
			}
		}

		public class Achievement: Game.Achievement
		{
			public Achievement(string id, string name, string desc, string? image_locked, string? image_unlocked,
			                   bool unlocked)
			{
				this.id = id;
				this.name = name;
				this.description = desc;
				this.image_locked = image_locked;
				this.image_unlocked = image_unlocked;
				this.unlocked = unlocked;
			}
		}
	}
}
