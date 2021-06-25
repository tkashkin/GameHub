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

using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;
using GameHub.Data.Runnables.Tasks.Run;

using GameHub.Data.Sources.Steam;

namespace GameHub.Data.Compat.Tools.Wine
{
	public class Wine: CompatTool, CompatToolTraits.Run, CompatToolTraits.Install
	{
		public File? wineserver_executable { protected get; protected construct set; }

		public Wine(File wine, File? wineserver = null, string? name = null)
		{
			var _name = name;
			if(_name == null)
			{
				_name = wine.get_basename();
				if(wine.get_parent().get_basename() == "bin")
				{
					_name = wine.get_parent().get_parent().get_basename();
				}
			}
			Object(
				tool: "wine",
				id: Utils.md5(wine.get_path()),
				name: _name ?? "Wine",
				icon: "tool-wine-symbolic",
				executable: wine,
				wineserver_executable: wineserver
			);
		}

		public Wine.from_db(Sqlite.Statement s)
		{
			File? wineserver_executable = null;

			var info = DB.Tables.CompatTools.INFO.get(s);
			var info_node = Parser.parse_json(info);
			if(info_node != null && info_node.get_node_type() == Json.NodeType.OBJECT)
			{
				var info_obj = info_node.get_object();
				if(info_obj.has_member("wineserver"))
				{
					wineserver_executable = FS.file(info_obj.get_string_member("wineserver"));
				}
			}

			Object(
				tool: "wine",
				id: DB.Tables.CompatTools.ID.get(s),
				name: DB.Tables.CompatTools.NAME.get(s),
				icon: "tool-wine-symbolic",
				executable: FS.file(DB.Tables.CompatTools.EXECUTABLE.get(s)),
				wineserver_executable: wineserver_executable,
				info: info,
				options: DB.Tables.CompatTools.OPTIONS.get(s)
			);
		}

		construct
		{
			version = Utils.replace_prefix(Utils.exec({executable.get_path(), "--version"}).log(false).sync(true).output, "wine-", "").strip();
		}

		public bool can_install(Traits.SupportsCompatTools runnable, InstallTask? task = null)
		{
			return can_run(runnable);
		}

		public bool can_run(Traits.SupportsCompatTools runnable)
		{
			return ((runnable is Game && (runnable is GameHub.Data.Sources.User.UserGame || Platform.WINDOWS in runnable.platforms))/* || runnable is Emulator*/);
		}

		/*public override bool can_run_action(Traits.SupportsCompatTools runnable, Traits.HasActions.Action action)
		{
			return installed && runnable != null && action != null;
		}*/

		protected virtual async string[] prepare_installer_args(Traits.SupportsCompatTools runnable, InstallTask task)
		{
			string[] args = {};

			if(runnable is Sources.GOG.GOGGame)
			{
				var tmp_root = "_gamehub_install_root";
				var win_path = yield convert_path(runnable, task.install_dir.get_child(tmp_root));
				var log_win_path = yield convert_path(runnable, task.install_dir.get_child("install.log"));
				args = { "/SP-", "/NOCANCEL", "/NOGUI", "/NOICONS", @"/DIR=$(win_path)", @"/LOG=$(log_win_path)" };
			}

			return args;
		}

		public async void install(Traits.SupportsCompatTools runnable, InstallTask task, File installer)
		{
			if(!can_install(runnable, task) || (yield InstallerType.guess(installer)) != InstallerType.WINDOWS_EXECUTABLE) return;
			var wine_options = get_options(runnable);
			yield wineboot(runnable, null, wine_options);
			yield exec(runnable, installer, installer.get_parent(), yield prepare_installer_args(runnable, task), wine_options);

			var tmp_root = "_gamehub_install_root";
			if(task.install_dir != null && task.install_dir.get_child(tmp_root).query_exists())
			{
				FS.mv_up(task.install_dir, tmp_root);
			}
		}

		public async void run(Traits.SupportsCompatTools runnable)
		{
			if(!can_run(runnable)) return;
			var wine_options = get_options(runnable);
			yield wineboot(runnable, null, wine_options);
			yield exec(runnable, runnable.executable, null, null, wine_options);
		}

		/*public override async void run_action(Traits.SupportsCompatTools runnable, Traits.HasActions.Action action)
		{
			if(!can_run_action(runnable, action)) return;
			yield wineboot(runnable);
			yield exec(runnable, action.file, action.workdir, Utils.parse_args(action.args));
		}*/

