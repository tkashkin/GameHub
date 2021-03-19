/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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

using GameHub.Data;
using GameHub.Settings;

namespace GameHub.Utils.FS
{
	public const string GAMEHUB_DIR = "_gamehub";
	public const string COMPAT_DATA_DIR = "compat";
	public const string OVERLAYS_DIR = "overlays";
	public const string OVERLAYS_LIST = "overlays.json";

	#if OS_WINDOWS
	public const string DIRECTORY_SEPARATOR = "\\";
	#else
	public const string DIRECTORY_SEPARATOR = "/";
	#endif

	public class Paths
	{
		public class Cache
		{
			public const string Home = "~/.cache/" + GameHub.Config.RDNN;

			public const string Cookies = Paths.Cache.Home + "/cookies";

			public const string Graphics = Paths.Cache.Home + "/graphics";

			public const string Database = Paths.Cache.Home + "/gamehub.db";

			public const string Compat = Paths.Cache.Home + "/compat";
			public const string SharedCompat = Paths.Cache.Compat + "/shared";
			public const string WineWrap = Paths.Cache.Compat + "/winewrap";

			public const string Sources = Paths.Cache.Home + "/sources";
			public const string Providers = Paths.Cache.Home + "/providers";
		}

		public class LocalData
		{
			public const string Home = "~/.local/share/" + GameHub.Config.RDNN;
			public const string Tweaks = Paths.LocalData.Home + "/tweaks";
			public const string DOSBoxConfigs = Paths.LocalData.Home + "/compat/dosbox";
		}

		public class Config
		{
			public const string Home = "~/.config/" + GameHub.Config.RDNN;
			public const string Tweaks = Paths.Config.Home + "/tweaks";
			public const string DOSBoxConfigs = Paths.Config.Home + "/compat/dosbox";
		}

		public class Steam
		{
			public const string[] InstallDirs = {"~/.local/share/Steam", "~/.var/app/com.valvesoftware.Steam/.local/share/Steam"};

			public const string Config = "config";
			public const string LoginUsersVDF = Paths.Steam.Config + "/loginusers.vdf";

			public const string SteamApps = "steamapps";
			public const string LibraryFoldersVDF = "libraryfolders.vdf";

			public const string RegistryVDF = "../../../.steam/registry.vdf";

			public const string AppInfoVDF = "appcache/appinfo.vdf";
			public const string PackageInfoVDF = "appcache/packageinfo.vdf";
		}

		public class EpicGames
		{
			public const string Cache = Paths.Cache.Sources + "/epicgames";
			public const string Manifests = Paths.EpicGames.Cache + "/manifests";
			public const string Metadata = Paths.EpicGames.Cache + "/metadata";
		}

		public class Humble
		{
			public const string Cache = Paths.Cache.Sources + "/humble";
			public const string LoadedOrdersMD5 = Paths.Humble.Cache + "/orders.md5";
		}

		public class Itch
		{
			public const string Database = "db/butler.db";

			public const string Repo = "broth";

