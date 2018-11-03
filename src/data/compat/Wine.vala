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
	public class Wine: CompatTool
	{
		public string binary { get; construct; default = "wine"; }
		public string arch { get; construct; default = "win64"; }
		public File? wine_binary { get; protected set; }

		public CompatTool.BoolOption install_opt_innosetup_args;

		public Wine(string binary="wine", string arch="win64")
		{
			Object(binary: binary, arch: arch);
		}

		construct
		{
			id = @"wine_$(binary)_$(arch)";
			name = @"Wine ($(binary)) [arch: $(arch)]";
			icon = "tool-wine-symbolic";

			executable = wine_binary = Utils.find_executable(binary);
			installed = executable != null && executable.query_exists();

			install_opt_innosetup_args = new CompatTool.BoolOption("InnoSetup", _("InnoSetup default options"), true);

			install_options = {
				install_opt_innosetup_args,
				new CompatTool.BoolOption("/SILENT", _("Silent installation"), false),
				new CompatTool.BoolOption("/VERYSILENT", _("Very silent installation"), true),
				new CompatTool.BoolOption("/SUPPRESSMSGBOXES", _("Suppress messages"), true),
				new CompatTool.BoolOption("/NOGUI", _("No GUI"), true)
			};

			if(installed)
			{
				actions = {
					new CompatTool.Action("prefix", _("Open prefix directory"), r => {
						Utils.open_uri(get_wineprefix(r).get_uri());
					}),
					new CompatTool.Action("winecfg", _("Run winecfg"), r => {
						wineutil.begin(null, r, "winecfg");
					}),
					new CompatTool.Action("winetricks", _("Run winetricks"), r => {
						winetricks.begin(null, r);
					}),
					new CompatTool.Action("regedit", _("Run regedit"), r => {
						wineutil.begin(null, r, "regedit");
					})
				};
			}
		}

		public override bool can_install(Runnable runnable)
		{
			return installed && runnable != null && Platform.WINDOWS in runnable.platforms;
		}

		public override bool can_run(Runnable runnable)
		{
			return installed && runnable != null && ((runnable is Game && (runnable is GameHub.Data.Sources.User.UserGame || Platform.WINDOWS in runnable.platforms)) || runnable is Emulator);
		}

		protected virtual async string[] prepare_installer_args(Runnable runnable)
		{
			var win_path = yield convert_path(runnable, runnable.install_dir);

			string[] opts = {};

			if(install_opt_innosetup_args.enabled)
			{
				opts = { "/SP-", "/NOCANCEL", "/NOGUI", "/NOICONS", @"/DIR=$(win_path)", "/LOG=C:\\install.log" };
			}

			foreach(var opt in install_options)
			{
				if(opt.name.has_prefix("/") && opt is CompatTool.BoolOption && ((CompatTool.BoolOption) opt).enabled)
				{
					opts += opt.name;
				}
			}

			return opts;
		}

		public override async void install(Runnable runnable, File installer)
		{
			if(!can_install(runnable) || (yield Runnable.Installer.guess_type(installer)) != Runnable.Installer.InstallerType.WINDOWS_EXECUTABLE) return;
			yield exec(runnable, installer, installer.get_parent(), yield prepare_installer_args(runnable));
		}

		public override async void run(Runnable runnable)
		{
			if(!can_run(runnable)) return;
			yield exec(runnable, runnable.executable, runnable.install_dir);
		}

		public override async void run_emulator(Emulator emu, Game runnable)
		{
			if(!can_run(emu)) return;
			yield exec(emu, emu.executable, emu.install_dir, emu.get_args(runnable));
		}

		protected virtual async void exec(Runnable runnable, File file, File dir, string[]? args=null, bool parse_opts=true)
		{
			string[] cmd = { executable.get_path(), file.get_path() };
			if(args != null)
			{
				foreach(var arg in args) cmd += arg;
			}
			yield Utils.run_thread(cmd, dir.get_path(), prepare_env(runnable));
		}

		protected virtual File get_wineprefix(Runnable runnable)
		{
			return FSUtils.mkdir(runnable.install_dir.get_path(), @"$(COMPAT_DATA_DIR)/$(binary)_$(arch)");
		}

		public override File get_install_root(Runnable runnable)
		{
			return get_wineprefix(runnable).get_child("drive_c");
		}

		protected virtual string[] prepare_env(Runnable runnable, bool parse_opts=true)
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINEDLLOVERRIDES", "mshtml=d");
			var prefix = get_wineprefix(runnable);
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			if(arch != null && arch.length > 0)
			{
				env = Environ.set_variable(env, "WINEARCH", arch);
			}

			return env;
		}

		protected async void wineutil(File? wineprefix, Runnable runnable, string util="winecfg")
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINE", wine_binary.get_path());
			env = Environ.set_variable(env, "WINEDLLOVERRIDES", "mshtml=d");
			var prefix = wineprefix ?? get_wineprefix(runnable);
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			if(arch != null && arch.length > 0)
			{
				env = Environ.set_variable(env, "WINEARCH", arch);
			}

			yield Utils.run_thread({ wine_binary.get_path(), util }, runnable.install_dir.get_path(), env);
		}

		protected async void winetricks(File? wineprefix, Runnable runnable)
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINE", wine_binary.get_path());
			env = Environ.set_variable(env, "WINEDLLOVERRIDES", "mshtml=d");
			var prefix = wineprefix ?? get_wineprefix(runnable);
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			if(arch != null && arch.length > 0)
			{
				env = Environ.set_variable(env, "WINEARCH", arch);
			}

			yield Utils.run_thread({ "winetricks" }, runnable.install_dir.get_path(), env);
		}

		public async string convert_path(Runnable runnable, File path)
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINE", wine_binary.get_path());
			env = Environ.set_variable(env, "WINEDLLOVERRIDES", "mshtml=d");
			var prefix = get_wineprefix(runnable);
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			if(arch != null && arch.length > 0)
			{
				env = Environ.set_variable(env, "WINEARCH", arch);
			}

			var win_path = (yield Utils.run_thread({ wine_binary.get_path(), "winepath", "-w", path.get_path() }, runnable.install_dir.get_path(), env)).strip();
			debug("'%s' -> '%s'", path.get_path(), win_path);
			return win_path;
		}
	}
}
