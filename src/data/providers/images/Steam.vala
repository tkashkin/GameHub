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
		private const string DOMAIN       = "https://store.steampowered.com";
		private const string CDN_BASE_URL = "http://cdn.akamai.steamstatic.com/steam/apps";
		private const string API_BASE_URL = "https://api.steampowered.com";
		private const string API_KEY_PAGE = "https://steamcommunity.com/dev/apikey";

		private const string APPLIST_CACHE_FILE = "applist.json";
		private ImagesProvider.ImageSize[] SIZES = { ImageSize(460, 215), ImageSize(600, 900) };

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
				appid = yield GameHub.Data.Sources.Steam.Steam.find_appid_by_name(game.name);
				if(appid == null) appid = yield find_appid_by_name(game.name);
			}

			if(appid != null)
			{
				debug("[Provider.Images.Steam] Found appid %s for game %s", appid, game.name);
				foreach(var size in SIZES)
				{
					results.add(new Result(this, game, appid, size));
				}
			}

			return results;
		}

		private async string? find_appid_by_name(string name)
		{
			var applist_cache_path = @"$(FS.Paths.Cache.Providers)/steam";
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
				var url = @"$(API_BASE_URL)/ISteamApps/GetAppList/v0002/";

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
						debug("[Provider.Images.Steam] Refreshed Steam applist");
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
				debug("[Provider.Images.Steam] Error reading Steam applist");
				return null;
			}

			var applist = Parser.json_object(json, {"applist"});
			if(applist == null) return null;

			var apps = applist.has_member("apps") ? applist.get_array_member("apps") : null;
			if(apps == null) return null;

			var name_normalized = Utils.strip_name(name, null, true).casefold();

			foreach(var app in apps.get_elements())
			{
				if(app.get_node_type() != Json.NodeType.OBJECT) continue;
				var obj = app.get_object();
				if(obj == null) continue;

				var appname = obj.has_member("name") ? obj.get_string_member("name") : null;
				var appid = obj.has_member("appid") ? obj.get_int_member("appid").to_string() : null;

				if(appid != null && appname != null)
				{
					var app_name_normalized = Utils.strip_name(appname, null, true).casefold();
					if(app_name_normalized == name_normalized)
					{
						return appid;
					}
				}
			}

			return null;
		}

		public class Result: ImagesProvider.Result
		{
			private Game game;
			private string appid;
			private ArrayList<ImagesProvider.Image>? images = null;

			public Result(Steam source, Game game, string appid, ImagesProvider.ImageSize? size)
			{
				this.game = game;
				this.appid = appid;
				provider = source;
				image_size = size ?? ImageSize(460, 215);
				name = "%s: %s (%d × %d)".printf(source.name, game.name, image_size.width, image_size.height);
				title = "%s: %d × %d".printf(source.name, image_size.width, image_size.height);
				subtitle = game.name;
				url = "%s/app/%s".printf(Steam.DOMAIN, appid);
			}

			public override async ArrayList<ImagesProvider.Image>? load_images()
			{
				if(images != null) return images;

				images = new ArrayList<ImagesProvider.Image>();

				string? remote = null;
				string? local = null;
				switch(image_size.width)
				{
					case 460:
						local = yield search_local();
						remote = yield search_remote( "header.jpg", false);
						break;
					case 600:
						local = yield search_local("p");
						remote = yield search_remote("library_600x900_2x.jpg");
						break;
				}

				if(local != null)
				{
					images.add(new Image(local, _("Local grid image")));
				}

				if(remote != null)
				{
					images.add(new Image(remote, _("Remote grid image")));
				}

				return images;
			}

			private async string? search_local(string format="")
			{
				string[] extensions = { ".png", ".jpg" };
				var grid_dir = Sources.Steam.Steam.get_userdata_dir().get_child("config").get_child("grid");

				foreach(var extension in extensions)
				{
					var img_file = grid_dir.get_child(appid + format + extension);
					if(img_file.query_exists())
					{
						return img_file.get_uri();
					}
				}

				return null;
			}

			private async string? search_remote(string format, bool needs_check=true)
			{
				var exists = !needs_check;
				var endpoint = "%s/%s".printf(appid, format);

				if(needs_check)
				{
					exists = yield image_exists("%s/%s".printf(CDN_BASE_URL, endpoint));
				}

				if(exists)
				{
					return "%s/%s".printf(CDN_BASE_URL, endpoint);
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
		}
	}
}