		/*public override async void run_emulator(Emulator emu, Game? game, bool launch_in_game_dir=false)
		{
			if(!can_run(emu)) return;
			var dir = game != null && launch_in_game_dir ? game.work_dir : emu.work_dir;
			yield exec(emu, emu.executable, dir, emu.get_args(game));
		}*/

		protected virtual string[] get_exec_cmdline_base()
		{
			return { executable.get_path() };
		}

		protected virtual string[] prepare_exec_cmdline(Traits.SupportsCompatTools runnable, File file, WineOptions wine_options)
		{
			string[] cmd = get_exec_cmdline_base();
			if(wine_options.desktop.enabled)
			{
				cmd += "c:\\windows\\system32\\explorer.exe";
				cmd += @"/desktop=$(runnable.name_escaped),$(wine_options.desktop.width)x$(wine_options.desktop.height)";
			}
			if(file.get_path().down().has_suffix(".msi"))
			{
				cmd += "msiexec";
				cmd += "/i";
			}
			cmd += file.get_path();
			return cmd;
		}

		protected virtual async void exec(Traits.SupportsCompatTools runnable, File file, File? dir = null, string[]? args = null, WineOptions? wine_options = null)
		{
			var wine_options_local = wine_options ?? get_options(runnable);
			var task = runnable.prepare_exec_task(prepare_exec_cmdline(runnable, file, wine_options), args);
			if(dir != null) task.dir(dir.get_path());
			apply_env(runnable, task, wine_options_local);
			yield task.sync_thread();
		}

		public virtual File? get_prefix(Traits.SupportsCompatTools runnable, WineOptions? wine_options = null)
		{
			var wine_options_local = wine_options ?? get_options(runnable);

			var variables = new HashMap<string, string>();
			variables.set("compat_shared", FS.Paths.Cache.SharedCompat);
			variables.set("tool_type", tool);
			variables.set("tool_id", id);
			variables.set("tool_version", version ?? "null");
			variables.set("install_dir", runnable.install_dir.get_path());
			variables.set("id", runnable.id);
			variables.set("compat", @"$(FS.GAMEHUB_DIR)/$(FS.COMPAT_DATA_DIR)");

			var prefix = FS.file(wine_options_local.prefix.path, null, variables);
			if(prefix != null)
			{
				if(!prefix.query_exists())
				{
					try
					{
						prefix.make_directory_with_parents();
					}
					catch(Error e)
					{
						warning("[Wine.get_prefix] Failed to create prefix `%s`: %s", prefix.get_path(), e.message);
					}
				}
			}
			return prefix;
		}

		public WineOptions get_options(Traits.SupportsCompatTools runnable)
		{
			return new WineOptions.from_json(runnable.get_compat_settings(this) ?? Parser.parse_json(options));
		}

		protected virtual void apply_env(Traits.SupportsCompatTools runnable, ExecTask task, WineOptions? wine_options = null)
		{
			var wine_options_local = wine_options ?? get_options(runnable);

			var dlloverrides = "winemenubuilder.exe=d";
			if(!wine_options_local.libraries.gecko)
				dlloverrides += ";mshtml=d";
			if(!wine_options_local.libraries.mono)
				dlloverrides += ";mscoree=d";

			task.env_var("WINEDLLOVERRIDES", dlloverrides);

			if(executable != null)
			{
				task.env_var("WINE", executable.get_path());
				task.env_var("WINELOADER", executable.get_path());
				if(wineserver_executable != null)
				{
					task.env_var("WINESERVER", wineserver_executable.get_path());
				}
			}

			var prefix = get_prefix(runnable, wine_options_local);
			if(prefix != null)
			{
				task.env_var("WINEPREFIX", prefix.get_path());
			}
		}

		protected virtual async void wineboot(Traits.SupportsCompatTools runnable, string[]? args = null, WineOptions? wine_options = null)
		{
			yield wineutil(runnable, "wineboot", args, wine_options);
		}

		protected async void wineutil(Traits.SupportsCompatTools runnable, string util = "winecfg", string[]? args = null, WineOptions? wine_options = null)
		{
			string[] cmd = { executable.get_path(), util };
			if(args != null)
			{
				foreach(var arg in args)
				{
					cmd += arg;
				}
			}
			var task = runnable.prepare_exec_task(cmd, args);
			task.dir(runnable.install_dir.get_path());
			apply_env(runnable, task, wine_options);
			yield task.sync_thread();
		}

