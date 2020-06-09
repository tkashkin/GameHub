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

namespace GameHub.Data.Sources.Itch
{
	public class ItchGame: Game
	{
		public int int_id { get { return int.parse(id); } }

		public ItchGame(Itch src, Json.Node json_node)
		{
			source = src;

			var json_obj = json_node.get_object();

			id = json_obj.get_int_member("id").to_string();
			name = json_obj.get_string_member("title");
			icon = json_obj.has_member("stillCoverUrl") ? json_obj.get_string_member("stillCoverUrl") : json_obj.get_string_member("coverUrl");
			description = json_obj.get_string_member("shortText");
			store_page = json_obj.get_string_member("url");

			image = icon;

			var platforms_obj = json_obj.get_object_member("platforms");
			if(platforms_obj.has_member("windows"))
			{
				platforms.add(Platform.WINDOWS);
			}
			if(platforms_obj.has_member("linux"))
			{
				platforms.add(Platform.LINUX);
			}
			if(platforms_obj.has_member("osx"))
			{
				platforms.add(Platform.MACOS);
			}


			info = Json.to_string(json_node, false);

			update_status();
		}

		public ItchGame.from_db(Itch src, Sqlite.Statement s)
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

			var info_root = Parser.parse_json(info);
			if(info_root != null && info_root.get_node_type() == Json.NodeType.OBJECT)
			{
				var info_root_obj = info_root.get_object();
				description = info_root_obj.get_string_member("shortText");
				store_page = info_root_obj.get_string_member("url");
			}

			update_status();
		}

		public override async void update_game_info() throws Utils.RunError
		{
			update_status();
		}

		private ArrayList<Cave> caves = new ArrayList<Cave>();
		public void update_caves(HashMap<int, ArrayList<Cave>> caves_map)
		{
			if(caves_map.has_key(int_id))
			{
				caves = caves_map.get(int_id);
			}
			else
			{
				caves.clear();
			}

			var cave = this.cave;
			if(cave != null)
			{
				install_dir = FSUtils.file(cave.install_dir);
			}

			update_status();
		}

		public Cave? cave
		{
			owned get
			{
				if(caves.size > 0)
				{
					return caves.first();
				}
				return null;
			}
		}

		public string? cave_id
		{
			get
			{
				var cave = this.cave;
				return cave != null ? cave.id : null;
			}
		}

		public override void update_status()
		{
			if(status.state == Game.State.DOWNLOADING && status.download != null
				&& status.download.status != null && status.download.status.state != Downloader.Download.State.CANCELLED
				&& status.download.status.state != Downloader.Download.State.FINISHED) return;

			if(caves.size > 0)
			{
				status = new Game.Status(Game.State.INSTALLED, this);
			}
			else
			{
				status = new Game.Status(Game.State.UNINSTALLED, this);
			}

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

		public override async void install(Runnable.Installer.InstallMode install_mode=Runnable.Installer.InstallMode.INTERACTIVE)
		{
			var uploads = yield ((Itch) source).get_game_uploads(this);

			if(uploads == null || uploads.size == 0)
			{
				is_installable = false;
				return;
			}

			var installers = new ArrayList<Runnable.Installer>();

			foreach(var upload in uploads)
			{
				var platforms = new ArrayList<Platform>();
				var platforms_obj = upload.get_object_member("platforms");
				if(platforms_obj.has_member("windows"))
				{
					platforms.add(Platform.WINDOWS);
				}
				if(platforms_obj.has_member("linux"))
				{
					platforms.add(Platform.LINUX);
				}
				if(platforms_obj.has_member("osx"))
				{
					platforms.add(Platform.MACOS);
				}

				if(platforms.size == 0) platforms.add(Platform.CURRENT);

				foreach(var platform in platforms)
				{
					installers.add(new Installer(this, upload, platform));
				}
			}

			new GameHub.UI.Dialogs.InstallDialog(this, installers, install_mode, install.callback);
			yield;
		}

		public override async void run()
		{
			if(can_be_launched(true))
			{
				Runnable.IsLaunched = is_running = true;
				update_status();

				last_launch = get_real_time() / 1000000;
				save();

				yield ((Itch) source).run_game(this);

				playtime_tracked += ((get_real_time() / 1000000) - last_launch) / 60;
				save();

				Timeout.add_seconds(1, () => {
					Runnable.IsLaunched = is_running = false;
					update_status();
					return Source.REMOVE;
				});
			}
		}

		public override async void run_with_compat(bool is_opened_from_menu=false)
		{
		}

		public override async void uninstall()
		{
			((Itch) source).uninstall_game.begin(this);
		}

		public class Installer: Runnable.Installer
		{
			public int int_id { get { return int.parse(id); } }

			public ItchGame game;
			private Json.Object json;

			public string? display_name;
			public string? file_name;

			private string _name;
			public override string name { owned get { return _name; } }

			public Installer(ItchGame game, Json.Object json, Platform platform)
			{
				this.game = game;
				this.json = json;

				id = json.get_int_member("id").to_string();
				this.platform = platform;

				file_name = json.has_member("filename") ? json.get_string_member("filename") : null;
				display_name = json.has_member("displayName") ? json.get_string_member("displayName") : null;

				if(file_name.length == 0) file_name = null;
				if(display_name.length == 0) display_name = null;

				_name = display_name ?? file_name ?? game.name;

				var build_obj = json.has_member("build") ? json.get_object_member("build") : null;
				if(build_obj != null)
				{
					version = build_obj.has_member("userVersion") ? build_obj.get_string_member("userVersion") : null;
					_name += @" ($(version))";
				}

				full_size = json.get_int_member("size");
			}

			public override async void install(Runnable runnable, CompatTool? tool=null)
			{
				yield ((Itch) game.source).install_game(this);
			}
		}
	}
}
