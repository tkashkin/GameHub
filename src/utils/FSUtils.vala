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
using Gdk;
using GLib;

using GameHub.Data;

namespace GameHub.Utils
{
	public class FSUtils
	{
		public const string GAMEHUB_DIR = "_gamehub";
		public const string COMPAT_DATA_DIR = "compat";
		public const string OVERLAYS_DIR = "overlays";
		public const string OVERLAYS_LIST = "overlays.json";

		public class Paths
		{
			public class Settings: Granite.Services.Settings
			{
				public string steam_home { get; set; }
				public string gog_games { get; set; }
				public string humble_games { get; set; }

				public Settings()
				{
					base(ProjectConfig.PROJECT_NAME + ".paths");
				}

				private static Settings _instance;
				public static Settings instance
				{
					get
					{
						if(_instance == null)
						{
							_instance = new Settings();
						}
						return _instance;
					}
				}
			}

			public class Cache
			{
				public const string Home = "~/.cache/com.github.tkashkin.gamehub";

				public const string Cookies = FSUtils.Paths.Cache.Home + "/cookies";
				public const string Images = FSUtils.Paths.Cache.Home + "/images";

				public const string Database = FSUtils.Paths.Cache.Home + "/gamehub.db";

				public const string Compat = FSUtils.Paths.Cache.Home + "/compat";
				public const string WineWrap = FSUtils.Paths.Cache.Compat + "/winewrap";

				public const string Sources = FSUtils.Paths.Cache.Home + "/sources";
			}

			public class Steam
			{
				public static string Home { owned get { return FSUtils.Paths.Settings.instance.steam_home; } }
				public const string Config = "steam/config";
				public const string LoginUsersVDF = FSUtils.Paths.Steam.Config + "/loginusers.vdf";

				public const string SteamApps = "steam/steamapps";
				public const string LibraryFoldersVDF = "libraryfolders.vdf";

				public const string RegistryVDF = "registry.vdf";
			}

			public class GOG
			{
				public static string Games { owned get { return FSUtils.Paths.Settings.instance.gog_games; } }
			}

			public class Humble
			{
				public static string Games { owned get { return FSUtils.Paths.Settings.instance.humble_games; } }

				public const string Cache = FSUtils.Paths.Cache.Sources + "/humble";
				public static string LoadedOrdersMD5 { owned get { return FSUtils.Paths.Humble.Cache + "/orders.md5"; } }
			}

			public class Collection: Granite.Services.Settings
			{
				public string root { get; set; }

				public static string expand_root()
				{
					return FSUtils.expand(instance.root);
				}

				public Collection()
				{
					base(ProjectConfig.PROJECT_NAME + ".paths.collection");
				}

				private static Collection? _instance;
				public static unowned Collection instance
				{
					get
					{
						if(_instance == null)
						{
							_instance = new Collection();
						}
						return _instance;
					}
				}

				public class GOG: Granite.Services.Settings
				{
					public string game_dir { get; set; }
					public string installers { get; set; }
					public string dlc { get; set; }
					public string bonus { get; set; }