		protected async void winetricks(Traits.SupportsCompatTools runnable, WineOptions? wine_options = null)
		{
			var task = Utils.exec({"winetricks"}).dir(runnable.install_dir.get_path());
			apply_env(runnable, task, wine_options);
			yield task.sync_thread();
		}

		protected virtual async string convert_path(Traits.SupportsCompatTools runnable, File path, WineOptions? wine_options = null)
		{
			var task = Utils.exec({executable.get_path(), "winepath", "-w", path.get_path()}).log(false);
			apply_env(runnable, task, wine_options);
			var win_path = (yield task.sync_thread(true)).output.strip();
			debug("[Wine.convert_path] '%s' -> '%s'", path.get_path(), win_path);
			return win_path;
		}

		public override void save()
		{
			Utils.thread("Wine.save", () => {
				var info_node = new Json.Node(Json.NodeType.OBJECT);
				var info_obj = new Json.Object();

				if(wineserver_executable != null && wineserver_executable.query_exists())
				{
					info_obj.set_string_member("wineserver", wineserver_executable.get_path());
				}

				info_node.set_object(info_obj);
				info = Json.to_string(info_node, false);

				DB.Tables.CompatTools.add(this);
			});
		}

		private const string[] WINE_VERSION_SUFFIXES = {"", "-development", "-devel", "-stable", "-staging"};
		private const string[] WINE_BINARIES = {"wine"};
		private const string[] WINE_OPT_PATHS = {"/opt/wine%s/bin/wine"};
		private const string[] WINE_EXTRA_PATHS = {"~/.local/share/lutris/runners/wine"};

		private static ArrayList<Wine>? wine_versions = null;

		public static ArrayList<Wine> detect()
		{
			if(wine_versions != null) return wine_versions;

			wine_versions = new ArrayList<Wine>();

			var db_versions = (ArrayList<Wine>) DB.Tables.CompatTools.get_all("wine");
			if(db_versions != null)
			{
				foreach(var wine in db_versions)
				{
					add_wine_version(wine);
				}
			}

			foreach(var suffix in WINE_VERSION_SUFFIXES)
			{
				foreach(var binary in WINE_BINARIES)
				{
					var wine = Utils.find_executable("%s%s".printf(binary, suffix));
					if(wine != null)
					{
						var wineserver = wine.get_parent().get_child("wineserver%s".printf(suffix));
						add_wine_version_from_file(wine, wineserver, @"Wine$(suffix)");
					}
				}

				foreach(var opt_path in WINE_OPT_PATHS)
				{
					var wine = Utils.find_executable(opt_path.printf(suffix));
					if(wine != null)
					{
						var wineserver = wine.get_parent().get_child("wineserver");
						add_wine_version_from_file(wine, wineserver, @"Wine$(suffix)");
					}
				}
			}

			foreach(var extra_path in WINE_EXTRA_PATHS)
			{
				var extra_dir = FS.file(extra_path);
				if(extra_dir != null && extra_dir.query_exists())
				{
					try
					{
						FileInfo? finfo = null;
						var enumerator = extra_dir.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
						while((finfo = enumerator.next_file()) != null)
						{
							var dir = extra_dir.get_child(finfo.get_name());
							var wine = dir.get_child("bin").get_child("wine");
							if(wine != null && wine.query_exists())
							{
								var wineserver = wine.get_parent().get_child("wineserver");
								add_wine_version_from_file(wine, wineserver, finfo.get_name());
							}
						}
					}
					catch(Error e)
					{
						warning("[Wine.detect] %s", e.message);
					}
				}
			}

			return wine_versions;
		}

		public static bool is_wine_version_added(File wine)
		{
			foreach(var existing_version in wine_versions)
			{
				if(existing_version.executable.equal(wine)) return true;
			}
			return false;
		}

		public static void add_wine_version(Wine wine)
		{
			if(!is_wine_version_added(wine.executable))
			{
				wine_versions.add(wine);
				Compat.add_tool(wine);
			}
		}

		public static void add_wine_version_from_file(File wine, File? wineserver, string? name = null)
		{
			if(!is_wine_version_added(wine))
			{
				var new_wine = new Wine(wine, wineserver, name);
				new_wine.save();
				wine_versions.add(new_wine);
				Compat.add_tool(new_wine);
			}
		}
	}
}
