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

namespace GameHub.Data.Sources.Steam
{
	public class SteamGame: Game
	{
		private int metadata_tries = 0;

		private bool game_info_updated = false;

		public SteamGame(Steam src, Json.Node json_node)
		{
			source = src;

			var json_obj = json_node.get_object();

			id = json_obj.get_int_member("appid").to_string();
			name = json_obj.get_string_member("name");
			var icon_hash = json_obj.get_string_member("img_icon_url");
			icon = @"http://media.steampowered.com/steamcommunity/public/images/apps/$(id)/$(icon_hash).jpg";
			image = @"http://cdn.akamai.steamstatic.com/steam/apps/$(id)/header.jpg";

			info = Json.to_string(json_node, false);

			store_page = @"steam://store/$(id)";

			update_status();
		}

		public SteamGame.from_db(Steam src, Sqlite.Statement s)
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

			store_page = @"steam://store/$(id)";

			update_status();
		}

		public override async void update_game_info()
		{
			update_status();

			if(image == null || image == "")
			{
				image = @"http://cdn.akamai.steamstatic.com/steam/apps/$(id)/header.jpg";
			}

			if((info != null && info.length > 0))
			{
				var i = Parser.parse_json(info).get_object();
				if((icon == null || icon == ""))
				{
					var icon_hash = i.get_string_member("img_icon_url");
					icon = @"http://media.steampowered.com/steamcommunity/public/images/apps/$(id)/$(icon_hash).jpg";
				}
				if(playtime_source == 0)
				{
					playtime_source = i.get_int_member("playtime_forever");
				}
			}

			File? dir;
			Steam.find_app_install_dir(id, out dir);
			install_dir = dir;

			if(game_info_updated) return;

			if(info_detailed == null || info_detailed.length == 0)
			{
				debug("[Steam:%s] No cached app data for '%s', fetching...", id, name);
				var lang = Utils.get_language_name().down();
				var url = @"https://store.steampowered.com/api/appdetails?appids=$(id)" + (lang != null && lang.length > 0 ? "&l=" + lang : "");
				info_detailed = (yield Parser.load_remote_file_async(url));
			}

			var root = Parser.parse_json(info_detailed);

			var app = Parser.json_object(root, {id});

			if(app == null)
			{
				debug("[Steam:%s] No app data for '%s', store page does not exist", id, name);
				game_info_updated = true;
				return;
			}

			var data = Parser.json_object(root, {id, "data"});

			if(data == null)
			{
				bool success = app.has_member("success") && app.get_boolean_member("success");
				debug("[Steam:%s] No app data for '%s', success: %s, store page does not exist", id, name, success.to_string());
				if(metadata_tries > 0)
				{
					game_info_updated = true;
					return;
				}
			}

			description = data != null && data.has_member("detailed_description") ? data.get_string_member("detailed_description") : "";

			metadata_tries++;

			var platforms_json = Parser.json_object(root, {id, "data", "platforms"});

			platforms.clear();
			if(platforms_json == null)
			{
				debug("[Steam:%s] No platform support data, %d tries failed, assuming Windows support", id, metadata_tries);
				platforms.add(Platform.WINDOWS);
				save();
				game_info_updated = true;
				return;
			}

			foreach(var p in Platforms)
			{
				if(platforms_json.get_boolean_member(p.id()))
				{
					platforms.add(p);
				}
			}

			save();

			game_info_updated = true;
			update_status();
		}

