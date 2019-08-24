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
		private bool game_info_updating = false;
		private bool game_info_updated = false;

		public bool is_updating { get; set; default = false; }

		public File? screenshots_dir { get; protected set; default = null; }

		public ItchGame(Itch src, Json.Node json_node)
		{
			source = src;

			var json_obj = json_node.get_object();

			id = json_obj.get_int_member("id").to_string();
			name = json_obj.get_string_member("title");
			icon = json_obj.get_string_member("coverUrl");
			store_page = json_obj.get_string_member("url");

			image = icon;

			var platforms_obj = json_obj.get_object_member("platforms");
			if(platforms_obj.has_member("windows")) {
				platforms.add(Platform.WINDOWS);
			}
			if(platforms_obj.has_member("linux")) {
				platforms.add(Platform.LINUX);
			}
			if(platforms_obj.has_member("osx")) {
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
			info = Tables.Games.INFO.get(s);
			info_detailed = Tables.Games.INFO_DETAILED.get(s);
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

			store_page = @"steam://store/$(id)";

			update_status();
		}

		public override async void update_game_info()
		{
		}

		private ArrayList<string> caves = new ArrayList<string>();
		public void update_caves(HashMap<int, ArrayList<string>> caves_map)
		{
			if(caves_map.has_key(int_id)) {
				caves = caves_map.get(int_id);
			} else {
				caves.clear();
			}
			update_status();
		}

		public string get_cave()
		{
			if(caves.size > 0) {
				return caves.first();
			}
			return null;
		}

		public override void update_status()
		{
			if(caves.size > 0) {
				status = new Game.Status(Game.State.INSTALLED, this);
			} else {
				status = new Game.Status(Game.State.UNINSTALLED, this);
			}
		}

		public override async void install(Runnable.Installer.InstallMode install_mode=Runnable.Installer.InstallMode.INTERACTIVE)
		{
			yield ((Itch) source).install_game(this);
		}

		public override async void run()
		{
			yield ((Itch) source).run_game(this);
		}

		public override async void run_with_compat(bool is_opened_from_menu=false)
		{
		}

		public override async void uninstall()
		{
		}

		private bool loading_achievements = false;
		public override async ArrayList<Game.Achievement>? load_achievements()
		{
			return null;
		}

		public override void import(bool update=true){}
		public override void choose_executable(bool update=true){}
	}
}
