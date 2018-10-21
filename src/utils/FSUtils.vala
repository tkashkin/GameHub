/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

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
using Gdk;
using GLib;

using GameHub.Data;

namespace GameHub.Utils
{
	public class FSUtils
	{
		public class Paths
		{
			public class Settings: Granite.Services.Settings
			{
				public string steam_home { get; set; }
				public string gog_games { get; set; }
				public string humble_games { get; set; }

				public string libretro_core_dir { get; set; }
				public string libretro_core_info_dir { get; set; }

				public Settings()
				{
					base(ProjectConfig.PROJECT_NAME + ".paths");
				}

				private static Settings? instance;
				public static unowned Settings get_instance()
				{
					if(instance == null)
					{
						instance = new Settings();
					}
					return instance;
				}
			}

			public class Cache
			{
				public const string Home = "~/.cache/com.github.tkashkin.gamehub";

				public const string Cookies = FSUtils.Paths.Cache.Home + "/cookies";
				public const string Images = FSUtils.Paths.Cache.Home + "/images";

				public const string Database = FSUtils.Paths.Cache.Home + "/gamehub.db";
			}

			public class Steam
			{
				public static string Home
				{
					owned get
					{
						/*#if FLATPAK
						return "/home/" + Environment.get_user_name() + "/.var/app/com.valvesoftware.Steam/.steam";
						#else*/
						return FSUtils.Paths.Settings.get_instance().steam_home;
						//#endif
					}
				}
				public static string Config { owned get { return FSUtils.Paths.Steam.Home + "/steam/config"; } }
				public static string LoginUsersVDF { owned get { return FSUtils.Paths.Steam.Config + "/loginusers.vdf"; } }

				public static string SteamApps { owned get { return FSUtils.Paths.Steam.Home + "/steam/steamapps"; } }
				public static string LibraryFoldersVDF { owned get { return FSUtils.Paths.Steam.SteamApps + "/libraryfolders.vdf"; } }
			}

			public class GOG
			{
				public static string Games
				{
					owned get
					{
						/*#if FLATPAK
						return Environment.get_user_data_dir() + "/games/GOG";
						#else*/
						return FSUtils.Paths.Settings.get_instance().gog_games;
						//#endif
					}
				}
			}

			public class Humble
			{
				public static string Games
				{
					owned get
					{
						/*#if FLATPAK
						return Environment.get_user_data_dir() + "/games/HumbleBundle";
						#else*/
						return FSUtils.Paths.Settings.get_instance().humble_games;
						//#endif
					}
				}
			}

			public class Collection: Granite.Services.Settings
			{
				public string root { get; set; }

				public static string expand_root()
				{
					return FSUtils.expand(get_instance().root);
				}

				public Collection()
				{
					base(ProjectConfig.PROJECT_NAME + ".paths.collection");
				}

				private static Collection? instance;
				public static unowned Collection get_instance()
				{
					if(instance == null)
					{
						instance = new Collection();
					}
					return instance;
				}

				public class GOG: Granite.Services.Settings
				{
					public string game_dir { get; set; }
					public string installers { get; set; }
					public string dlc { get; set; }
					public string bonus { get; set; }

