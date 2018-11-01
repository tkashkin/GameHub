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

using Gee;
using GameHub.Data.DB;
using GameHub.Utils;

namespace GameHub.Data.Sources.User
{
	public class UserGame: Game
	{
		private bool is_removed = false;
		public signal void removed();

		private Installer? installer;

		public UserGame(string name, File dir, File exec, string args, bool is_installer)
		{
			source = User.instance;

			this.id = Utils.md5(name + Random.next_int().to_string());
			this.name = name;

			platforms.clear();
			platforms.add(exec.get_path().has_suffix(".exe") ? Platform.WINDOWS : Platform.LINUX);

			install_dir = dir;

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
			install_dir = FSUtils.file(Tables.Games.INSTALL_PATH.get(s)) ?? FSUtils.file(FSUtils.Paths.GOG.Games, escaped_name);
			executable = FSUtils.file(Tables.Games.EXECUTABLE.get(s)) ?? FSUtils.file(install_dir.get_path(), "start.sh");
			compat_tool = Tables.Games.COMPAT_TOOL.get(s);
			compat_tool_settings = Tables.Games.COMPAT_TOOL_SETTINGS.get(s);
			arguments = Tables.Games.ARGUMENTS.get(s);
			last_launch = Tables.Games.LAST_LAUNCH.get_int64(s);

			platforms.clear();
			var pls = Tables.Games.PLATFORMS.get(s).split(",");
			foreach(var pl in pls)
			{
				foreach(var p in Platforms)
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

			update_status();
		}

		public override async void update_game_info()
		{
			update_status();
			if(installer == null && info != null && info.length > 0)
			{
				var i = Parser.parse_json(info).get_object();
				installer = new Installer(this, File.new_for_path(i.get_string_member("installer")));
			}
			save();
		}

		public override async void install()
		{
			yield update_game_info();

			if(installer == null) return;

			var installers = new ArrayList<Game.Installer>();
			installers.add(installer);

			var wnd = new GameHub.UI.Dialogs.GameInstallDialog(this, installers);

			wnd.cancelled.connect(() => Idle.add(install.callback));

			wnd.install.connect((installer, dl_only, tool) => {
				installer.install.begin(this, dl_only, tool, (obj, res) => {
					installer.install.end(res);
					Idle.add(install.callback);
				});
			});

			wnd.show_all();
			wnd.present();

			yield;
		}

		public override async void uninstall()
		{
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
			var state = executable != null && executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED;
			status = new Game.Status(state);
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
		}

		public class Installer: Game.Installer
		{
			private string game_name;
			public override string name { get { return game_name; } }

			public Installer(UserGame game, File installer)
			{
				game_name = game.name;
				id = "installer";
				platform = installer.get_path().has_suffix(".exe") ? Platform.WINDOWS : Platform.LINUX;
				parts.add(new Game.Installer.Part("installer", installer.get_uri(), full_size, installer, installer));
			}
		}
	}
}
