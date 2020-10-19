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

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Data.Runnables;
using GameHub.Utils;

namespace GameHub.Data.Runnables.Traits
{
	public interface HasExecutableFile: Runnable
	{
		public abstract string? executable_path { owned get; set; }
		public abstract string? work_dir_path { owned get; set; }
		public abstract string? arguments { owned get; set; }
		public abstract string? environment { owned get; set; }

		public File? executable
		{
			owned get
			{
				if(executable_path == null || executable_path.length == 0 || install_dir == null) return null;
				return get_file(executable_path);
			}
			set
			{
				if(value != null && value.query_exists() && install_dir != null && install_dir.query_exists())
				{
					var dirs = get_file_search_paths();
					foreach(var dir in dirs)
					{
						if(dir != null && value.get_path().has_prefix(dir.get_path()))
						{
							executable_path = value.get_path().replace(dir.get_path(), "${install_dir}");
							break;
						}
					}
				}
				else
				{
					executable_path = null;
				}
				save();
			}
		}

		public File? work_dir
		{
			owned get
			{
				if(install_dir == null) return null;
				if(work_dir_path == null || work_dir_path.length == 0) return install_dir;
				return get_file(work_dir_path);
			}
			set
			{
				if(value != null && value.query_exists() && install_dir != null && install_dir.query_exists())
				{
					var dirs = get_file_search_paths();
					foreach(var dir in dirs)
					{
						if(dir != null && value.get_path().has_prefix(dir.get_path()))
						{
							work_dir_path = value.get_path().replace(dir.get_path(), "${install_dir}");
							break;
						}
					}
				}
				else
				{
					work_dir_path = null;
				}
				save();
			}
		}

		public bool is_executable_not_native
		{
			get
			{
				#if !OS_WINDOWS
				return executable != null && executable.get_basename().down().has_suffix(".exe");
				#else
				return false;
				#endif
			}
		}

		protected void dbinit_executable(Sqlite.Statement s)
		{
			executable_path = Tables.Games.EXECUTABLE.get(s);
			work_dir_path = Tables.Games.WORK_DIR.get(s);
			arguments = Tables.Games.ARGUMENTS.get(s);
			environment = Tables.Games.ENVIRONMENT.get(s);
		}

		public bool can_be_launched(bool is_launch_attempt=false)
		{
			return can_be_launched_base(is_launch_attempt) && executable != null && executable.query_exists();
		}

		protected async void run_executable()
		{
			if(!can_be_launched(true)) return;

			Runnable.IsAnyRunnableRunning = is_running = true;
			Inhibitor.inhibit(_("%s is running").printf(name));
			update_status();

			yield pre_run();

			yield prepare_exec_task().sync_thread();

			yield post_run();

			Timeout.add_seconds(1, () => {
				Runnable.IsAnyRunnableRunning = is_running = false;
				Inhibitor.uninhibit();
				update_status();
				return Source.REMOVE;
			});
		}

		protected virtual async void pre_run(){}
		protected virtual async void post_run(){}

		protected virtual string[] cmdline
		{
			owned get { return { executable.get_path() }; }
		}

		public virtual ExecTask prepare_exec_task(string[]? cmdline_override = null, string[]? args_override = null)
		{
			string[] cmd = cmdline_override ?? cmdline;
			string[] full_cmd = cmd;

			var variables = get_variables();
			var args = args_override ?? Utils.parse_args(arguments);
			if(args != null)
			{
				if("$command" in args || "${command}" in args)
				{
					full_cmd = {};
				}
				foreach(var arg in args)
				{
					if(arg == "$command" || arg == "${command}")
					{
						foreach(var a in cmd)
						{
							full_cmd += a;
						}
					}
					else
					{
						if("$" in arg)
						{
							arg = FS.expand(arg, null, variables);
						}
						full_cmd += arg;
					}
				}
			}

			var task = Utils.exec(full_cmd).override_runtime(true).dir(work_dir.get_path());

			cast<Traits.Game.SupportsTweaks>(game => task.tweaks(game.tweaks, game));

			if(environment != null && environment.length > 0)
			{
				var env = Parser.json_object(Parser.parse_json(environment), {});
				if(env != null)
				{
					env.foreach_member((obj, name, node) => {
						task.env_var(name, node.get_string());
					});
				}
			}

			return task;
		}
	}
}