					public static string expand_game_dir(string game)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.get_instance().root);
						variables.set("game", g);
						return FSUtils.expand(get_instance().game_dir, null, variables);
					}
					public static string expand_dlc(string game)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.get_instance().root);
						variables.set("game", g);
						variables.set("game_dir", expand_game_dir(g));
						return FSUtils.expand(get_instance().dlc, null, variables);
					}
					public static string expand_installers(string game, string? dlc=null)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var d = dlc == null ? null : dlc.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.get_instance().root);
						variables.set("game", g);
						if(d == null)
						{
							variables.set("game_dir", expand_game_dir(g));
						}
						else
						{
							variables.set("game_dir", expand_dlc(g) + "/" + d);
						}
						return FSUtils.expand(get_instance().installers, null, variables);
					}
					public static string expand_bonus(string game, string? dlc=null)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var d = dlc == null ? null : dlc.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.get_instance().root);
						variables.set("game", g);
						if(d == null)
						{
							variables.set("game_dir", expand_game_dir(g));
						}
						else
						{
							variables.set("game_dir", expand_dlc(g) + "/" + d);
						}
						return FSUtils.expand(get_instance().bonus, null, variables);
					}

					public GOG()
					{
						base(ProjectConfig.PROJECT_NAME + ".paths.collection.gog");
					}

					private static GOG? instance;
					public static unowned GOG get_instance()
					{
						if(instance == null)
						{
							instance = new GOG();
						}
						return instance;
					}
				}

				public class Humble: Granite.Services.Settings
				{
					public string game_dir { get; set; }
					public string installers { get; set; }

					public static string expand_game_dir(string game)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.get_instance().root);
						variables.set("game", g);
						return FSUtils.expand(get_instance().game_dir, null, variables);
					}
					public static string expand_installers(string game)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.get_instance().root);
						variables.set("game", g);
						variables.set("game_dir", expand_game_dir(g));
						return FSUtils.expand(get_instance().installers, null, variables);
					}

					public Humble()
					{
						base(ProjectConfig.PROJECT_NAME + ".paths.collection.humble");
					}

					private static Humble? instance;
					public static unowned Humble get_instance()
					{
						if(instance == null)
						{
							instance = new Humble();
						}
						return instance;
					}
				}
			}
		}

		public static string? expand(string? path, string? file=null, HashMap<string, string>? variables=null)
		{
			if(path == null) return null;
			var expanded_path = path;
			if(variables != null)
			{
				foreach(var v in variables.entries)
				{
					expanded_path = expanded_path.replace("${" + v.key + "}", v.value).replace("$" + v.key, v.value);
				}
			}
			return expanded_path.replace("~/.cache", Environment.get_user_cache_dir()).replace("~", Environment.get_home_dir()) + (file != null && file != "" ? "/" + file : "");
		}

		public static File? file(string? path, string? file=null, HashMap<string, string>? variables=null)
		{
			var f = FSUtils.expand(path, file, variables);
			return f != null ? File.new_for_path(f) : null;
		}

		public static File? mkdir(string? path, string? file=null, HashMap<string, string>? variables=null)
		{
			try
			{
				var dir = FSUtils.file(path, file, variables);
				if(dir == null || !dir.query_exists()) dir.make_directory_with_parents();
				return dir;
			}
			catch(Error e)
			{
				warning(e.message);
			}
			return null;
		}

		public static void rm(string path, string? file=null, string flags="-f", HashMap<string, string>? variables=null)
		{
			Utils.run({"bash", "-c", "rm " + flags + " " + FSUtils.expand(path, file, variables)});
		}

		public static void make_dirs()
		{
			mkdir(FSUtils.Paths.Cache.Home);
			mkdir(FSUtils.Paths.Cache.Images);

			#if FLATPAK
			var paths = Paths.Settings.get_instance();
			if(paths.steam_home == paths.schema.get_default_value("steam-home").get_string())
			{
				paths.steam_home = "/home/" + Environment.get_user_name() + "/.var/app/com.valvesoftware.Steam/.steam";
			}
			if(paths.gog_games == paths.schema.get_default_value("gog-games").get_string())
			{
				paths.gog_games = Environment.get_user_data_dir() + "/games/GOG";
			}
			if(paths.humble_games == paths.schema.get_default_value("humble-games").get_string())
			{
				paths.humble_games = Environment.get_user_data_dir() + "/games/HumbleBundle";
			}
			#endif

			FSUtils.rm(FSUtils.Paths.Collection.GOG.expand_installers("*"), ".goutputstream-*");
			FSUtils.rm(FSUtils.Paths.Collection.Humble.expand_installers("*"), ".goutputstream-*");
		}
	}
}
