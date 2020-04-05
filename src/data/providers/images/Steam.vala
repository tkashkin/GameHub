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
using GameHub.Utils;

namespace GameHub.Data.Providers.Images
{
	public class Steam: ImagesProvider
	{
		private const string DOMAIN       = "https://store.steampowered.com/";
		private const string CDN_BASE_URL = "http://cdn.akamai.steamstatic.com/steam/apps/";
		private const string API_KEY_PAGE = "https://steamcommunity.com/dev/apikey";
		private const string API_BASE_URL = "https://api.steampowered.com/";

		//  private const string APPLIST_CACHE_PATH = @"$(FSUtils.Paths.Cache.Providers)/steam/";
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
			var app_id = "";

			if(game is GameHub.Data.Sources.Steam.SteamGame)
			{
				app_id = game.id;
			}
			else
			{
				app_id = yield get_appid(game.name);
			}

			if(app_id != "")
			{
				foreach(var size in SIZES)
				{
					var needs_check = false;
					var exists = false;
					var result = new ImagesProvider.Result();
					result.image_size = size ?? ImageSize(460, 215);
					result.name = "%s: %s (%d × %d)".printf(name, game.name, result.image_size.width, result.image_size.height);
					result.url = "%sapp/%s".printf(DOMAIN, app_id);

					var format = "header.jpg";
					switch (size.width) {
					case 460:
						// Always enforced by steam, exists for everything
						format = "header.jpg";
						exists = true;
						break;
					//  case 920:
						// Higher resolution of the one above at the same location
						//  format = "header.jpg";
						//  break;
					case 600:
						// Enforced since 2019, possibly not available
						format = "library_600x900_2x.jpg";
						needs_check = true;
						break;
					}

					var endpoint = "%s/%s".printf(app_id, format);

					result.images = new ArrayList<ImagesProvider.Image>();

					if(needs_check)
					{
						exists = yield image_exists("%s%s".printf(CDN_BASE_URL, endpoint));
					}

					if(exists)
					{
						result.images.add(new Image("%s%s".printf(CDN_BASE_URL, endpoint)));
					}

					if(result.images.size > 0)
					{
						results.add(result);
					}
				}
			}

			return results;
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

		private async string get_appid(string name)
		{
			var applist_cache_path = @"$(FSUtils.Paths.Cache.Providers)/steam/";
			var cache_file = FSUtils.file(applist_cache_path, APPLIST_CACHE_FILE);
			DateTime? modification_date = null;

			if(cache_file.query_exists())
			{
				try
				{
					// Get modification time so we refresh only once a day
					modification_date = cache_file.query_info("*", NONE).get_modification_date_time();
				}
				catch(Error e)
				{
					debug("[Provider.Images.Steam] %s", e.message);
					return "";
				}
			}

			if(!cache_file.query_exists() || modification_date == null || modification_date.compare(new DateTime.now_utc().add_days(-1)) < 0)
			{
				// https://api.steampowered.com/ISteamApps/GetAppList/v0002/?key=
				var url = @"$(API_BASE_URL)ISteamApps/GetAppList/v0002/?key=$(Settings.Providers.Images.Steam.instance.api_key)";

				FSUtils.mkdir(applist_cache_path);
				cache_file = FSUtils.file(applist_cache_path, APPLIST_CACHE_FILE);

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
					return "";
				}
			}

			var json = Parser.parse_json_file(applist_cache_path, APPLIST_CACHE_FILE);
			if(json == null || json.get_node_type() != Json.NodeType.OBJECT)
			{
				debug("[Provider.Images.Steam] Error reading steam applist");
				return "";
			}

			var apps = json.get_object().get_object_member("applist").get_array_member("apps").get_elements();
			foreach(var app in apps)
			{
				// exact match, maybe do some fuzzy matching?
				if(app.get_object().get_string_member("name") == name)
				{
					var appid = app.get_object().get_int_member("appid").to_string();
					debug("[Provider.Images.Steam] Found appid %s for game %s", appid, name);
					return appid;
				}
			}

			return "";
		}

		public override Gtk.Widget? settings_widget
		{
			owned get
			{
				var settings = Settings.Providers.Images.Steam.instance;

				var grid = new Gtk.Grid();
				grid.column_spacing = 12;
				grid.row_spacing = 4;

				var entry = new Gtk.Entry();
				entry.placeholder_text = _("Default");
				entry.max_length = 32;
				if(settings.api_key != settings.schema.get_default_value("api-key").get_string())
				{
					entry.text = settings.api_key;
				}
				entry.secondary_icon_name = "edit-delete-symbolic";
				entry.secondary_icon_tooltip_text = _("Restore default API key");
				entry.set_size_request(250, -1);

				entry.notify["text"].connect(() => { settings.api_key = entry.text; });
				entry.icon_press.connect((pos, e) => {
					if(pos == Gtk.EntryIconPosition.SECONDARY)
					{
						entry.text = "";
					}
				});

				var label = new Gtk.Label(_("API key"));
				label.halign = Gtk.Align.START;
				label.valign = Gtk.Align.CENTER;
				label.hexpand = true;

				var entry_wrapper = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
				entry_wrapper.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);

				var link = new Gtk.Button.with_label(_("Generate key"));
				link.tooltip_text = API_KEY_PAGE;

				link.clicked.connect(() => {
					Utils.open_uri(API_KEY_PAGE);
				});

				entry_wrapper.add(entry);
				entry_wrapper.add(link);

				grid.attach(label, 0, 0);
				grid.attach(entry_wrapper, 1, 0);

				return grid;
			}
		}
	}
}
