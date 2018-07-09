using Gtk;
using GameHub.Utils;

namespace GameHub.Data.Sources.Steam
{
	public class SteamGame: Game
	{
		private bool? _is_for_linux = null;
		private bool _product_info_updated = false;
		private int metadata_tries = 0;
		
		public SteamGame(Steam src, Json.Object json)
		{
			source = src;
			id = json.get_int_member("appid").to_string();
			name = json.get_string_member("name");
			var icon_hash = json.get_string_member("img_icon_url");
			icon = @"https://media.steampowered.com/steamcommunity/public/images/apps/$(id)/$(icon_hash).jpg";
			image = @"https://cdn.akamai.steamstatic.com/steam/apps/$(id)/header.jpg";

			if(GamesDB.get_instance().is_game_unsupported(src, id))
			{
				_is_for_linux = false;
			}
			is_installed();

			store_page = @"steam://store/$(id)";
		}
		
		public SteamGame.from_db(Steam src, Sqlite.Statement stmt)
		{
			source = src;
			id = stmt.column_text(1);
			name = stmt.column_text(2);
			icon = stmt.column_text(3);
			image = stmt.column_text(4);
			custom_info = stmt.column_text(5);
			_is_for_linux = true;
			is_installed();
			store_page = @"steam://store/$(id)";
		}

		public override async void update_game_info()
		{
			if(custom_info == null || custom_info.length == 0 || !_product_info_updated)
			{
				var url = @"https://store.steampowered.com/api/appdetails?appids=$(id)";
				custom_info = (yield Parser.load_remote_file_async(url));
				_product_info_updated = true;
			}

			var root = Parser.parse_json(custom_info);
			description = Parser.json_object(root, {id, "data"}).get_string_member("detailed_description");

			if(_is_for_linux == true) GamesDB.get_instance().add_game(this);
		}
		
		public override async bool is_for_linux()
		{
			if(_is_for_linux != null) return _is_for_linux;
			
			metadata_tries++;
			
			debug("[Steam] <app %s> Checking for compatibility [%d]...\n", id, metadata_tries);
			
			yield update_game_info();

			var root = Parser.parse_json(custom_info);
			var platforms = Parser.json_object(root, {id, "data", "platforms"});
			
			if(platforms == null)
			{
				if(metadata_tries > 2)
				{
					debug("[Steam] <app %s> No data, %d tries failed, assuming no linux support\n", id, metadata_tries);
					_is_for_linux = false;
					GamesDB.get_instance().add_unsupported_game(source, id);
					return _is_for_linux;
				}
				
				debug("[Steam] <app %s> No data, sleeping for 2.5s\n", id);
				yield Utils.sleep_async(2500);
				return yield is_for_linux();
			}
			
			_is_for_linux = platforms.get_boolean_member("linux");
			
			if(_is_for_linux == false) GamesDB.get_instance().add_unsupported_game(source, id);

			return _is_for_linux;
		}
		
		public override bool is_installed()
		{
			foreach(var dir in Steam.LibraryFolders)
			{
				var acf = FSUtils.file(dir, @"appmanifest_$(id).acf");
				if(acf.query_exists())
				{
					var root = Parser.parse_vdf_file(acf.get_path()).get_object();
					install_dir = FSUtils.file(dir, "common/" + root.get_object_member("AppState").get_string_member("installdir"));
					status = new Game.Status(Game.State.INSTALLED);
					return true;
				}
			}
			
			status = new Game.Status(Game.State.UNINSTALLED);
			return false;
		}
		
		public override async void install(DownloadProgress progress = (d, t) => {})
		{
			yield run();
		}
		
		public override async void run()
		{
			Utils.open_uri(@"steam://rungameid/$(id)");
		}
	}
}
