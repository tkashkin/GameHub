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

using GameHub.Utils;

namespace GameHub.Data.Compat
{
	public class DOSBox: CompatTool
	{
		private static string[] DOSBOX_WIN_EXECUTABLE_NAMES = {"DOSBox", "dosbox", "DOSBOX"};
		private static string[] DOSBOX_WIN_EXECUTABLE_EXTENSIONS = {".exe", ".EXE"};

		public string binary { get; construct; default = "dosbox"; }

		private File conf_windowed;
		private CompatTool.BoolOption? opt_windowed;

		public DOSBox(string binary="dosbox")
		{
			Object(binary: binary);
		}

		construct
		{
			id = @"dosbox";
			name = @"DOSBox";
			icon = "tool-dosbox-symbolic";

			executable = Utils.find_executable(binary);
			installed = executable != null && executable.query_exists();

			conf_windowed = FSUtils.file(ProjectConfig.DATADIR + "/" + ProjectConfig.PROJECT_NAME, "compat/dosbox/windowed.conf");
			if(conf_windowed.query_exists())
			{
				opt_windowed = new CompatTool.BoolOption(_("Windowed"), _("Disable fullscreen"), true);
				options = { opt_windowed };
			}
		}

		private static ArrayList<string> find_configs(File? dir)
		{
			var configs = new ArrayList<string>();

			if(dir == null || !dir.query_exists())
			{
				return configs;
			}

			try
			{
				FileInfo? finfo = null;
				var enumerator = dir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				while((finfo = enumerator.next_file()) != null)
				{
					var fname = finfo.get_name();
					if(fname.has_suffix(".conf"))
					{
						configs.add(dir.get_child(fname).get_path());
					}
				}
			}
			catch(Error e)
			{
				warning("[DOSBox.find_configs] %s", e.message);
			}

			return configs;
		}

		public override bool can_run(Runnable runnable)
		{
			return installed && runnable is Game && find_configs(runnable.install_dir).size > 0;
		}

		public override async void run(Runnable runnable)
		{
			if(!can_run(runnable)) return;

			string[] cmd = { executable.get_path() };

			var wdir = runnable.install_dir;

			var configs = find_configs(runnable.install_dir);

			if(configs.size > 2 && runnable is GameHub.Data.Sources.GOG.GOGGame)
			{
				foreach(var conf in configs)
				{
					if(conf.has_suffix("_single.conf"))
					{
						configs.clear();
						configs.add(conf.replace("_single.conf", ".conf"));
						configs.add(conf);
						break;
					}
				}
			}

			foreach(var conf in configs)
			{
				cmd += "-conf";
				cmd += conf;
			}

			if(conf_windowed.query_exists() && opt_windowed != null && opt_windowed.enabled)
			{
				cmd += "-conf";
				cmd += conf_windowed.get_path();
			}

			bool bundled_win_dosbox_found = false;
			foreach(var dirname in DOSBOX_WIN_EXECUTABLE_NAMES)
			{
				foreach(var exename in DOSBOX_WIN_EXECUTABLE_NAMES)
				{
					foreach(var exeext in DOSBOX_WIN_EXECUTABLE_EXTENSIONS)
					{
						if(runnable.install_dir.get_child(dirname).get_child(exename + exeext).query_exists())
						{
							wdir = runnable.install_dir.get_child(dirname);
							bundled_win_dosbox_found = true;
							break;
						}
					}
					if(bundled_win_dosbox_found) break;
				}
				if(bundled_win_dosbox_found) break;
			}

			yield Utils.run_thread(cmd, wdir.get_path());
		}
	}
}