					public static string expand_game_dir(string game, Platform? platform=null)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.instance.root);
						variables.set("game", g);
						variables.set("platform_name", platform == null ? "" : platform.name());
						variables.set("platform", platform == null ? "" : platform.id());
						return FSUtils.expand(instance.game_dir, null, variables);
					}
					public static string expand_dlc(string game, Platform? platform=null)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.instance.root);
						variables.set("platform_name", platform == null ? "." : platform.name());
						variables.set("platform", platform == null ? "." : platform.id());
						variables.set("game_dir", expand_game_dir(g, platform));
						return FSUtils.expand(instance.dlc, null, variables);
					}
					public static string expand_installers(string game, string? dlc=null, Platform? platform=null)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var d = dlc == null ? null : dlc.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.instance.root);
						variables.set("platform_name", platform == null ? "." : platform.name());
						variables.set("platform", platform == null ? "." : platform.id());
						if(d == null)
						{
							variables.set("game_dir", expand_game_dir(g, platform));
						}
						else
						{
							variables.set("game_dir", expand_dlc(g, platform) + "/" + d);
						}
						return FSUtils.expand(instance.installers, null, variables);
					}
					public static string expand_bonus(string game, string? dlc=null)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var d = dlc == null ? null : dlc.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.instance.root);
						if(d == null)
						{
							variables.set("game_dir", expand_game_dir(g));
						}
						else
						{
							variables.set("game_dir", expand_dlc(g) + "/" + d);
						}
						return FSUtils.expand(instance.bonus, null, variables);
					}

					public GOG()
					{
						base(ProjectConfig.PROJECT_NAME + ".paths.collection.gog");
					}

					private static GOG? _instance;
					public static unowned GOG instance
					{
						get
						{
							if(_instance == null)
							{
								_instance = new GOG();
							}
							return _instance;
						}
					}
				}

				public class Humble: Granite.Services.Settings
				{
					public string game_dir { get; set; }
					public string installers { get; set; }

					public static string expand_game_dir(string game, Platform? platform=null)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.instance.root);
						variables.set("game", g);
						variables.set("platform_name", platform == null ? "." : platform.name());
						variables.set("platform", platform == null ? "." : platform.id());
						return FSUtils.expand(instance.game_dir, null, variables);
					}
					public static string expand_installers(string game, Platform? platform=null)
					{
						var g = game.replace(": ", " - ").replace(":", "");
						var variables = new HashMap<string, string>();
						variables.set("root", Collection.instance.root);
						variables.set("platform_name", platform == null ? "." : platform.name());
						variables.set("platform", platform == null ? "." : platform.id());
						variables.set("game_dir", expand_game_dir(g, platform));
						return FSUtils.expand(instance.installers, null, variables);
					}

					public Humble()
					{
						base(ProjectConfig.PROJECT_NAME + ".paths.collection.humble");
					}

					private static Humble? _instance;
					public static unowned Humble instance
					{
						get
						{
							if(_instance == null)
							{
								_instance = new Humble();
							}
							return _instance;
						}
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
			expanded_path = Utils.replace_prefix(expanded_path, "~/.cache", Environment.get_user_cache_dir());
			expanded_path = Utils.replace_prefix(expanded_path, "~", Environment.get_home_dir());
			return expanded_path + (file != null && file != "" ? "/" + file : "");
		}

		public static File? file(string? path, string? file=null, HashMap<string, string>? variables=null)
		{
			var f = FSUtils.expand(path, file, variables);
			return f != null ? File.new_for_path(f) : null;
		}

		public static File? find_case_insensitive(File root, string? path=null, string[]? parts=null)
		{
			if(path == null && parts == null) return null;

			string[]? _parts = parts;

			if(parts == null)
			{
				_parts = path.down().split("/");
			}

			try
			{
				FileInfo? finfo = null;
				var enumerator = root.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
				while((finfo = enumerator.next_file()) != null)
				{
					if(finfo.get_name().down() == _parts[0])
					{
						var child = root.get_child(finfo.get_name());
						if(finfo.get_file_type() == FileType.REGULAR || _parts.length == 1)
						{
							return child;
						}
						else
						{
							var new_parts = new string[]{};
							for(int i = 1; i < _parts.length; i++)
							{
								new_parts += _parts[i];
							}
							var child_file = find_case_insensitive(child, null, new_parts);
							if(child_file != null)
							{
								return child_file;
							}
						}
					}
				}
			}
			catch(Error e)
			{
				warning("[FSUtils.find_case_insensitive] %s", e.message);
			}
			return null;
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
			Utils.run({"bash", "-c", "rm " + flags + " " + FSUtils.expand(path, file, variables).replace(" ", "\\ ") }, null, null, false, false, false);
		}

		public static void mv_up(File? path, string dirname)
		{
			try
			{
				if(path == null || !path.get_child(dirname).query_exists() || path.get_child(dirname).query_file_type(FileQueryInfoFlags.NONE) != FileType.DIRECTORY) return;
				var tmp_dir = path.get_child(dirname).set_display_name(".gh_" + dirname + "_" + Utils.md5(dirname)); // rename source dir in case there's a child with the same name
				FileInfo? finfo = null;
				var enumerator = tmp_dir.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
				while((finfo = enumerator.next_file()) != null)
				{
					var src = tmp_dir.get_child(finfo.get_name());
					var dest = path.get_child(finfo.get_name());
					debug("[FSUtils.mv_up] '%s' -> '%s'", src.get_path(), dest.get_path());
					FSUtils.mv_merge(src, dest);
				}
				tmp_dir.delete();
			}
			catch(Error e)
			{
				warning("[FSUtils.mv_up] %s", e.message);
			}
		}

		public static void mv_merge(File source, File destination)
		{
			try
			{
				source.move(destination, FileCopyFlags.OVERWRITE | FileCopyFlags.NOFOLLOW_SYMLINKS);
			}
			catch(IOError.WOULD_MERGE e)
			{
				FileInfo? finfo = null;
				var enumerator = source.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
				while((finfo = enumerator.next_file()) != null)
				{
					var src = source.get_child(finfo.get_name());
					var dest = destination.get_child(finfo.get_name());
					debug("[FSUtils.mv_merge] '%s' -> '%s'", src.get_path(), dest.get_path());
					FSUtils.mv_merge(src, dest);
				}
				source.delete();
			}
			catch(Error e)
			{
				warning("[FSUtils.mv_merge] %s", e.message);
			}
		}

		public static void make_dirs()
		{
			mkdir(FSUtils.Paths.Cache.Home);
			mkdir(FSUtils.Paths.Cache.Images);
			mkdir(FSUtils.Paths.Humble.Cache);

			#if FLATPAK
			var paths = Paths.Settings.instance;
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
