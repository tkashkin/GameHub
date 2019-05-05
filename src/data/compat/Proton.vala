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
	public class Proton: Wine
	{
		public const string[] APPIDS = {"1054830", "996510", "961940", "930400", "858280"}; // 4.2, 3.16 Beta, 3.16, 3.7 Beta, 3.7
		public const string LATEST = "latest";

		public string appid { get; construct; }

		public Proton(string appid)
		{
			Object(appid: appid, binary: "", arch: "");
		}

		construct
		{
			id = @"proton_$(appid)";
			name = "Proton";
			icon = "source-steam-symbolic";
			installed = false;

			opt_prefix = new CompatTool.FileOption(Wine.OPT_PREFIX, _("Proton prefix"), null, null, Gtk.FileChooserAction.SELECT_FOLDER);
			opt_prefix.icon = icon;

			options = {
				opt_prefix,
				opt_env,
				new CompatTool.BoolOption("PROTON_NO_ESYNC", _("Disable esync"), false),
				new CompatTool.BoolOption("PROTON_FORCE_LARGE_ADDRESS_AWARE", _("Force LARGE_ADDRESS_AWARE flag"), false),
				new CompatTool.BoolOption("PROTON_NO_D3D11", _("Disable DirectX 11 compatibility layer"), false),
				new CompatTool.BoolOption("PROTON_USE_WINED3D11", _("Use WineD3D11 as DirectX 11 compatibility layer"), false),
				new CompatTool.BoolOption("DXVK_HUD", _("Show DXVK info overlay"), true)
			};

			install_options = {
				opt_prefix,
				opt_env,
				install_opt_innosetup_args,
				new CompatTool.BoolOption("/SILENT", _("Silent installation"), false),
				new CompatTool.BoolOption("/VERYSILENT", _("Very silent installation"), false),
				new CompatTool.BoolOption("/SUPPRESSMSGBOXES", _("Suppress messages"), false),
				new CompatTool.BoolOption("/NOGUI", _("No GUI"), false)
			};

			if(appid == Proton.LATEST)
			{
				foreach(var tool in CompatTools)
				{
					if(tool is Proton)
					{
						var proton = tool as Proton;
						if(proton.installed)
						{
							appid = proton.appid;
							name = "Proton (latest)";
							executable = proton.executable;
							installed = true;
							wine_binary = proton.wine_binary;
							break;
						}
					}
				}
			}
			else
			{
				File? proton_dir = null;
				if(Steam.find_app_install_dir(appid, out proton_dir))
				{
					if(proton_dir != null)
					{
						name = proton_dir.get_basename();
						executable = proton_dir.get_child("proton");
						installed = executable.query_exists();
						wine_binary = proton_dir.get_child("dist/bin/wine");
					}
				}
			}

			if(installed)
			{
				actions = {
					new CompatTool.Action("prefix", _("Open prefix directory"), r => {
						Utils.open_uri(get_wineprefix(r).get_parent().get_uri());
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

		protected override async void exec(Runnable runnable, File file, File dir, string[]? args=null, bool parse_opts=true)
		{
			string[] cmd = { executable.get_path(), "run", file.get_path() };
			if(file.get_path().down().has_suffix(".msi"))
			{
				cmd = { executable.get_path(), "run", "msiexec", "/i", file.get_path() };
			}
			if(args != null)
			{
				foreach(var arg in args) cmd += arg;
			}
			yield Utils.run_thread(cmd, dir.get_path(), prepare_env(runnable, parse_opts));
		}

		public override File get_default_wineprefix(Runnable runnable)
		{
			var install_dir = runnable.install_dir ?? runnable.default_install_dir;

			var prefix = FSUtils.mkdir(install_dir.get_path(), @"$(FSUtils.GAMEHUB_DIR)/$(FSUtils.COMPAT_DATA_DIR)/$(id)/pfx");
			var dosdevices = prefix.get_child("dosdevices");

			if(FSUtils.file(install_dir.get_path(), @"$(FSUtils.GAMEHUB_DIR)/$(binary)_$(arch)").query_exists())
			{
				Utils.run({"bash", "-c", @"mv -f $(FSUtils.GAMEHUB_DIR)/$(id) $(FSUtils.GAMEHUB_DIR)/$(FSUtils.COMPAT_DATA_DIR)/$(id)"}, install_dir.get_path());
				FSUtils.rm(dosdevices.get_child("d:").get_path());
			}

			return prefix;
		}

		public override File get_wineprefix(Runnable runnable)
		{
			var prefix = get_default_wineprefix(runnable);

			if(opt_prefix.file != null && opt_prefix.file.query_exists())
			{
				prefix = opt_prefix.file.get_child("pfx");
			}

			var dosdevices = prefix.get_child("dosdevices");

			if(dosdevices.get_child("c:").query_exists() && !dosdevices.get_child("d:").query_exists())
			{
				if(dosdevices.get_path().has_prefix(runnable.install_dir.get_path()))
				{
					Utils.run({"ln", "-nsf", "../../../../../", "d:"}, dosdevices.get_path());
				}
			}

			return prefix;
		}

		protected override string[] prepare_env(Runnable runnable, bool parse_opts=true)
		{
			var env = base.prepare_env(runnable, parse_opts);

			var dist = executable.get_parent().get_child("dist").get_path();
			env = Environ.set_variable(env, "WINEDLLPATH", @"$(dist)/lib64/wine:$(dist)/lib/wine");

			var compatdata = get_wineprefix(runnable).get_parent();
			if(compatdata != null && compatdata.query_exists())
			{
				env = Environ.set_variable(env, "STEAM_COMPAT_DATA_PATH", compatdata.get_path());
				env = Environ.set_variable(env, "WINEPREFIX", compatdata.get_child("pfx").get_path());
			}

			env = Environ.set_variable(env, "STEAM_COMPAT_CLIENT_INSTALL_PATH", FSUtils.Paths.Steam.Home);
			env = Environ.set_variable(env, "PROTON_LOG", "1");

			if(parse_opts)
			{
				foreach(var opt in options)
				{
					if(opt is CompatTool.BoolOption && ((CompatTool.BoolOption) opt).enabled)
					{
						env = Environ.set_variable(env, opt.name, "1");
					}
				}
			}

			return env;
		}

		protected override async void wineboot(Runnable runnable, string[]? args=null)
		{
			if(args == null)
			{
				yield proton_init_prefix(runnable);
			}

			yield wineutil(runnable, "wineboot", args);
		}

		protected async void proton_init_prefix(Runnable runnable)
		{
			var prefix = get_wineprefix(runnable);
			if(opt_prefix.file != null && opt_prefix.file.query_exists())
			{
				prefix = opt_prefix.file.get_child("pfx");
			}

			var cmd = prefix.get_child("drive_c/windows/system32/cmd.exe");

			if(!cmd.query_exists())
			{
				yield Utils.run_thread({ executable.get_path(), "run", cmd.get_path() }, runnable.install_dir.get_path(), prepare_env(runnable), false, true);
			}
		}
	}
}
