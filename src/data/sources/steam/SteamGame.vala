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

			status = new Game.Status(Steam.is_app_installed(id) ? Game.State.INSTALLED : Game.State.UNINSTALLED);
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

			status = new Game.Status(Steam.is_app_installed(id) ? Game.State.INSTALLED : Game.State.UNINSTALLED);
		}

		public override async void update_game_info()
		{
			if(image == null || image == "")
			{
				image = @"http://cdn.akamai.steamstatic.com/steam/apps/$(id)/header.jpg";
			}

			if((icon == null || icon == "") && (info != null && info.length > 0))
			{
				var i = Parser.parse_json(info).get_object();
				var icon_hash = i.get_string_member("img_icon_url");
				icon = @"http://media.steampowered.com/steamcommunity/public/images/apps/$(id)/$(icon_hash).jpg";
			}

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
				Tables.Games.add(this);
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

			Tables.Games.add(this);

			game_info_updated = true;
		}

		public override async void install()
		{
			yield run();
		}

		public override async void run()
		{
			Utils.open_uri(@"steam://rungameid/$(id)");
			status = new Game.Status(Steam.is_app_installed(id) ? Game.State.INSTALLED : Game.State.UNINSTALLED);
		}

		public override async void run_with_compat()
		{
			yield run();
		}

		public override async void uninstall()
		{
			Utils.open_uri(@"steam://uninstall/$(id)");
			status = new Game.Status(Steam.is_app_installed(id) ? Game.State.INSTALLED : Game.State.UNINSTALLED);
		}

		public override void import(bool update=true){}
		public override void choose_executable(bool update=true){}
	}
}
