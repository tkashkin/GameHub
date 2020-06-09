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

namespace GameHub.Data.Compat
{
	public class DOSBox: CompatTool
	{
		public string binary { get; construct; default = "dosbox"; }

		private HashMap<File, CompatTool.BoolOption> additional_configs = new HashMap<File, CompatTool.BoolOption>();

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

			init();
		}

		private void init()
		{
			CompatTool.Option[] options = {};
			additional_configs.clear();

			foreach(var data_dir in FSUtils.get_data_dirs("compat/dosbox"))
			{
				if(GameHub.Application.log_verbose)
				{
					debug("[DOSBox.init] Config directory: '%s'", data_dir.get_path());
				}

				try
				{
					FileInfo? finfo = null;
					var enumerator = data_dir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
					while((finfo = enumerator.next_file()) != null)
					{
						var fname = finfo.get_name();
						if(fname.down().has_suffix(".conf"))
						{
							var conf = data_dir.get_child(fname);
							var description = fname;
							bool enabled = false;

							string contents;
							FileUtils.get_contents(conf.get_path(), out contents);
							var lines = contents.split("\n");

							foreach(var line in lines)
							{
								if(line.has_prefix("[")) break;

								if("description=" in line)
								{
									description = line.replace("description=", "").strip();
								}
								else if("enabled=true" in line)
								{
									enabled = true;
								}
							}

							if(GameHub.Application.log_verbose)
							{
								debug("[DOSBox.init] Config: '%s'; description: '%s'; enabled: %s", conf.get_path(), description, enabled.to_string());
							}

							var opt = new CompatTool.BoolOption(conf.get_path(), description, enabled);
							options += opt;
							additional_configs.set(conf, opt);
						}
					}
				}
				catch(Error e)
				{
					warning("[DOSBox.init] %s", e.message);
				}
				this.options = options;
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
					if(fname.down().has_suffix(".conf"))
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

		private static bool is_dos_executable(File? file)
		{
			//XXX: Switch to using libmagic directly here
			if(file == null || !file.query_exists()) return false;
			var type = Utils.run({"file", "-b", file.get_path()}).log(false).run_sync_nofail(true).output;
			if(type != null && type.length > 0)
			{
				return "DOS" in type;
			}
			return false;
		}

		public override bool can_run(Runnable runnable)
		{
			return installed && runnable is Game && runnable.install_dir != null && runnable.install_dir.query_exists()
				&& (is_dos_executable(runnable.executable) || find_configs(runnable.install_dir).size > 0);
		}

		public override async void run(Runnable runnable) throws Utils.RunError
		{
			this.ensure_installed();
			if(!can_run(runnable))
			{
				throw new Utils.RunError.INVALID_ARGUMENT(
					_("File “%s” does not look like a DOS executable"),
					runnable.executable.get_path()
				);
			}

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

			if(configs.size > 0)
			{
				foreach(var conf in configs)
				{
					cmd += "-conf";
					cmd += conf;
				}
			}
			else if(runnable.executable != null)
			{
				var dos_path = runnable.executable.get_path().replace(runnable.install_dir.get_path(), "").replace("/", "\\");
				var dos_cmdline = dos_path + ((runnable.arguments != null && runnable.arguments.length > 0) ? " " + runnable.arguments : "");
				cmd += "-c";
				cmd += "mount c .";
				cmd += "-c";
				cmd += "c:";
				cmd += "-c";
				cmd += "call " + dos_cmdline;
				cmd += "-c";
				cmd += "exit";
			}

			foreach(var conf in additional_configs.entries)
			{
				if(conf.key.query_exists() && conf.value.enabled)
				{
					cmd += "-conf";
					cmd += conf.key.get_path();
				}
			}

			var bundled_win_dosbox = FSUtils.find_case_insensitive(runnable.install_dir, "dosbox/dosbox.exe");
			if(bundled_win_dosbox != null && bundled_win_dosbox.query_exists())
			{
				wdir = bundled_win_dosbox.get_parent();
			}

			var task = Utils.run(combine_cmd_with_args(cmd, runnable)).dir(wdir.get_path());
			if(runnable is TweakableGame)
			{
				task.tweaks(((TweakableGame) runnable).get_enabled_tweaks(this));
			}
			yield task.run_sync_thread();
		}
	}
}
