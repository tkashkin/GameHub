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

using GameHub.Utils;

using GameHub.Data.Sources.Steam;

namespace GameHub.Data.Compat
{
	public class Innoextract: CompatTool
	{
		public string binary { get; construct; default = "innoextract"; }

		public Innoextract(string binary="innoextract")
		{
			Object(binary: binary);
		}

		construct
		{
			id = @"innoextract";
			name = @"Innoextract";
			icon = "package-x-generic-symbolic";

			executable = Utils.find_executable(binary);
			installed = executable != null && executable.query_exists();
		}

		public override bool can_install(Runnable runnable)
		{
			return installed && runnable != null && Platform.WINDOWS in runnable.platforms;
		}

		public override async void install(Runnable runnable, File installer)
		{
			if(!can_install(runnable) || (yield Runnable.Installer.guess_type(installer)) != Runnable.Installer.InstallerType.WINDOWS_EXECUTABLE) return;

			string[] cmd = { executable.get_path(), "-e", "-m", "-d", runnable.install_dir.get_path() };
			if(runnable is Sources.GOG.GOGGame) cmd += "--gog";
			cmd += installer.get_path();
			yield Utils.run_thread(cmd, installer.get_parent().get_path());
			Utils.run({"bash", "-c", "mv app/* ."}, runnable.install_dir.get_path());
		}
	}
}
