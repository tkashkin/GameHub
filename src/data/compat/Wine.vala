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
	public class Wine: CompatTool
	{
		public const string OPT_PREFIX = "prefix";
		public const string OPT_ENV = "env";

		public string binary { get; construct; default = "wine"; }
		public string arch { get; construct; default = "win64"; }
		public File? wine_binary { get; protected set; }

		public CompatTool.FileOption opt_prefix;
		public CompatTool.StringOption opt_env;

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

			opt_prefix = new CompatTool.FileOption(Wine.OPT_PREFIX, _("Wine prefix"), null, null, Gtk.FileChooserAction.SELECT_FOLDER);
			opt_prefix.icon = icon;
			opt_env = new CompatTool.StringOption(Wine.OPT_ENV, _("Environment variables"), null);
			opt_env.icon = "utilities-terminal-symbolic";

			options = { opt_prefix, opt_env };

			install_opt_innosetup_args = new CompatTool.BoolOption("InnoSetup", _("InnoSetup default options"), true);

			install_options = {
				opt_prefix,
				opt_env,
				install_opt_innosetup_args,
				new CompatTool.BoolOption("/SILENT", _("Silent installation"), false),
				new CompatTool.BoolOption("/VERYSILENT", _("Very silent installation"), false),
				new CompatTool.BoolOption("/SUPPRESSMSGBOXES", _("Suppress messages"), false),
				new CompatTool.BoolOption("/NOGUI", _("No GUI"), false)
			};

			if(installed)
			{
				actions = {
					new CompatTool.Action("prefix", _("Open prefix directory"), r => {
						Utils.open_uri(get_wineprefix(r).get_uri());
					}),
					new CompatTool.Action("winecfg", _("Run winecfg"), r => {
						wineutil.begin(r, "winecfg");
					}),
					new CompatTool.Action("winetricks", _("Run winetricks"), r => {
						winetricks.begin(r);
					}),
					new CompatTool.Action("taskmgr", _("Run taskmgr"), r => {
						wineutil.begin(r, "taskmgr");
					}),
					new CompatTool.Action("kill", _("Kill apps in prefix"), r => {
						wineboot.begin(r, {"-k"});
					})
				};
			}
		}

		public override bool can_install(Runnable runnable)
		{
			return can_run(runnable);
		}

		public override bool can_run(Runnable runnable)
		{
			return installed && runnable != null && ((runnable is Game && (runnable is GameHub.Data.Sources.User.UserGame || Platform.WINDOWS in runnable.platforms)) || runnable is Emulator);
		}

		public override bool can_run_action(Runnable runnable, Runnable.RunnableAction action)
		{
			return installed && runnable != null && action != null;
		}

		protected virtual async string[] prepare_installer_args(Runnable runnable)
		{
			var tmp_root = (runnable is Game) ? "_gamehub_game_root" : "_gamehub_app_root";
			var win_path = yield convert_path(runnable, runnable.install_dir.get_child(tmp_root));
			var log_win_path = yield convert_path(runnable, runnable.install_dir.get_child("install.log"));

			string[] opts = {};

			if(install_opt_innosetup_args.enabled)
			{
				opts = { "/SP-", "/NOCANCEL", "/NOGUI", "/NOICONS", @"/DIR=$(win_path)", @"/LOG=$(log_win_path)" };
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
			yield wineboot(runnable);
			yield exec(runnable, installer, installer.get_parent(), yield prepare_installer_args(runnable));

			var tmp_root = (runnable is Game) ? "_gamehub_game_root" : "_gamehub_app_root";
			if(runnable.install_dir != null && runnable.install_dir.get_child(tmp_root).query_exists())
			{
				FSUtils.mv_up(runnable.install_dir, tmp_root);
			}
		}

		public override async void run(Runnable runnable)
		{
			if(!can_run(runnable)) return;
			yield wineboot(runnable);
			yield exec(runnable, runnable.executable, runnable.install_dir, Utils.parse_args(runnable.arguments));
		}

		public override async void run_action(Runnable runnable, Runnable.RunnableAction action)
		{
			if(!can_run_action(runnable, action)) return;
			yield wineboot(runnable);
			yield exec(runnable, action.file, action.workdir, Utils.parse_args(action.args));
		}

		public override async void run_emulator(Emulator emu, Game? game, bool launch_in_game_dir=false)
		{
			if(!can_run(emu)) return;
			var dir = game != null && launch_in_game_dir ? game.install_dir : emu.install_dir;
			yield exec(emu, emu.executable, dir, emu.get_args(game));
		}

		protected virtual async void exec(Runnable runnable, File file, File dir, string[]? args=null, bool parse_opts=true)
		{
			string[] cmd = { executable.get_path(), file.get_path() };
			if(file.get_path().down().has_suffix(".msi"))
			{
				cmd = { executable.get_path(), "msiexec", "/i", file.get_path() };
			}
			if(args != null)
			{
				foreach(var arg in args) cmd += arg;
			}
			yield Utils.run_thread(cmd, dir.get_path(), prepare_env(runnable));
		}

		public virtual File get_default_wineprefix(Runnable runnable)
		{
			var install_dir = runnable.install_dir ?? runnable.default_install_dir;

			var prefix = FSUtils.mkdir(install_dir.get_path(), @"$(FSUtils.GAMEHUB_DIR)/$(FSUtils.COMPAT_DATA_DIR)/$(binary)_$(arch)");
			var dosdevices = prefix.get_child("dosdevices");

			if(FSUtils.file(install_dir.get_path(), @"$(FSUtils.GAMEHUB_DIR)/$(binary)_$(arch)").query_exists())
			{
				Utils.run({"bash", "-c", @"mv -f $(FSUtils.GAMEHUB_DIR)/$(binary)_$(arch) $(FSUtils.GAMEHUB_DIR)/$(FSUtils.COMPAT_DATA_DIR)/$(binary)_$(arch)"}, install_dir.get_path());
				FSUtils.rm(dosdevices.get_child("d:").get_path());
			}

			return prefix;
		}

		public virtual File get_wineprefix(Runnable runnable)
		{
			var prefix = get_default_wineprefix(runnable);

			if(opt_prefix.file != null && opt_prefix.file.query_exists())
			{
				prefix = opt_prefix.file;
			}

			var dosdevices = prefix.get_child("dosdevices");

			if(dosdevices.get_child("c:").query_exists() && !dosdevices.get_child("d:").query_exists())
			{
				if(dosdevices.get_path().has_prefix(runnable.install_dir.get_path()))
				{
					Utils.run({"ln", "-nsf", "../../../../", "d:"}, dosdevices.get_path());
				}
			}

			return prefix;
		}

		public override File get_install_root(Runnable runnable)
		{
			return get_wineprefix(runnable).get_child("drive_c");
		}

		protected virtual string[] prepare_env(Runnable runnable, bool parse_opts=true)
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINEDLLOVERRIDES", "mshtml=d;winemenubuilder.exe=d");

			if(wine_binary != null && wine_binary.query_exists())
			{
				env = Environ.set_variable(env, "WINE", wine_binary.get_path());
				env = Environ.set_variable(env, "WINELOADER", wine_binary.get_path());
				var wineserver_binary = wine_binary.get_parent().get_child("wineserver");
				if(wineserver_binary.query_exists())
				{
					env = Environ.set_variable(env, "WINESERVER", wineserver_binary.get_path());
				}
			}

			var prefix = get_wineprefix(runnable);
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}

			if(arch != null && arch.length > 0)
			{
				env = Environ.set_variable(env, "WINEARCH", arch);
			}

			if(parse_opts)
			{
				if(opt_env.value != null && opt_env.value.length > 0)
				{
					var evars = Utils.parse_args(opt_env.value);
					if(evars != null)
					{
						foreach(var ev in evars)
						{
							var v = ev.split("=");
							env = Environ.set_variable(env, v[0], v[1]);
						}
					}
				}
			}

			return env;
		}

		protected virtual async void wineboot(Runnable runnable, string[]? args=null)
		{
			yield wineutil(runnable, "wineboot", args);
		}

		protected async void wineutil(Runnable runnable, string util="winecfg", string[]? args=null)
		{
			string[] cmd = { wine_binary.get_path(), util };

			if(args != null)
			{
				foreach(var arg in args)
				{
					cmd += arg;
				}
			}

			yield Utils.run_thread(cmd, runnable.install_dir.get_path(), prepare_env(runnable));
		}

		protected async void winetricks(Runnable runnable)
		{
			yield Utils.run_thread({ "winetricks" }, runnable.install_dir.get_path(), prepare_env(runnable));
		}

		public async string convert_path(Runnable runnable, File path)
		{
			var win_path = (yield Utils.run_thread({ wine_binary.get_path(), "winepath", "-w", path.get_path() }, runnable.install_dir.get_path(), prepare_env(runnable), false, true)).strip();
			debug("[Wine.convert_path] '%s' -> '%s'", path.get_path(), win_path);
			return win_path;
		}
	}
}
