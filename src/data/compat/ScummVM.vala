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
	public class ScummVM: CompatTool
	{
		private static string SCUMMVM_NO_GAMES_WARNING = "WARNING: ScummVM could not find any game";

		public string binary { get; construct; default = "scummvm"; }

		public ScummVM(string binary="scummvm")
		{
			Object(binary: binary);
		}

		construct
		{
			id = "scummvm";
			name = "ScummVM";
			icon = "tool-scummvm-symbolic";

			executable = Utils.find_executable(binary);
			installed = executable != null && executable.query_exists();
		}

		private bool scummvm_detect(File? dir)
		{
			if(dir != null && dir.query_exists())
			{
				var output = Utils.run({ executable.get_path(), "--detect" }, dir.get_path(), null, false, false);
				return !(SCUMMVM_NO_GAMES_WARNING in output);
			}
			return false;
		}

		public override bool can_run(Runnable runnable)
		{
			return installed && runnable is Game && runnable.install_dir != null
				&& (scummvm_detect(runnable.install_dir) || scummvm_detect(runnable.install_dir.get_child("data")));
		}

		public override async void run(Runnable runnable)
		{
			if(!can_run(runnable)) return;

			var dir = runnable.install_dir;
			var data_dir = runnable.install_dir.get_child("data");

			if(!scummvm_detect(dir) && scummvm_detect(data_dir))
			{
				dir = data_dir;
			}

			yield Utils.run_thread({ executable.get_path(), "--auto-detect" }, dir.get_path());
		}
	}
}
