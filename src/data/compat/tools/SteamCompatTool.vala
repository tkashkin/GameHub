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

using GameHub.Data.Compat.Tools.Wine;

namespace GameHub.Data.Compat.Tools
{
	public class SteamCompatTool: CompatTool, CompatToolTraits.Run
	{
		public File? directory { protected get; protected construct set; }

		public SteamCompatTool(File directory, string? name = null)
		{
			var _name = name;
			if(_name == null)
			{
				_name = directory.get_basename();
			}
			var executable_name = _name;
			var run_cmd = get_run_command(directory);
			if(run_cmd != null && run_cmd.length > 0)
			{
				executable_name = Utils.replace_prefix(run_cmd[0], "/", "");
			}
			var executable = directory.get_child(executable_name);
			Object(
				tool: "steamct",
				id: Utils.md5(executable.get_path()),
				name: _name,
				icon: "source-steam-symbolic",
				directory: directory,
				executable: executable
			);
		}

		public SteamCompatTool.from_db(Sqlite.Statement s)
		{
			File? directory = null;

			var info = DB.Tables.CompatTools.INFO.get(s);
			var info_node = Parser.parse_json(info);
			if(info_node != null && info_node.get_node_type() == Json.NodeType.OBJECT)
			{
				var info_obj = info_node.get_object();
				if(info_obj.has_member("directory"))
				{
					directory = FS.file(info_obj.get_string_member("directory"));
				}
			}

			Object(
				tool: "steamct",
				id: DB.Tables.CompatTools.ID.get(s),
				name: DB.Tables.CompatTools.NAME.get(s),
				icon: "source-steam-symbolic",
				directory: directory,
				executable: FS.file(DB.Tables.CompatTools.EXECUTABLE.get(s)),
				info: DB.Tables.CompatTools.INFO.get(s),
				options: DB.Tables.CompatTools.OPTIONS.get(s)
			);
		}

		public bool can_run(Traits.SupportsCompatTools runnable)
		{
			return runnable is Game;
		}

		public async void run(Traits.SupportsCompatTools runnable)
		{
			if(!can_run(runnable)) return;

			var dir = directory ?? executable.get_parent();
			var run_cmd = get_run_command(dir);

			string[] cmd = {};
			foreach(var arg in run_cmd)
			{
				if(cmd.length == 0)
				{
					cmd += dir.get_path() + arg;
				}
				else
				{
					cmd += arg;
				}
			}
			cmd += runnable.executable.get_path();

			var task = runnable.prepare_exec_task(cmd);

			runnable.cast<Sources.GOG.GOGGame>(game => task.env_var("GOG_GAME_ID", game.id));

			yield task.sync_thread();
		}

		private static string[]? get_run_command(File directory)
		{
			var root_node = Parser.parse_vdf_file(directory.get_path(), "toolmanifest.vdf");
			var manifest = Parser.json_object(root_node, {"manifest"});
			if(manifest != null)
			{
				return manifest.get_string_member("commandline").split(" ");
			}
			return null;
		}

		construct
		{
			try
			{
				string? _version = null;
				if(FileUtils.get_contents(executable.get_parent().get_child("version").get_path(), out _version))
				{
					version = _version.strip();
				}
			}
			catch(Error e)
			{
				warning("[SteamCompatTool.construct] Failed to get version: %s", e.message);
			}
		}

		public override void save()
		{
			Utils.thread("SteamCompatTool.save", () => {
				var info_node = new Json.Node(Json.NodeType.OBJECT);
				var info_obj = new Json.Object();

				if(directory != null && directory.query_exists())
				{
					info_obj.set_string_member("directory", directory.get_path());
				}

				info_node.set_object(info_obj);
				info = Json.to_string(info_node, false);

				DB.Tables.CompatTools.add(this);
			});
		}

		private const string[] STEAM_COMPATTOOLS_PATHS = {"~/.local/share/Steam/compatibilitytools.d"};

		private static ArrayList<SteamCompatTool>? steamct_tools = null;

		public static ArrayList<SteamCompatTool> detect()
		{
			if(steamct_tools != null) return steamct_tools;

			steamct_tools = new ArrayList<SteamCompatTool>();

			var db_tools = (ArrayList<SteamCompatTool>) DB.Tables.CompatTools.get_all("steamct");
			if(db_tools != null)
			{
				foreach(var tool in db_tools)
				{
					add_tool(tool);
				}
			}

			foreach(var path in STEAM_COMPATTOOLS_PATHS)
			{
				var compattools_dir = FS.file(path);
				if(compattools_dir != null && compattools_dir.query_exists())
				{
					try
					{
						FileInfo? finfo = null;
						var enumerator = compattools_dir.enumerate_children("standard::*", FileQueryInfoFlags.NONE);
						while((finfo = enumerator.next_file()) != null)
						{
							var dir = compattools_dir.get_child(finfo.get_name());
							var toolmanifest = dir.get_child("toolmanifest.vdf");
							if(toolmanifest != null && toolmanifest.query_exists())
							{
								add_tool_from_directory(dir);
							}
						}
					}
					catch(Error e)
					{
						warning("[SteamCompatTool.detect] %s", e.message);
					}
				}
			}

			return steamct_tools;
		}

		public static bool is_tool_added(File directory)
		{
			foreach(var existing_tool in steamct_tools)
			{
				if(existing_tool.directory.equal(directory)) return true;
			}
			return false;
		}

		public static void add_tool(SteamCompatTool tool)
		{
			if(!is_tool_added(tool.directory))
			{
				steamct_tools.add(tool);
				Compat.add_tool(tool);
			}
		}

		public static void add_tool_from_directory(File directory, string? name = null)
		{
			if(!is_tool_added(directory))
			{
				var proton_executable = directory.get_child("proton");
				if(proton_executable != null && proton_executable.query_exists())
				{
					Proton.Proton.add_proton_version_from_file(proton_executable);
				}
				else
				{
					var new_tool = new SteamCompatTool(directory, name);
					new_tool.save();
					steamct_tools.add(new_tool);
					Compat.add_tool(new_tool);
				}
			}
		}
	}
}
