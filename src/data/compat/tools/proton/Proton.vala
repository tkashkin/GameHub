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

using GameHub.Utils;

using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;
using GameHub.Data.Runnables.Tasks.Run;

using GameHub.Data.Sources.Steam;

using GameHub.Data.Compat.Tools.Wine;

namespace GameHub.Data.Compat.Tools.Proton
{
	public class Proton: Tools.Wine.Wine
	{
		public Proton(File proton, string? name = null)
		{
			var _name = name;
			if(_name == null)
			{
				_name = proton.get_parent().get_basename();
			}
			Object(
				tool: "proton",
				id: Utils.md5(proton.get_path()),
				name: _name ?? "Proton",
				icon: "source-steam-symbolic",
				executable: proton
			);
		}

		public Proton.from_db(Sqlite.Statement s)
		{
			Object(
				tool: "proton",
				id: DB.Tables.CompatTools.ID.get(s),
				name: DB.Tables.CompatTools.NAME.get(s),
				icon: "source-steam-symbolic",
				executable: FS.file(DB.Tables.CompatTools.EXECUTABLE.get(s)),
				info: DB.Tables.CompatTools.INFO.get(s),
				options: DB.Tables.CompatTools.OPTIONS.get(s)
			);
		}

		construct
		{
			try
			{
				string? _version = null;
				if(FileUtils.get_contents(executable.get_parent().get_child("version").get_path(), out _version))
				{
					version = _version.strip();
					if(" " in version)
					{
						version = Utils.replace_prefix(version.split(" ", 2)[1], "proton-", "").strip();
					}
				}
			}
			catch(Error e)
			{
				warning("[Proton.construct] Failed to get version: %s", e.message);
			}
		}

		protected override string[] get_exec_cmdline_base()
		{
			return { executable.get_path(), "run" };
		}

		protected override void apply_env(Traits.SupportsCompatTools runnable, ExecTask task, WineOptions? wine_options = null)
		{
			var wine_options_local = wine_options ?? get_options(runnable);
			base.apply_env(runnable, task, wine_options_local);

			// unset Wine variables to let Proton set them
			task.env_var("WINE", null);
			task.env_var("WINELOADER", null);
			task.env_var("WINESERVER", null);

			var prefix = get_prefix(runnable, wine_options_local);
			if(prefix != null)
			{
				task.env_var("STEAM_COMPAT_DATA_PATH", prefix.get_path());
				task.env_var("WINEPREFIX", prefix.get_child("pfx").get_path());
			}

			task.env_var("STEAM_COMPAT_CLIENT_INSTALL_PATH", Steam.instance.steam_client_install_dir.get_path());
			task.env_var("PROTON_LOG", "1");
		}

		protected override async void wineboot(Traits.SupportsCompatTools runnable, string[]? args = null, WineOptions? wine_options = null)
		{
			if(args == null)
			{
				yield proton_init_prefix(runnable, wine_options);
			}
			yield wineutil(runnable, "wineboot", args, wine_options);
		}

		private async void proton_init_prefix(Traits.SupportsCompatTools runnable, WineOptions? wine_options = null)
		{
			var wine_options_local = wine_options ?? get_options(runnable);
			var prefix = get_prefix(runnable, wine_options_local);
			var cmd = prefix.get_child("pfx/drive_c/windows/system32/cmd.exe");
			if(!cmd.query_exists())
			{
				var cmd_task = Utils.exec({executable.get_path(), "run", cmd.get_path(), "/c", "exit"});
				apply_env(runnable, cmd_task, wine_options_local);
				yield cmd_task.sync_thread(true);
			}
		}

		protected override async string convert_path(Traits.SupportsCompatTools runnable, File path, WineOptions? wine_options = null)
		{
			var task = Utils.exec({executable.get_path(), "getcompatpath", path.get_path()}).log(false);
			apply_env(runnable, task, wine_options);
			var win_path = (yield task.sync_thread(true)).output.strip();
			debug("[Wine.convert_path] '%s' -> '%s'", path.get_path(), win_path);
			return win_path;
		}

		public override void save()
		{
			Utils.thread("Proton.save", () => {
				DB.Tables.CompatTools.add(this);
			});
		}

		private static ArrayList<Proton>? proton_versions = null;
		private static HashMap<string, string>? proton_appids = null;

		public static new ArrayList<Proton> detect()
		{
			if(proton_versions != null) return proton_versions;

			proton_versions = new ArrayList<Proton>();
			proton_appids = new HashMap<string, string>();

			var db_versions = (ArrayList<Proton>) DB.Tables.CompatTools.get_all("proton");
			if(db_versions != null)
			{
				foreach(var proton in db_versions)
				{
					add_proton_version(proton);
				}
			}

			if(Steam.instance != null)
			{
				Steam.instance.load_appinfo();
				if(Steam.instance.appinfo != null)
				{
					foreach(var app_node in Steam.instance.appinfo.nodes.values)
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

									if(type != null && type.down() == "tool" && name != null && name.down().has_prefix("proton "))
									{
										add_proton_version_from_appid(app.key, name);
									}
								}
							}
						}
					}
				}
			}

			return proton_versions;
		}

		public static HashMap<string, string>? get_appids()
		{
			return proton_appids;
		}

		public static bool is_proton_version_added(File proton)
		{
			foreach(var existing_version in proton_versions)
			{
				if(existing_version.executable.equal(proton)) return true;
			}
			return false;
		}

		public static void add_proton_version(Proton proton)
		{
			if(!is_proton_version_added(proton.executable))
			{
				proton_versions.add(proton);
				Compat.add_tool(proton);
			}
		}

		public static void add_proton_version_from_file(File proton, string? name = null)
		{
			if(!is_proton_version_added(proton))
			{
				var new_proton = new Proton(proton, name);
				new_proton.save();
				proton_versions.add(new_proton);
				Compat.add_tool(new_proton);
			}
		}

		public static void add_proton_version_from_appid(string appid, string? name = null)
		{
			File? proton_dir = null;
			if(Steam.find_app_install_dir(appid, out proton_dir))
			{
				add_proton_version_from_file(proton_dir.get_child("proton"), name);
			}
			else
			{
				proton_appids.set(appid, name ?? @"Proton (app $(appid))");
			}
		}
	}
}
