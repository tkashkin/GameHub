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

using GameHub.Utils;

using GameHub.Data.Sources.Steam;

namespace GameHub.Data.Compat
{
	public class Innoextract: CompatTool
	{
		private const int[] MIN_SUPPORTED_VERSION = { 1, 8 };

		public string binary { get; construct; default = "innoextract"; }

		public string? version { get; construct; default = null; }

		public Innoextract(string binary="innoextract")
		{
			Object(binary: binary);
		}

		construct
		{
			id = "innoextract";
			name = "Innoextract";
			icon = "package-x-generic-symbolic";

			executable = Utils.find_executable(binary);
			installed = executable != null && executable.query_exists();

			if(installed)
			{
				version = Utils.run({executable.get_path(), "-v", "-q", "-c", "0"}).log(false).run_sync_nofail(true).output.replace(id, "").strip();
				name = name + " (" + version + ")";

				if(Utils.compare_versions(Utils.parse_version(version), Innoextract.MIN_SUPPORTED_VERSION) < 0)
				{
					warnings = {
						_("Innoextract <b>%1$s</b> is not supported and may not be able to extract some games correctly.\nInstall innoextract <b>%2$s</b> or newer.")
							.printf(version, Utils.format_version(Innoextract.MIN_SUPPORTED_VERSION))
					};
				}
			}
		}

		public override bool can_install(Runnable runnable)
		{
			return installed && runnable != null && Platform.WINDOWS in runnable.platforms;
		}

		public override async void install(Runnable runnable, File installer) throws Utils.RunError
		{
			this.ensure_installed();
			if(!can_install(runnable) || (yield Runnable.Installer.guess_type(installer)) != Runnable.Installer.InstallerType.WINDOWS_EXECUTABLE)
			{
				throw new Utils.RunError.INVALID_ARGUMENT(
					_("File “%s” does not appear to be an InnoSetup installer file"),
					installer.get_path()
				);
			}

			runnable.install_dir = runnable.install_dir ?? runnable.default_install_dir;

			string[] cmd = { executable.get_path(), "-e", "-m", "-d", runnable.install_dir.get_path() };
			if(runnable is Sources.GOG.GOGGame) cmd += "--gog";
			cmd += installer.get_path();
			yield Utils.run(cmd).dir(installer.get_parent().get_path()).run_sync_thread();

			do
			{
				FSUtils.mv_up(runnable.install_dir, "__support");
				FSUtils.mv_up(runnable.install_dir, "app");
			}
			while(runnable.install_dir.get_child("__support").query_exists());
		}
	}
}
