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
	public class RetroArch: CompatTool
	{
		public const string LIBRETRO_CORE_SUFFIX = "_libretro.so";
		public const string LIBRETRO_CORE_INFO_SUFFIX = "_libretro.info";

		public static RetroArch instance;
		public ArrayList<string> cores = new ArrayList<string>();

		public string binary { get; construct; default = "retroarch"; }
		public bool has_cores { get; protected set; default = false; }

		private CompatTool.ComboOption core_option;

		public RetroArch(string binary="retroarch")
		{
			Object(binary: binary);
			instance = this;
		}

		construct
		{
			id = @"retroarch";
			name = @"RetroArch";
			icon = "emu-retroarch-symbolic";

			executable = Utils.find_executable(binary);
			installed = executable != null && executable.query_exists();

			core_option = new CompatTool.ComboOption("core", _("Libretro core file"), cores, null);

			find_cores();

			options = { core_option };
		}

		public bool find_cores()
		{
			cores.clear();
			has_cores = false;
			core_option.options = cores;

			var dir = FSUtils.file(Settings.Compat.RetroArch.instance.core_dir);

			if(dir == null || !dir.query_exists())
			{
				return has_cores;
			}

			try
			{
				FileInfo? finfo = null;
				var enumerator = dir.enumerate_children("standard::name", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				while((finfo = enumerator.next_file()) != null)
				{
					var fname = finfo.get_name();
					if(fname.has_suffix(LIBRETRO_CORE_SUFFIX))
					{
						cores.add(fname.replace(LIBRETRO_CORE_SUFFIX, ""));
					}
				}
			}
			catch(Error e)
			{
				warning("[RetroArch.find_cores] %s", e.message);
			}

			has_cores = cores.size > 0;
			core_option.options = cores;

			return has_cores;
		}

		public override bool can_run(Runnable runnable)
		{
			return installed && runnable is Game && has_cores;
		}

		public override async void run(Runnable runnable) throws Utils.RunError
		{
			this.ensure_installed();
			if(!can_run(runnable))
			{
				throw new Utils.RunError.COMMAND_NOT_FOUND(
					_("RetroArch has no core, please check the logs")
				);
			}
			
			var core = core_option.value;
			if(core == null) return;  //XXX: When does this happen?

			if(!core.has_prefix("/"))
			{
				core = FSUtils.expand(Settings.Compat.RetroArch.instance.core_dir, core);
			}
			if(!core.has_suffix(LIBRETRO_CORE_SUFFIX))
			{
				core += LIBRETRO_CORE_SUFFIX;
			}

			string[] cmd = { executable.get_path(), "-L", core, runnable.executable.get_path() };

			yield Utils.run(combine_cmd_with_args(cmd, runnable)).dir(runnable.work_dir.get_path()).run_sync_thread();
		}
	}
}
