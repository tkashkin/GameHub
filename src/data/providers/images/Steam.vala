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

using GameHub.Data.Runnables;
using GameHub.Utils;

namespace GameHub.Data.Providers.Images
{
	public class Steam: ImagesProvider
	{
		private const string DOMAIN       = "https://store.steampowered.com/";
		private const string CDN_BASE_URL = "http://cdn.akamai.steamstatic.com/steam/apps/";
		private const string API_KEY_PAGE = "https://steamcommunity.com/dev/apikey";
		private const string API_BASE_URL = "https://api.steampowered.com/";

		private const string APPLIST_CACHE_FILE = "applist.json";
		private ImagesProvider.ImageSize?[] SIZES = { ImageSize(460, 215), ImageSize(600, 900) };

		public override string id   { get { return "steam"; } }
		public override string name { get { return "Steam"; } }
		public override string url  { get { return DOMAIN; } }
		public override string icon { get { return "source-steam-symbolic"; } }

		public override bool enabled
		{
			get { return Settings.Providers.Images.Steam.instance.enabled; }
			set { Settings.Providers.Images.Steam.instance.enabled = value; }
		}

		public override async ArrayList<ImagesProvider.Result> images(Game game)
		{
			var results = new ArrayList<ImagesProvider.Result>();
			string? appid = null;

			if(game is GameHub.Data.Sources.Steam.SteamGame)
			{
				appid = game.id;
			}
			else
			{
				appid = yield GameHub.Data.Sources.Steam.Steam.get_appid_from_name(game.name);

				// also contains unowned games:
				if(appid == null) appid = yield get_appid_from_name(game.name);
			}

			if(appid != null)
			{
				debug("[Provider.Images.Steam] Found appid %s for game %s", appid, game.name);
				foreach(var size in SIZES)
				{
					var result = new ImagesProvider.Result();
					result.images = new ArrayList<ImagesProvider.Image>();
					result.image_size = size ?? ImageSize(460, 215);
					result.name = "%s: %s (%d × %d)".printf(name, game.name, result.image_size.width, result.image_size.height);
					result.url = "%sapp/%s".printf(DOMAIN, appid);

					string? remote_result = null;
					string? local_result = null;
					switch (size.width) {
					case 460:
						// Always enforced by steam, exists for everything
						local_result = yield search_local(appid);
						remote_result = yield search_remote(appid, "header.jpg", false);
						break;
					//  case 920:
						// Higher resolution of the one above at the same location
						//  break;
					case 600:
						// Enforced since 2019, possibly not available
						local_result = yield search_local(appid, "p");
						remote_result = yield search_remote(appid, "library_600x900_2x.jpg");
						break;
					}

					if(local_result != null)
					{
						result.images.add(new Image(local_result, "Local custom steam grid image"));
					}

					if(remote_result != null)
					{
						result.images.add(new Image(remote_result, "Remote download"));
					}

					if(result.images.size > 0)
					{
						results.add(result);
					}
				}
			}

			return results;
		}

		private async string? search_local(string appid, string format="")
		{
			string[] extensions = { ".png", ".jpg" };
			File? griddir = Sources.Steam.Steam.get_userdata_dir().get_child("config").get_child("grid");

			foreach(var extension in extensions)
			{
				if(griddir.get_child(appid + format + extension).query_exists())
				{
					return "file://" + griddir.get_child(appid + format + extension).get_path();
				}
			}

			return null;
		}

		private async string? search_remote(string appid, string format, bool needs_check=true)
		{
			var exists = !needs_check;
			var endpoint = "%s/%s".printf(appid, format);

			if(needs_check)
			{
				exists = yield image_exists("%s%s".printf(CDN_BASE_URL, endpoint));
			}

			if(exists)
			{
				return "%s%s".printf(CDN_BASE_URL, endpoint);
			}

			return null;
		}

		private async bool image_exists(string url)
		{
			uint status;
			yield Parser.load_remote_file_async(url, "GET", null, null, null, out status);
			if(status == 200)
			{
				return true;
			}
			return false;
		}

		private async string? get_appid_from_name(string game_name)
		{
			var applist_cache_path = @"$(FS.Paths.Cache.Providers)/steam/";
			var cache_file = FS.file(applist_cache_path, APPLIST_CACHE_FILE);
			DateTime? modification_date = null;

			if(cache_file.query_exists())
			{
				try
				{
					// Get modification time so we refresh only once a day
					#if GLIB_2_62
					modification_date = cache_file.query_info("*", FileQueryInfoFlags.NONE).get_modification_date_time();
					#else
					modification_date = new DateTime.from_timeval_utc(cache_file.query_info("*", FileQueryInfoFlags.NONE).get_modification_time());
					#endif
				}
				catch(Error e)
				{
					debug("[Provider.Images.Steam] %s", e.message);
					return null;
				}
			}

			if(!cache_file.query_exists() || modification_date == null || modification_date.compare(new DateTime.now_utc().add_days(-1)) < 0)
			{
				var url = @"$(API_BASE_URL)ISteamApps/GetAppList/v0002/";

				FS.mkdir(applist_cache_path);
				cache_file = FS.file(applist_cache_path, APPLIST_CACHE_FILE);

				try
				{
					var json_string = yield Parser.load_remote_file_async(url);
					var tmp = Parser.parse_json(json_string);
					if(tmp != null && tmp.get_node_type() == Json.NodeType.OBJECT && tmp.get_object().get_object_member("applist").get_array_member("apps").get_length() > 0)
					{
						var dos = new DataOutputStream(cache_file.replace(null, false, FileCreateFlags.NONE));
						dos.put_string(json_string);
						debug("[Provider.Images.Steam] Refreshed steam applist");
					}
					else
					{
						debug("[Provider.Images.Steam] Downloaded applist is empty");
					}
				}
				catch(Error e)
				{
					warning("[Provider.Images.Steam] %s", e.message);
					return null;
				}
			}

			var json = Parser.parse_json_file(applist_cache_path, APPLIST_CACHE_FILE);
			if(json == null || json.get_node_type() != Json.NodeType.OBJECT)
			{
				debug("[Provider.Images.Steam] Error reading steam applist");
				return null;
			}

			var apps = json.get_object().get_object_member("applist").get_array_member("apps").get_elements();
			foreach(var app in apps)
			{
				if(app.get_object().get_string_member("name").down() == game_name.down())
				{
					var appid = app.get_object().get_int_member("appid").to_string();
					return appid;
				}
			}

			return null;
		}
	}
}
