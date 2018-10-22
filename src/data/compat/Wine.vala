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

			install_options = {
				new CompatTool.Option("/SILENT", _("Silent installation"), false),
				new CompatTool.Option("/VERYSILENT", _("Very silent installation"), true),
				new CompatTool.Option("/SUPPRESSMSGBOXES", _("Suppress messages"), true),
				new CompatTool.Option("/NOGUI", _("No GUI"), true)
			};

			if(installed)
			{
				actions = {
					new CompatTool.Action("prefix", _("Open prefix directory"), game => {
						Utils.open_uri(get_wineprefix(game).get_uri());
					}),
					new CompatTool.Action("winecfg", _("Run winecfg"), game => {
						wineutil.begin(null, game, "winecfg");
					}),
					new CompatTool.Action("winetricks", _("Run winetricks"), game => {
						winetricks.begin(null, game);
					}),
					new CompatTool.Action("regedit", _("Run regedit"), game => {
						wineutil.begin(null, game, "regedit");
					})
				};
			}
		}

		public override bool can_install(Game game)
		{
			return installed && Platform.WINDOWS in game.platforms;
		}

		public override bool can_run(Game game)
		{
			return installed && Platform.WINDOWS in game.platforms;
		}

		protected virtual async string[] prepare_installer_args(Game game)
		{
			var win_path = yield convert_path(game, game.install_dir);
			string[] opts = { "/SP-", "/NOCANCEL", "/NOGUI", "/NOICONS", @"/DIR=$(win_path)", "/LOG=C:\\install.log" };

			foreach(var opt in install_options)
			{
				if(opt.enabled)
				{
					opts += opt.name;
				}
			}

			return opts;
		}

		public override async void install(Game game, File installer)
		{
			if(!can_install(game) || (yield Game.Installer.guess_type(installer)) != Game.Installer.InstallerType.WINDOWS_EXECUTABLE) return;
			yield exec(game, installer, installer.get_parent(), yield prepare_installer_args(game));
		}

		public override async void run(Game game)
		{
			if(!can_run(game)) return;
			yield exec(game, game.executable, game.install_dir);
		}

		protected virtual async void exec(Game game, File file, File dir, string[]? args=null, bool parse_opts=true)
		{
			string[] cmd = { executable.get_path(), file.get_path() };
			if(args != null)
			{
				foreach(var arg in args) cmd += arg;
			}
			yield Utils.run_thread(cmd, dir.get_path(), prepare_env(game));
		}

		protected virtual File get_wineprefix(Game game)
		{
			return FSUtils.mkdir(game.install_dir.get_path(), @"$(COMPAT_DATA_DIR)/$(binary)_$(arch)");
		}

		public override File get_install_root(Game game)
		{
			return get_wineprefix(game).get_child("drive_c");
		}

		protected virtual string[] prepare_env(Game game, bool parse_opts=true)
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINEDLLOVERRIDES", "mshtml=d");
			var prefix = get_wineprefix(game);
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			if(arch != null)
			{
				env = Environ.set_variable(env, "WINEARCH", arch);
			}

			return env;
		}

		protected async void wineutil(File? wineprefix, Game game, string util="winecfg")
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINE", wine_binary.get_path());
			env = Environ.set_variable(env, "WINEDLLOVERRIDES", "mshtml=d");
			var prefix = wineprefix ?? get_wineprefix(game);
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			if(arch != null)
			{
				env = Environ.set_variable(env, "WINEARCH", "mshtml=d");
			}

			yield Utils.run_thread({ wine_binary.get_path(), util }, game.install_dir.get_path(), env);
		}

		protected async void winetricks(File? wineprefix, Game game)
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINE", wine_binary.get_path());
			env = Environ.set_variable(env, "WINEDLLOVERRIDES", "mshtml=d");
			var prefix = wineprefix ?? get_wineprefix(game);
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			if(arch != null)
			{
				env = Environ.set_variable(env, "WINEARCH", arch);
			}

			yield Utils.run_thread({ "winetricks" }, game.install_dir.get_path(), env);
		}

		public async string convert_path(Game game, File path)
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINE", wine_binary.get_path());
			env = Environ.set_variable(env, "WINEDLLOVERRIDES", "mshtml=d");
			var prefix = get_wineprefix(game);
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			if(arch != null)
			{
				env = Environ.set_variable(env, "WINEARCH", "mshtml=d");
			}

			var win_path = (yield Utils.run_thread({ wine_binary.get_path(), "winepath", "-w", path.get_path() }, game.install_dir.get_path(), env)).strip();
			debug("'%s' -> '%s'", path.get_path(), win_path);
			return win_path;
		}
	}
}
