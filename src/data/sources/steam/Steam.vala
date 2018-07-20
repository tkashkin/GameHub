using Gtk;
using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.Steam
{
	public class Steam: GameSource
	{
		private string api_key;
		
		public override string name { get { return "Steam"; } }
		public override string icon { get { return "steam"; } }
		public override string auth_description
		{
			owned get
			{
				var text = _("Your SteamID will be read from Steam configuration file");
				if(!is_authenticated_in_steam_client)
				{
					text = _("Steam config file not found.\nLogin into your account in Steam client and return to GameHub");
				}
				return ".\n%s".printf(text);
			}
		}

		public override bool enabled
		{
			get { return Settings.Auth.Steam.get_instance().enabled; }
			set { Settings.Auth.Steam.get_instance().enabled = value; }
		}
		
		public string? user_id { get; protected set; }
		public string? user_name { get; protected set; }

		private bool? installed = null;

		private bool is_authenticated_in_steam_client { get { return FSUtils.file(FSUtils.Paths.Steam.LoginUsersVDF).query_exists(); } }

		public override bool is_installed(bool refresh)
		{
			if(installed != null && !refresh)
			{
				return (!) installed;
			}

			if("elementary" in Utils.get_distro())
			{
				installed = Utils.is_package_installed("steam");
			}
			else
			{
				installed = FSUtils.file(FSUtils.Paths.Steam.Home).query_exists();
			}

			return (!) installed;
		}

		public override async bool install()
		{
			if("elementary" in Utils.get_distro())
			{
				Utils.open_uri("appstream://steam.desktop");
			}
			return true;
		}

		public override async bool authenticate()
		{
			Settings.Auth.Steam.get_instance().authenticated = true;
			
			if(is_authenticated()) return true;
			
			var result = false;
			
			if(!is_authenticated_in_steam_client)
			{
				yield Utils.run_async({"steam"}, null, false, false);
				return false;
			}

			new Thread<void*>("steam-loginusers-thread", () => {
				var config = Parser.parse_vdf_file(FSUtils.Paths.Steam.LoginUsersVDF);
				var users = Parser.json_object(config, {"users"});
				
				if(users == null)
				{
					result = false;
					Idle.add(authenticate.callback);
					return null;
				}
				
				foreach(var uid in users.get_members())
				{
					user_id = uid;
					user_name = users.get_object_member(uid).get_string_member("PersonaName");
					
					debug("[Auth] SteamID: %s, PersonaName: %s", user_id, user_name);
					
					result = true;
					break;
				}
				
				Idle.add(authenticate.callback);
				return null;
			});
			
			yield;
			return result;
		}
		
		public override bool is_authenticated()
		{
			return user_id != null;
		}
		
		public override bool can_authenticate_automatically()
		{
			return Settings.Auth.Steam.get_instance().authenticated && is_authenticated_in_steam_client;
		}

		private ArrayList<Game> games = new ArrayList<Game>(Game.is_equal);
		public override async ArrayList<Game> load_games(FutureResult<Game>? game_loaded = null)
		{
			api_key = Settings.Auth.Steam.get_instance().api_key;
			
			if(!is_authenticated() || games.size > 0)
			{
				return games;
			}
			
			games.clear();
			
			var cached = GamesDB.get_instance().get_games(this);
			if(cached.size > 0)
			{
				games = cached;
				if(game_loaded != null)
				{
					foreach(var g in cached)
					{
						game_loaded(g);
					}
				}
			}
			games_count = games.size;
			
			var url = @"https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=$(api_key)&steamid=$(user_id)&format=json&include_appinfo=1&include_played_free_games=1";
			
			var root = yield Parser.parse_remote_json_file_async(url);
			var json_games = Parser.json_object(root, {"response"}).get_array_member("games");
			
			foreach(var g in json_games.get_elements())
			{
				var game = new SteamGame(this, g.get_object());
				if(!games.contains(game) && yield game.is_for_linux())
				{
					games.add(game);
					if(game_loaded != null) game_loaded(game);
					GamesDB.get_instance().add_game(game);
				}
				games_count = games.size;
			}
			
			return games;
		}
		
		public static ArrayList<string>? folders = null;
		public static ArrayList<string> LibraryFolders
		{
			get
			{
				if(folders != null) return folders;
				
				folders = new ArrayList<string>();
				folders.add(FSUtils.Paths.Steam.SteamApps);
				
				var root = Parser.parse_vdf_file(FSUtils.Paths.Steam.LibraryFoldersVDF);
				var lf = Parser.json_object(root, {"LibraryFolders"});
				
				if(lf != null)
				{
					foreach(var key in lf.get_members())
					{
						var dir = lf.get_string_member(key) + "/steamapps";
						if(FSUtils.file(dir).query_exists()) folders.add(dir);
					}
				}
				
				return folders;
			}
		}
	}
}
