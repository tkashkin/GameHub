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

using GameHub.Utils;

namespace GameHub.Data.Runnables
{
	public abstract class Runnable: BaseObject
	{
		// General properties

		public string id { get; protected set; }
		public virtual string full_id { owned get { return id; } }

		private string _name;
		public string name_escaped { get; private set; }
		public string name_normalized { get; private set; }
		public string name_without_colons { get; private set; }

		public string name
		{
			get { return _name; }
			set
			{
				_name = value;
				name_escaped = Utils.strip_name(_name.replace(" ", "_"), "_.,");
				name_normalized = Utils.strip_name(_name, null, true);
				name_without_colons = name.replace(": ", " - ").replace(":", "");
			}
		}

		public File? install_dir { owned get; set; default = null; }

		// Run

		public bool is_running { get; set; default = false; }
		public abstract async void run();

		public bool can_be_launched_base(bool is_launch_attempt=false)
		{
			if(Runnable.IsAnyRunnableRunning || Sources.Steam.Steam.IsAnyAppRunning || is_running) return false;
			if(is_launch_attempt)
			{
				lock(Runnable.LastLaunchAttempt)
				{
					var launch_attempt = Runnable.LastLaunchAttempt;
					var now = get_real_time();
					Runnable.LastLaunchAttempt = now;
					if(now - launch_attempt < 1000000) return false;
				}
			}
			return true;
		}

		public virtual bool can_be_launched(bool is_launch_attempt=false)
		{
			return can_be_launched_base(is_launch_attempt);
		}

		// Platforms

		public ArrayList<Platform> platforms { get; protected set; default = new ArrayList<Platform>(); }

		public virtual bool supports_platform(Platform platform)
		{
			return platforms.size == 0 || platforms.contains(platform);
		}

		public virtual bool is_native
		{
			get { return supports_platform(Platform.CURRENT); }
		}

		// General methods

		public HashMap<string, string> get_variables_base()
		{
			var variables = new HashMap<string, string>();
			variables.set("name_escaped", name_escaped);
			variables.set("name", name);
			if(install_dir != null && install_dir.query_exists()) variables.set("install_dir", install_dir.get_path());
			return variables;
		}

		public virtual HashMap<string, string> get_variables()
		{
			return get_variables_base();
		}

		public File?[] get_file_search_paths_base()
		{
			return { install_dir };
		}

		public virtual File?[] get_file_search_paths()
		{
			return get_file_search_paths_base();
		}

		public File? get_file(string? path, bool should_exist=true)
		{
			if(path == null || path.length == 0 || install_dir == null) return null;
			var full_path = path;
			if(!full_path.has_prefix("/") && !full_path.has_prefix("${install_dir}/") && !full_path.has_prefix("$install_dir/"))
			{
				full_path = "${install_dir}/%s".printf(full_path);
			}
			var variables = get_variables();
			var dirs = get_file_search_paths();
			foreach(var dir in dirs)
			{
				if(dir == null) continue;
				variables.set("install_dir", dir.get_path());
				var file = FS.file(full_path, null, variables);
				if(file != null && (!should_exist || file.query_exists()))
				{
					return file;
				}
			}
			return null;
		}

		public virtual void update_status(){}
		public virtual void save(){}

		// Static functions

		public static bool is_equal(Runnable first, Runnable second)
		{
			return first == second || first.full_id == second.full_id;
		}

		public static uint hash(Runnable runnable)
		{
			return str_hash(runnable.full_id);
		}

		// Static variables

		public static bool IsAnyRunnableRunning = false;
		public static int64 LastLaunchAttempt = 0;
	}
}
