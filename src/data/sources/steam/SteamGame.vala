using Gtk;
using GameHub.Utils;

namespace GameHub.Data.Sources.Steam
{
	public class SteamGame: Game
	{
		private bool? _is_for_linux = null;
		private int metadata_tries = 0;
		
		public SteamGame(Steam src, Json.Object json)
		{
			this.source = src;
			
			this.id = json.get_int_member("appid").to_string();
			this.name = json.get_string_member("name");
			
			var icon_hash = json.get_string_member("img_icon_url");
			var image_hash = json.get_string_member("img_logo_url");
			
			this.icon = @"https://media.steampowered.com/steamcommunity/public/images/apps/$(id)/$(icon_hash).jpg";
			this.image = @"https://cdn.akamai.steamstatic.com/steam/apps/$(id)/header.jpg";
			
			this.command = @"xdg-open steam://rungameid/$(id)";
			
			int64 minutes = json.get_int_member("playtime_forever");
			int64 hours = (int) (minutes / 60.0f);
			
			this.playtime = minutes > 60 ? @"$(hours) hours" : @"$(minutes) minutes";
		}
		
		public override async bool is_for_linux()
		{
			if(_is_for_linux != null) return _is_for_linux;
			
			metadata_tries++;
			
			print("[Steam app %s] Checking for linux compatibility [%d]...\n", this.id, metadata_tries);
			
			var url = @"https://store.steampowered.com/api/appdetails?appids=$(id)";
			var root = yield Parser.parse_remote_json_file_async(url);
			var platforms = Parser.json_object(root, {this.id, "data", "platforms"});
			
			if(platforms == null)
			{
				if(metadata_tries > 2)
				{
					print("[Steam app %s] No data, %d tries failed, assuming no linux support\n", this.id, metadata_tries);
					_is_for_linux = false;
					return _is_for_linux;
				}
				
				print("[Steam app %s] No data, sleeping for 2.5s\n", this.id);
				yield Utils.sleep_async(2500);
				return yield is_for_linux();
			}
			
			_is_for_linux = platforms.get_boolean_member("linux");
			
			return _is_for_linux;
		}
		
		public override bool is_installed()
		{
			foreach(var dir in Steam.LibraryFolders)
			{
				var acf = FSUtils.file(dir, @"appmanifest_$(id).acf");
				if(acf.query_exists())
				{
					return true;
				}
			}
			
			return false;
		}
		
		public override async void install()
		{
			yield run();
		}
		
		public override async void run()
		{
			Utils.open_uri(@"steam://rungameid/$(id)");
		}
	}
}
