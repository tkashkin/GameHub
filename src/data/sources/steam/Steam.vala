using Gtk;
using Gee;
using GameHub.Utils;

namespace GameHub.Data.Sources.Steam
{
	public class Steam: GameSource
	{
		private string api_key;

		public static string[] PROTON_APPIDS = {"858280", "930400"};

		public override string id { get { return "steam"; } }
		public override string name { get { return "Steam"; } }
		public override string icon { get { return "steam-symbolic"; } }
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

		public static bool find_app_install_dir(string app, out File? install_dir)
		{
			install_dir = null;
			foreach(var dir in Steam.LibraryFolders)
			{
				var acf = FSUtils.file(dir, @"appmanifest_$(app).acf");
				if(acf.query_exists())
				{
					var root = Parser.parse_vdf_file(acf.get_path()).get_object();
					var d = FSUtils.file(dir, "common/" + root.get_object_member("AppState").get_string_member("installdir"));
					install_dir = d;
					return d.query_exists();
				}
			}
			return false;
		}

		public static bool is_app_installed(string app)
		{
			return find_app_install_dir(app, null);
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
				Utils.open_uri("steam://");
				return false;
			}

			Utils.thread("Steam-loginusers", () => {
				var config = Parser.parse_vdf_file(FSUtils.Paths.Steam.LoginUsersVDF);
				var users = Parser.json_object(config, {"users"});

				if(users == null)
				{
					result = false;
					Idle.add(authenticate.callback);
					return;
				}

				foreach(var uid in users.get_members())
				{
					var user = users.get_object_member(uid);

					user_id = uid;
					user_name = user.get_string_member("PersonaName");

					var last = !user.has_member("mostrecent") || user.get_string_member("mostrecent") == "1";

					debug(@"[Auth] SteamID: $(user_id), PersonaName: $(user_name), last: $(last)");

					if(last)
					{
						result = true;
						break;
					}
				}

				Idle.add(authenticate.callback);
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

		private ArrayList<Game> _games = new ArrayList<Game>(Game.is_equal);

		public override ArrayList<Game> games { get { return _games; } }

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null)
		{
			api_key = Settings.Auth.Steam.get_instance().api_key;

			if(!is_authenticated() || _games.size > 0)
			{
				return _games;
			}

			Utils.thread("SteamLoading", () => {
				_games.clear();

				var cached = GamesDB.get_instance().get_games(this);
				if(cached.size > 0)
				{
					foreach(var g in cached)
					{
						if(!Settings.UI.get_instance().merge_games || !GamesDB.get_instance().is_game_merged(g))
						{
							//g.update_game_info.begin();
							_games.add(g);
							games_count = _games.size;
							if(game_loaded != null)
							{
								Idle.add(() => { game_loaded(g, true); return Source.REMOVE; });
								Thread.usleep(100000);
							}
						}
					}
				}

				games_count = _games.size;

				if(cache_loaded != null)
				{
					Idle.add(() => { cache_loaded(); return Source.REMOVE; });
				}

				var url = @"https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=$(api_key)&steamid=$(user_id)&format=json&include_appinfo=1&include_played_free_games=1";

				var root = Parser.parse_remote_json_file(url);
				var response = Parser.json_object(root, {"response"});
				var json_games = response != null && response.has_member("games") ? response.get_array_member("games") : null;

				add_games.begin(json_games, game_loaded, (obj, res) => {
					add_games.end(res);
					Idle.add(load_games.callback);
				});
			});

			yield;

			return _games;
		}

		private async void add_games(Json.Array json_games, FutureResult2<Game, bool>? game_loaded = null)
		{
			if(json_games != null)
			{
				foreach(var g in json_games.get_elements())
				{
					var game = new SteamGame(this, g);
					if(!_games.contains(game) && (!Settings.UI.get_instance().merge_games || !GamesDB.get_instance().is_game_merged(game)))
					{
						yield game.update_game_info();
						_games.add(game);
						games_count = _games.size;
						if(game_loaded != null)
						{
							Idle.add(() => { game_loaded(game, false); return Source.REMOVE; });
							Thread.usleep(100000);
						}
					}
				}
			}
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