			public const string ButlerRoot = Paths.Itch.Repo + "/butler";
			public const string ButlerCurrentVersion = Paths.Itch.ButlerRoot + "/.chosen-version";
			public const string ButlerExecutable = Paths.Itch.ButlerRoot + "/versions/%s/butler";
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
				if(v.key != null && v.value != null)
				{
					expanded_path = expanded_path.replace("${" + v.key + "}", v.value).replace("$" + v.key, v.value);
				}
			}
		}
		#if OS_WINDOWS
		expanded_path = expanded_path.replace("\\", "/");
		#endif
		expanded_path = Utils.replace_prefix(expanded_path, "~/.cache", Environment.get_user_cache_dir());
		expanded_path = Utils.replace_prefix(expanded_path, "~/.local/share", Environment.get_user_data_dir());
		expanded_path = Utils.replace_prefix(expanded_path, "~/.config", Environment.get_user_config_dir());
		expanded_path = Utils.replace_prefix(expanded_path, "~", Environment.get_home_dir());
		expanded_path = expanded_path + (file != null && file != "" ? "/" + file : "");
		#if OS_WINDOWS
		expanded_path = expanded_path.replace("/", "\\");
		#endif
		return expanded_path;
	}

	public static File? file(string? path, string? file=null, HashMap<string, string>? variables=null)
	{
		var f = expand(path, file, variables);
		return f != null ? File.new_for_path(f) : null;
	}

	public static File? find_case_insensitive(File? root, string? path=null, string[]? parts=null)
	{
		if(root == null || (path == null && parts == null)) return null;

		string[]? _parts = parts;

		if(parts == null)
		{
			_parts = path.down().replace(DIRECTORY_SEPARATOR, "/").split("/");
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
						string[] new_parts = {};
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
			warning("[FS.find_case_insensitive] %s", e.message);
		}
		return null;
	}

	public static ArrayList<File> get_data_dirs(string? subdir=null, bool with_nonexistent=false)
	{
		var data_path = subdir != null ? @"$(Config.RDNN)/$(subdir)" : Config.RDNN;

		string[] data_dirs = {};
		var system_data_dirs = Environment.get_system_data_dirs();
		var user_data_dir = Environment.get_user_data_dir();
		var user_config_dir = Environment.get_user_config_dir();

		if(system_data_dirs != null && system_data_dirs.length > 0)
		{
			foreach(var system_data_dir in system_data_dirs)
			{
				var dir = FS.file(system_data_dir, data_path).get_path();
				if(!(dir in data_dirs)) data_dirs += dir;
			}
		}

		var project_data_dir = FS.file(Config.DATADIR, data_path).get_path();
		if(!(project_data_dir in data_dirs)) data_dirs += project_data_dir;

		if(user_data_dir != null && user_data_dir.length > 0)
		{
			var dir = FS.file(user_data_dir, data_path).get_path();
			if(!(dir in data_dirs)) data_dirs += dir;
		}

		if(user_config_dir != null && user_config_dir.length > 0)
		{
			var dir = FS.file(user_config_dir, data_path).get_path();
			if(!(dir in data_dirs)) data_dirs += dir;
		}

		var dirs = new ArrayList<File>();

		foreach(var d in data_dirs)
		{
			var dir = FS.file(d);
			if(dir != null && (with_nonexistent || dir.query_exists()))
			{
				dirs.add(dir);
			}
		}

		return dirs;
	}

	public static File? mkdir(string? path, string? file=null, HashMap<string, string>? variables=null)
	{
		try
		{
			var dir = FS.file(path, file, variables);
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
		Utils.exec({"bash", "-c", "rm " + flags + " " + expand(path, file, variables).replace(" ", "\\ ")}).sync();
	}

	public static void mv_up(File? path, string dirname)
	{
		try
		{
			if(path == null || !path.get_child(dirname).query_exists() || path.get_child(dirname).query_file_type(FileQueryInfoFlags.NONE) != FileType.DIRECTORY) return;
			var tmp_dir = path.get_child(dirname).set_display_name(".gh_tmpdir_" + Utils.md5(dirname)); // rename source dir in case there's a child with the same name
			FileInfo? finfo = null;
			var enumerator = tmp_dir.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
			while((finfo = enumerator.next_file()) != null)
			{
				var src = tmp_dir.get_child(finfo.get_name());
				var dest = path.get_child(finfo.get_name());
				debug("[FS.mv_up] '%s' -> '%s'", src.get_path(), dest.get_path());
				mv_merge(src, dest);
			}
			tmp_dir.delete();
		}
		catch(Error e)
		{
			warning("[FS.mv_up] %s", e.message);
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
			try
			{
				FileInfo? finfo = null;
				var enumerator = source.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
				while((finfo = enumerator.next_file()) != null)
				{
					var src = source.get_child(finfo.get_name());
					var dest = destination.get_child(finfo.get_name());
					debug("[FS.mv_merge] '%s' -> '%s'", src.get_path(), dest.get_path());
					mv_merge(src, dest);
				}
				source.delete();
			}
			catch(Error e)
			{
				warning("[FS.mv_merge] %s", e.message);
			}
		}
		catch(Error e)
		{
			warning("[FS.mv_merge] %s", e.message);
		}
	}

	public static void make_dirs()
	{
		FS.mkdir(Paths.Cache.Home);
		FS.mkdir(Paths.Cache.Graphics);
		FS.mkdir(Paths.Humble.Cache);

		FS.mkdir(Paths.LocalData.Home);
		FS.mkdir(Paths.LocalData.Tweaks);
		FS.mkdir(Paths.LocalData.DOSBoxConfigs);

		FS.mkdir(Paths.Config.Home);
		FS.mkdir(Paths.Config.Tweaks);
		FS.mkdir(Paths.Config.DOSBoxConfigs);
	}
}