		public override void update_status()
		{
			status = new Game.Status(Steam.is_app_installed(id) ? Game.State.INSTALLED : Game.State.UNINSTALLED, this);
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

		public override async void install()
		{
			yield run();
		}

		public override async void run()
		{
			last_launch = get_real_time() / 1000000;
			save();
			Utils.open_uri(@"steam://rungameid/$(id)");
			update_status();
		}

		public override async void run_with_compat(bool is_opened_from_menu=false)
		{
			yield run();
		}

		public override async void uninstall()
		{
			Utils.open_uri(@"steam://uninstall/$(id)");
			update_status();
		}

		private bool loading_achievements = false;
		public override async ArrayList<Game.Achievement>? load_achievements()
		{
			if(achievements != null || loading_achievements)
			{
				return achievements;
			}

			loading_achievements = true;

			var lang = Utils.get_language_name().down();
			lang = (lang != null && lang.length > 0 ? "&l=" + lang : "");

			var schema_url = @"https://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/?key=$(Steam.instance.api_key)&format=json&appid=$(id)$(lang)";
			var achievements_url = @"https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/?key=$(Steam.instance.api_key)&steamid=$(Steam.instance.user_id)&format=json&appid=$(id)$(lang)";
			var global_percentages_url = @"https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?key=$(Steam.instance.api_key)&format=json&gameid=$(id)";

			var schema_root = (yield Parser.parse_remote_json_file_async(schema_url));
			var achievements_root = (yield Parser.parse_remote_json_file_async(achievements_url));
			var global_percentages_root = (yield Parser.parse_remote_json_file_async(global_percentages_url));

			var schema_achievements_obj = Parser.json_object(schema_root, {"game", "availableGameStats"});
			if(schema_achievements_obj == null || !schema_achievements_obj.has_member("achievements"))
			{
				loading_achievements = false;
				return null;
			}
			var schema_achievements = schema_achievements_obj.get_array_member("achievements");

			var achievements_obj = Parser.json_object(achievements_root, {"playerstats"});
			if(achievements_obj == null || !achievements_obj.has_member("achievements"))
			{
				loading_achievements = false;
				return null;
			}
			var player_achievements = achievements_obj.get_array_member("achievements");

			var global_percentages_obj = Parser.json_object(global_percentages_root, {"achievementpercentages"});
			if(global_percentages_obj == null || !global_percentages_obj.has_member("achievements"))
			{
				loading_achievements = false;
				return null;
			}
			var global_percentages = global_percentages_obj.get_array_member("achievements");

			var _achievements = new ArrayList<Game.Achievement>();

			foreach(var s_achievement_node in schema_achievements.get_elements())
			{
				var s_achievement = s_achievement_node != null && s_achievement_node.get_node_type() == Json.NodeType.OBJECT
					? s_achievement_node.get_object() : null;

				if(s_achievement == null || !s_achievement.has_member("name")) continue;

				var a_id                  = s_achievement.get_string_member("name");
				var a_name                = s_achievement.has_member("displayName") ? s_achievement.get_string_member("displayName") : a_id;
				var a_desc                = s_achievement.has_member("description") ? s_achievement.get_string_member("description") : "";
				var a_image_unlocked      = s_achievement.has_member("icon") ? s_achievement.get_string_member("icon") : null;
				var a_image_locked        = s_achievement.has_member("icongray") ? s_achievement.get_string_member("icongray") : null;
				bool a_unlocked           = false;
				int64 a_unlock_time       = 0;
				float a_global_percentage = 0;

				foreach(var p_achievement_node in player_achievements.get_elements())
				{
					var p_achievement = p_achievement_node != null && p_achievement_node.get_node_type() == Json.NodeType.OBJECT
						? p_achievement_node.get_object() : null;

					if(p_achievement == null || !p_achievement.has_member("apiname")
						|| p_achievement.get_string_member("apiname") != a_id) continue;

					a_unlocked = p_achievement.has_member("achieved") && p_achievement.get_int_member("achieved") > 0;
					a_unlock_time = p_achievement.has_member("unlocktime") ? p_achievement.get_int_member("unlocktime") : 0;
				}

				foreach(var gp_achievement_node in global_percentages.get_elements())
				{
					var gp_achievement = gp_achievement_node != null && gp_achievement_node.get_node_type() == Json.NodeType.OBJECT
						? gp_achievement_node.get_object() : null;

					if(gp_achievement == null || !gp_achievement.has_member("name")
						|| gp_achievement.get_string_member("name") != a_id) continue;

					a_global_percentage = (float) (gp_achievement.has_member("percent") ? gp_achievement.get_double_member("percent") : 0);
				}

				_achievements.add(new Achievement(a_id, a_name, a_desc, a_image_locked, a_image_unlocked,
				                                  a_unlocked, a_unlock_time, a_global_percentage));
			}

			_achievements.sort((first, second) => {
				var a1 = first as Achievement;
				var a2 = second as Achievement;

				if(a1.unlock_timestamp > 0 || a2.unlock_timestamp > 0)
				{
					return (int) (a2.unlock_timestamp - a1.unlock_timestamp);
				}

				if(a1.global_percentage < a2.global_percentage) return 1;
				if(a1.global_percentage > a2.global_percentage) return -1;
				return 0;
			});

			achievements = _achievements;
			loading_achievements = false;
			return achievements;
		}

		public override void import(bool update=true){}
		public override void choose_executable(bool update=true){}

		public class Achievement: Game.Achievement
		{
			public int64 unlock_timestamp;

			public Achievement(string id, string name, string desc, string? image_locked, string? image_unlocked,
			                   bool unlocked, int64 unlock_time, float global_percentage)
			{
				this.id = id;
				this.name = name;
				this.description = desc;
				this.image_locked = image_locked;
				this.image_unlocked = image_unlocked;
				this.unlocked = unlocked;
				this.global_percentage = global_percentage;
				this.unlock_timestamp = unlock_time;
				this.unlock_date = new DateTime.from_unix_utc(unlock_time);
				this.unlock_time = Utils.get_relative_datetime(this.unlock_date);
			}
		}
	}
}
