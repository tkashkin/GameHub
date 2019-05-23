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

namespace GameHub.Data.Sources.Steam
{
	public class Steam: GameSource
	{
		public static Steam instance;

		public Steam()
		{
			instance = this;
		}

		public string api_key;

		public override string id { get { return "steam"; } }
		public override string name { get { return "Steam"; } }
		public override string icon { get { return "source-steam-symbolic"; } }
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

		private bool is_authenticated_in_steam_client
		{
			get
			{
				var loginusers = FSUtils.find_case_insensitive(FSUtils.file(FSUtils.Paths.Steam.Home), FSUtils.Paths.Steam.LoginUsersVDF);
				return loginusers != null && loginusers.query_exists();
			}
		}

		public override bool is_installed(bool refresh)
		{
			if(installed != null && !refresh)
			{
				return (!) installed;
			}

			var distro = Utils.get_distro().down();
			if("ubuntu" in distro || "elementary" in distro || "pop!_os" in distro)
			{
				installed = Utils.is_package_installed("steam")
				         || Utils.is_package_installed("steam64")
				         || Utils.is_package_installed("steam-launcher")
				         || Utils.is_package_installed("steam-installer")
				         || FSUtils.file(FSUtils.Paths.Steam.Home).query_exists();
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
				var acf = FSUtils.find_case_insensitive(FSUtils.file(dir), @"appmanifest_$(app).acf");
				if(acf != null && acf.query_exists())
				{
					var root = Parser.parse_vdf_file(acf.get_path()).get_object();
					var d = FSUtils.find_case_insensitive(FSUtils.file(dir), "common/" + root.get_object_member("AppState").get_string_member("installdir"));
					install_dir = d;
					return d != null && d.query_exists();
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
			var distro = Utils.get_distro().down();
			if("elementary" in distro || "pop!_os" in distro)
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
				var loginusers = FSUtils.find_case_insensitive(FSUtils.file(FSUtils.Paths.Steam.Home), FSUtils.Paths.Steam.LoginUsersVDF);

				if(loginusers == null || !loginusers.query_exists())
				{
					result = false;
					Idle.add(authenticate.callback);
					return;
				}

				var config = Parser.parse_vdf_file(loginusers.get_path());
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

					if(GameHub.Application.log_auth)
					{
						debug(@"[Auth] SteamID: $(user_id), PersonaName: $(user_name), last: $(last)");
					}

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

				var cached = Tables.Games.get_all(this);
				games_count = 0;
				if(cached.size > 0)
				{
					foreach(var g in cached)
					{
						if(!Settings.UI.get_instance().merge_games || !Tables.Merges.is_game_merged(g))
						{
							_games.add(g);
							if(game_loaded != null)
							{
								game_loaded(g, true);
							}
						}
						games_count++;
					}
				}

				if(cache_loaded != null)
				{
					cache_loaded();
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

			watch_client_registry();

			return _games;
		}

		private async void add_games(Json.Array json_games, FutureResult2<Game, bool>? game_loaded = null)
		{
			if(json_games != null)
			{
				foreach(var g in json_games.get_elements())
				{
					var game = new SteamGame(this, g);
					bool is_new_game = !_games.contains(game);
					if(is_new_game && (!Settings.UI.get_instance().merge_games || !Tables.Merges.is_game_merged(game)))
					{
						_games.add(game);
						if(game_loaded != null)
						{
							game_loaded(game, false);
						}
					}
					if(is_new_game)
					{
						games_count++;
						game.save();
					}
					else if(g != null && g.get_node_type() == Json.NodeType.OBJECT)
					{
						_games.get(_games.index_of(game)).playtime_source = g.get_object().get_int_member("playtime_forever");
					}
				}
			}
		}

		private void watch_client_registry()
		{
			var regfile = FSUtils.find_case_insensitive(FSUtils.file(FSUtils.Paths.Steam.Home), FSUtils.Paths.Steam.RegistryVDF);
			if(regfile == null || !regfile.query_exists()) return;

			Timeout.add_seconds(5, () => {
				Utils.thread("SteamClientRegistryUpdate", () => {
					client_registry_update(regfile);
				}, false);
				return Source.CONTINUE;
			}, Priority.LOW);
		}

		private void client_registry_update(File? regfile)
		{
			if(regfile == null || !regfile.query_exists()) return;

			var reg = Parser.parse_vdf_file(regfile.get_path());
			var steam = Parser.json_object(reg, {"Registry", "HKCU", "Software", "Valve", "Steam"});

			if(steam == null) return;

			var running_appid = steam.has_member("RunningAppID") ? steam.get_string_member("RunningAppID") : "0";
			IsAnyAppRunning = running_appid != "0";

			var apps = steam.has_member("Apps") ? steam.get_member("Apps") : null;

			foreach(var g in _games)
			{
				var game = g as SteamGame;

				var appinfo  = Parser.json_object(apps, {game.id});
				var running  = game.id == running_appid || (appinfo != null && appinfo.has_member("Running") && appinfo.get_string_member("Running") == "1");
				var updating = appinfo != null && appinfo.has_member("Updating") && appinfo.get_string_member("Updating") == "1";

				if(game.is_running != running || game.is_updating != updating)
				{
					game.is_running = running;
					game.is_updating = updating;
					game.update_status();
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

				var steamapps = FSUtils.find_case_insensitive(FSUtils.file(FSUtils.Paths.Steam.Home), FSUtils.Paths.Steam.SteamApps);

				if(steamapps == null || !steamapps.query_exists()) return folders;

				folders.add(steamapps.get_path());

				var libraryfolders = FSUtils.find_case_insensitive(steamapps, FSUtils.Paths.Steam.LibraryFoldersVDF);

				if(libraryfolders == null || !libraryfolders.query_exists()) return folders;

				var root = Parser.parse_vdf_file(libraryfolders.get_path());
				var lf = Parser.json_object(root, {"LibraryFolders"});

				if(lf != null)
				{
					foreach(var key in lf.get_members())
					{
						var libdir = FSUtils.file(lf.get_string_member(key));
						if(libdir != null && libdir.query_exists())
						{
							var dir = FSUtils.find_case_insensitive(libdir, "steamapps");
							if(dir != null && dir.query_exists()) folders.add(dir.get_path());
						}
					}
				}

				return folders;
			}
		}

		public static uint64 communityid_to_steamid3(uint64 id)
		{
			return id - 76561197960265728;
		}

		public static void add_game_shortcut(Game game)
		{
			uint64 communityid = uint64.parse(instance.user_id);
			uint64 steamid3 = communityid_to_steamid3(communityid);

			var config_dir = FSUtils.find_case_insensitive(FSUtils.file(FSUtils.Paths.Steam.Home), @"steam/userdata/$(steamid3)/config");

			if(config_dir == null || !config_dir.query_exists()) return;

			var shortcuts = FSUtils.find_case_insensitive(config_dir, "shortcuts.vdf") ?? FSUtils.file(config_dir.get_path(), "shortcuts.vdf");

			var vdf = new BinaryVDF(shortcuts);

			var root_node = vdf.read() as BinaryVDF.ListNode;

			if(root_node == null)
			{
				root_node = new BinaryVDF.ListNode.node("shortcuts");
			}

			var game_node = new BinaryVDF.ListNode.node(root_node.nodes.size.to_string());

			game_node.add_node(new BinaryVDF.StringNode.node("AppName", game.name));
			game_node.add_node(new BinaryVDF.StringNode.node("exe", ProjectConfig.PROJECT_NAME));
			game_node.add_node(new BinaryVDF.StringNode.node("LaunchOptions", "--run " + game.full_id));
			game_node.add_node(new BinaryVDF.StringNode.node("ShortcutPath", ProjectConfig.DATADIR + "/applications/" + ProjectConfig.PROJECT_NAME + ".desktop"));
			game_node.add_node(new BinaryVDF.StringNode.node("StartDir", "."));
			game_node.add_node(new BinaryVDF.IntNode.node("IsHidden", 0));
			game_node.add_node(new BinaryVDF.IntNode.node("OpenVR", 0));
			game_node.add_node(new BinaryVDF.IntNode.node("AllowOverlay", 1));
			game_node.add_node(new BinaryVDF.IntNode.node("AllowDesktopConfig", 1));
			game_node.add_node(new BinaryVDF.IntNode.node("LastPlayTime", 1));

			if(game.image != null)
			{
				var cached = ImageCache.local_file(game.image, "image");
				game_node.add_node(new BinaryVDF.StringNode.node("icon", cached.get_path()));
			}

			var tags_node = new BinaryVDF.ListNode.node("tags");
			tags_node.add_node(new BinaryVDF.StringNode.node("0", "GameHub"));
			game_node.add_node(tags_node);

			root_node.add_node(game_node);

			root_node.show();

			BinaryVDF.write(shortcuts, root_node);
		}

		public static bool IsAnyAppRunning = false;
	}
}
