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
using LevelDB;
using ZLib.Utility;

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
			get { return Settings.Auth.Steam.instance.enabled; }
			set { Settings.Auth.Steam.instance.enabled = value; }
		}

		public string? user_id { get; protected set; }
		public string? user_name { get; protected set; }

		private bool? installed = null;

		public BinaryVDF.ListNode? appinfo;
		public BinaryVDF.ListNode? packageinfo;

		public bool is_authenticated_in_steam_client
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
			Settings.Auth.Steam.instance.authenticated = true;

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
			return Settings.Auth.Steam.instance.authenticated && is_authenticated_in_steam_client;
		}

		public void load_appinfo()
		{
			if(appinfo == null)
			{
				appinfo = new AppInfoVDF(FSUtils.find_case_insensitive(FSUtils.file(FSUtils.Paths.Steam.Home), FSUtils.Paths.Steam.AppInfoVDF)).read();
			}
			if(packageinfo == null)
			{
				packageinfo = new PackageInfoVDF(FSUtils.find_case_insensitive(FSUtils.file(FSUtils.Paths.Steam.Home), FSUtils.Paths.Steam.PackageInfoVDF)).read();
			}
		}

		private ArrayList<Game> _games = new ArrayList<Game>(Game.is_equal);

		public override ArrayList<Game> games { get { return _games; } }

		public override async ArrayList<Game> load_games(Utils.FutureResult2<Game, bool>? game_loaded=null, Utils.Future? cache_loaded=null)
		{
			api_key = Settings.Auth.Steam.instance.api_key;

			if(!is_authenticated() || _games.size > 0)
			{
				return _games;
			}

			Utils.thread("SteamLoading", () => {
				_games.clear();

				load_appinfo();

				var cached = Tables.Games.get_all(this);
				games_count = 0;
				if(cached.size > 0)
				{
					foreach(var g in cached)
					{
						if(!Settings.UI.Behavior.instance.merge_games || !Tables.Merges.is_game_merged(g))
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

				if(json_games != null)
				{
					foreach(var g in json_games.get_elements())
					{
						var game = new SteamGame(this, g);
						bool is_new_game = !_games.contains(game);
						if(is_new_game && (!Settings.UI.Behavior.instance.merge_games || !Tables.Merges.is_game_merged(game)))
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

				Idle.add(load_games.callback);
			});

			yield;

			watch_client_registry();

			return _games;
		}

		public static BinaryVDF.ListNode? get_appinfo(string appid)
		{
			if(instance.appinfo != null)
			{
				return (BinaryVDF.ListNode?) instance.appinfo.get(appid);
			}
			return null;
		}

		public static string[]? get_packages_for_app(string appid)
		{
			if(instance.packageinfo == null) return null;
			string[] pkgs = {};
			foreach(var pkg in instance.packageinfo.nodes.values)
			{
				if(appid in ((PackageInfoVDF.PackageNode) pkg).appids)
				{
					pkgs += ((PackageInfoVDF.PackageNode) pkg).id;
				}
			}
			return pkgs;
		}

		public static async string? get_appid_from_name(string game_name)
		{
			if(instance == null) return null;

			instance.load_appinfo();

			if(instance.appinfo == null) return null;

			foreach(var app_node in instance.appinfo.nodes.values)
			{
				if(app_node != null && app_node is BinaryVDF.ListNode)
				{
					var app = (BinaryVDF.ListNode) app_node;
					var common_node = app.get_nested({"appinfo", "common"});

					if(common_node != null && common_node is BinaryVDF.ListNode)
					{
						var common = (BinaryVDF.ListNode) common_node;

						var name_node = common.get("name");
						var type_node = common.get("type");

						if(name_node != null && name_node is BinaryVDF.StringNode && type_node != null && type_node is BinaryVDF.StringNode)
						{
							var name = ((BinaryVDF.StringNode) name_node).value;
							var type = ((BinaryVDF.StringNode) type_node).value;

							if(type != null && type.down() == "game" && name != null && name.down() == game_name.down())
							{
								return app.key;
							}
						}
					}
				}
			}

			return null;
		}

		public static void install_app(string appid)
		{
			Utils.open_uri(@"steam://install/$(appid)");
		}

		public static void install_multiple_apps(string[] appids)
		{
			if(instance.packageinfo == null) return;
			var packages = "";
			foreach(var appid in appids)
			{
				var pkgs = get_packages_for_app(appid);
				foreach(var pkg in pkgs)
				{
					packages += "/" + pkg;
				}
			}
			if(packages.length > 0)
			{
				Utils.open_uri("steam://subscriptioninstall" + packages);
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

		public static File? get_userdata_dir()
		{
			uint64 communityid = uint64.parse(instance.user_id);
			uint64 steamid3 = communityid_to_steamid3(communityid);
			return FSUtils.find_case_insensitive(FSUtils.file(FSUtils.Paths.Steam.Home), @"steam/userdata/$(steamid3)");
		}

		public static void add_game_shortcut(Game game)
		{
			if(is_running())
			{
				notify("[Sources.Steam.add_game_shortcut] No shortcut created because Steam is running, make sure Steam is closed properly.");
				return;
			}
			set_shortcut(game);
			set_shortcut_collection(game);
			set_shortcut_assets(game);
		}

		// add or update shortcut
		private static void set_shortcut(Game game)
		{
			var config_dir = FSUtils.find_case_insensitive(get_userdata_dir(), "config");
			if(config_dir == null || !config_dir.query_exists()) return;

			var shortcuts = FSUtils.find_case_insensitive(config_dir, "shortcuts.vdf") ?? FSUtils.file(config_dir.get_path(), "shortcuts.vdf");
			var vdf = new BinaryVDF(shortcuts);
			var root_node = vdf.read() as BinaryVDF.ListNode;

			if(root_node.get("shortcuts") == null)
			{
				root_node = new BinaryVDF.ListNode.node("shortcuts");
			}
			else
			{
				root_node = root_node.get("shortcuts") as BinaryVDF.ListNode;
			}

			BinaryVDF.ListNode? game_node = null;

			foreach(BinaryVDF.Node node in root_node.nodes.values)
			{
				var tmp = node as BinaryVDF.ListNode;
				var existing_node = tmp.get("LaunchOptions") as BinaryVDF.StringNode;
				if(existing_node.value == "--run " + game.full_id)
				{
					game_node = tmp;
					break;
				}
			}

			if(game_node == null)
			{
				game_node = new BinaryVDF.ListNode.node(root_node.nodes.size.to_string());
			}

			game_node.add_node(new BinaryVDF.StringNode.node("appname", game.name));
			game_node.add_node(new BinaryVDF.StringNode.node("exe", ProjectConfig.PROJECT_NAME));
			game_node.add_node(new BinaryVDF.StringNode.node("LaunchOptions", "--run " + game.full_id));
			game_node.add_node(new BinaryVDF.StringNode.node("ShortcutPath", ProjectConfig.DATADIR + "/applications/" + ProjectConfig.PROJECT_NAME + ".desktop"));
			game_node.add_node(new BinaryVDF.StringNode.node("StartDir", "."));

			if(game.icon != null)
			{
				var cached = ImageCache.local_file(game.icon, @"games/$(game.source.id)/$(game.id)/icons/");
				game_node.add_node(new BinaryVDF.StringNode.node("icon", cached.get_path()));
			}
			else if(game.image != null)
			{
				var cached = ImageCache.local_file(game.image, @"games/$(game.source.id)/$(game.id)/images/");
				game_node.add_node(new BinaryVDF.StringNode.node("icon", cached.get_path()));
			}

			// add missing tags
			var tags_node = game_node.get("tags") as BinaryVDF.ListNode;
			if(tags_node == null) tags_node = new BinaryVDF.ListNode.node("tags");
			tags_node.add_node(new BinaryVDF.StringNode.node("0", "GameHub"));

			foreach(var tag in game.tags)
			{
				var tag_exists = false;
				foreach(var value in tags_node.nodes.values)
				{
					var tmp = value as BinaryVDF.StringNode;
					if(tag.name == tmp.value)
					{
						tag_exists = true;
						break;
					}
				}
				if(!tag_exists)
				{
					tags_node.add_node(new BinaryVDF.StringNode.node(tags_node.nodes.size.to_string(), tag.name));
				}
			}

			game_node.add_node(tags_node);
			root_node.add_node(game_node);

			root_node.show();

			BinaryVDF.write(shortcuts, root_node);
		}

		// add or update artwork
		private static void set_shortcut_assets(Game game)
		{
			// https://github.com/boppreh/steamgrid/blob/master/games.go#L120
			var custom_appid = (crc32(0, (ProjectConfig.PROJECT_NAME + game.name).data) | 0x80000000).to_string();

			if(game.image != null)
			{
				try
				{
					var cached = ImageCache.local_file(game.image, @"games/$(game.source.id)/$(game.id)/images/");
					var dest = FSUtils.file(get_userdata_dir().get_child("config").get_child("grid").get_path(), custom_appid + ".png");
					cached.copy(dest, FileCopyFlags.OVERWRITE);
				}
				catch (Error e) {}
			}

			if(game.image_vertical != null)
			{
				try
				{
					var cached = ImageCache.local_file(game.image_vertical, @"games/$(game.source.id)/$(game.id)/images/");
					var dest = FSUtils.file(get_userdata_dir().get_child("config").get_child("grid").get_path(), custom_appid + "p.png");
					cached.copy(dest, FileCopyFlags.OVERWRITE);
				}
				catch (Error e) {}
			}
		}

		// add or update collections
		private static void set_shortcut_collection(Game game)
		{
			string? error;

			var config_dir = FSUtils.find_case_insensitive(get_userdata_dir(), "config");
			if(config_dir == null || !config_dir.query_exists()) return;

			var collections_db = new SteamCollectionDatabase(instance.user_id, out error);
			if(error != null) return;

			collections_db.read(out error);
			if(error != null) return;

			var localconfig = Parser.parse_vdf_file(config_dir.get_path(), "localconfig.vdf");
			if(localconfig == null || localconfig.get_node_type() != Json.NodeType.OBJECT) return;
			var user_collections = Parser.parse_json(localconfig.get_object().get_object_member("UserLocalConfigStore").get_object_member("WebStorage").get_string_member("user-collections"));
			if(user_collections == null || user_collections.get_node_type() != Json.NodeType.OBJECT) return;

			int64? custom_appid_int;
			try
			{
				// https://github.com/boppreh/steamgrid/blob/master/games.go#L120
				var custom_appid = (crc32(0, (ProjectConfig.PROJECT_NAME + game.name).data) | 0x80000000).to_string();
				int64.from_string(custom_appid, out custom_appid_int);
				if(custom_appid_int == null) return;
			}
			catch (Error e) {return;}

			// Remove from collections where the game doesn't have the tag anymore
			user_collections.get_object().foreach_member((object, name, node) =>
			{
				if(name.has_prefix("gh-") || name == "favorite" || name == "hidden")
				{
					foreach(var tag in game.tags)
					{
						string key;
						if(tag.id == "builtin:favorites")
						{
							key = "favorite";
						}
						else if(tag.id == "builtin:hidden")
						{
							key = "hidden";
						}
						else
						{
							key = @"gh-$(tag.name)";
						}

						if(node.get_object().get_string_member("id") == key) return;
					}

					if(node.get_object().has_member("added") && node.get_object().get_member("added").get_node_type() == Json.NodeType.ARRAY)
					{
						uint? index = null;

						node.get_object().get_array_member("added").foreach_element((a, i, n) =>
						{
							if(n.get_int() == custom_appid_int) index = i;
						});

						if(index != null)
						{
							node.get_object().get_array_member("added").remove_element(index);
							return;
						}
					}
				}
			});

			// add new tags
			var created_collection = false;
			foreach(var tag in game.tags)
			{
				string key;
				if(tag.id == "builtin:favorites")
				{
					key = "favorite";
				}
				else if(tag.id == "builtin:hidden")
				{
					key = "hidden";
				}
				else
				{
					key = @"gh-$(tag.name)";
				}

				var collection = collections_db.get_collection(key);

				// create categorie if it doesn't exist already
				if(collection == null && key.has_prefix("gh-"))
				{
					collection = new Json.Object();
					collection.set_string_member("id", key);
					collection.set_string_member("name", tag.name);
					collection.set_array_member("added", new Json.Array());
					collection.set_array_member("removed", new Json.Array());
					collections_db.set_collection(key, collection);
					created_collection = true;
				}

				if(!user_collections.get_object().has_member(key))
				{
					var object = new Json.Object();
					object.set_string_member("id", key);
					object.set_array_member("added", new Json.Array());
					object.set_array_member("removed", new Json.Array());
					user_collections.get_object().set_object_member(key, object);
				}

				var already_present = false;
				user_collections.get_object().get_object_member(key).get_array_member("added").foreach_element((array, index, node) =>
				{
					if(node.get_int() == custom_appid_int) already_present = true;
				});
				if(!already_present)
				{
					user_collections.get_object().get_object_member(key).get_array_member("added").add_int_element(custom_appid_int);
				}
			}

			debug(@"[Sources.Steam.set_shortcut_collection]\n$(Json.to_string(user_collections, true))");

			var generator = new Json.Generator();
			generator.set_root(user_collections);
			localconfig.get_object().get_object_member("UserLocalConfigStore").get_object_member("WebStorage").set_string_member("user-collections", generator.to_data(null));
			FSUtils.write_string_to_file(FSUtils.file(config_dir.get_path(), "localconfig.vdf"), generate_vdf_from_json(localconfig.get_object()));
			if(created_collection) collections_db.save(out error);
			if(error != null) warning(@"[Sources.Steam.set_shortcut_collection] Error saving database: `%s`", error);
		}

		// https://github.com/node-steam/vdf/blob/master/src/index.ts#L78-L117
		private static string generate_vdf_from_json(Json.Object object, int level = 0)
		{
			var seperator = "	";
			var result = "";
			var indent = "";

			for(var i = 0; i < level; i++)
			{
				indent += seperator;
			}

			object.foreach_member((object, name, node) =>
			{
				if(node.get_node_type() == Json.NodeType.OBJECT && node.get_object() != null)
				{
					result += indent + "\"" + name + "\"\n" + indent + "{\n" + generate_vdf_from_json(node.get_object(), level + 1) + indent + "}\n";
				}
				else
				{
					var generator = new Json.Generator();
					generator.set_root(node);
					result += indent + "\"" + name + "\"" + seperator + seperator + generator.to_data(null) + "\n";
				}
			});

			return result;
		}

		public static bool is_running()
		{
			if(Utils.run({"pidof", "steam"}).run_sync(true).exit_code == 0) return true;
			return false;
		}

		public static bool IsAnyAppRunning = false;
	}
}
