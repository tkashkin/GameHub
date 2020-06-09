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

using GameHub.Data.Sources.Steam;
using GameHub.Utils;

namespace GameHub.Data.Compat
{
	public class Proton: Wine
	{
		public const string LATEST = "latest";

		public string appid { get; construct set; }
		public string? appname { get; construct set; }

		public bool is_latest { get; construct set; default = false; }

		public Proton(string appid, string? appname=null)
		{
			Object(appid: appid, appname: appname, is_latest: appid == LATEST, binary: "", arch: "");
		}

		construct
		{
			id = @"proton_$(appid)";
			name = appname ?? "Proton";
			icon = "source-steam-symbolic";
			installed = false;

			opt_prefix = new CompatTool.FileOption(Wine.OPT_PREFIX, _("Proton prefix"), null, null, Gtk.FileChooserAction.SELECT_FOLDER);
			opt_prefix.icon = icon;

			options = {
				opt_prefix,
				opt_env
			};

			install_options = {
				opt_prefix,
				opt_env,
				install_opt_innosetup_args
			};

			if(!is_latest)
			{
				init();
			}
		}

		public void init()
		{
			if(is_latest)
			{
				name = "Proton (latest)";
				foreach(var tool in CompatTools)
				{
					if(tool is Proton)
					{
						var proton = tool as Proton;
						if(proton.installed)
						{
							appid = proton.appid;
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
						name = appname ?? proton_dir.get_basename();
						executable = proton_dir.get_child("proton");
						installed = executable.query_exists();
						wine_binary = proton_dir.get_child("dist/bin/wine");
					}
				}
				else
				{
					name = appname ?? "Proton";
				}
			}

			if(installed)
			{
				actions = {
					new CompatTool.Action("prefix", _("Open prefix directory"), (r, cb) => {
						Utils.sleep_async.begin(0, GLib.Priority.DEFAULT, cb((obj, res) => {
							Utils.open_uri(get_wineprefix(r).get_parent().get_uri());
						}));
					}),
					new CompatTool.Action("winecfg", _("Run winecfg"), (r, cb) => {
						wineutil.begin(r, "winecfg", null, cb((obj, res) => {
							wineutil.end(res);
						}));
					}),
					new CompatTool.Action("winetricks", _("Run winetricks"), (r, cb) => {
						winetricks.begin(r, cb((obj, res) => {
							winetricks.end(res);
						}));
					}),
					new CompatTool.Action("taskmgr", _("Run taskmgr"), (r, cb) => {
						wineutil.begin(r, "taskmgr", null, cb((obj, res) => {
							wineutil.end(res);
						}));
					}),
					new CompatTool.Action("kill", _("Kill apps in prefix"), (r, cb) => {
						wineboot.begin(r, {"-k"}, cb((obj, res) => {
							wineboot.end(res);
						}));
					})
				};
			}
		}

		protected override async void exec(Runnable runnable, File file, File dir, string[]? args=null, bool parse_opts=true) throws Utils.RunError
		{
			string[] cmd = { executable.get_path(), "run", file.get_path() };
			if(file.get_path().down().has_suffix(".msi"))
			{
				cmd = { executable.get_path(), "run", "msiexec", "/i", file.get_path() };
			}
			var task = Utils.run(combine_cmd_with_args(cmd, runnable, args)).dir(dir.get_path()).env(prepare_env(runnable, parse_opts));
			if(runnable is TweakableGame)
			{
				task.tweaks(((TweakableGame) runnable).get_enabled_tweaks(this));
			}
			yield task.run_sync_thread();
		}

		public override File get_default_wineprefix(Runnable runnable)
		{
			var install_dir = runnable.install_dir ?? runnable.default_install_dir;

			var prefix = FSUtils.mkdir(install_dir.get_path(), @"$(FSUtils.GAMEHUB_DIR)/$(FSUtils.COMPAT_DATA_DIR)/$(id)/pfx");
			var dosdevices = prefix.get_child("dosdevices");

			if(FSUtils.file(install_dir.get_path(), @"$(FSUtils.GAMEHUB_DIR)/$(id)").query_exists())
			{
				//XXX: This looks very bad…
				Utils.run({"bash", "-c", @"mv -f $(FSUtils.GAMEHUB_DIR)/$(id) $(FSUtils.GAMEHUB_DIR)/$(FSUtils.COMPAT_DATA_DIR)/$(id)"}).dir(install_dir.get_path()).run_sync_nofail();
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

			//XXX: Why is this duplicated from Compat.Wine?
			if(dosdevices.get_child("c:").query_exists() && dosdevices.get_path().has_prefix(runnable.install_dir.get_path()))
			{
				var has_symlink = false;
				for(var letter = 'd'; letter <= 'y'; letter++)
				{
					if(is_symlink_and_correct(dosdevices.get_child(@"$(letter):")))
					{
						has_symlink = true;
						break;
					}
				}

				for(var letter = 'd'; has_symlink == false && letter <= 'y'; letter++)
				{
					if(!dosdevices.get_child(@"$(letter):").query_exists() && !dosdevices.get_child(@"$(letter)::").query_exists())
					{
						Utils.run({"ln", "-nsf", "../../../../../", @"$(letter):"}).dir(dosdevices.get_path()).run_sync_nofail();
						break;
					}
				}
			}

			return prefix;
		}

		//XXX: … and this?
		private bool is_symlink_and_correct(File symlink)
		{
			if(!symlink.query_exists())
			{
				return false;
			}

			try
			{
				var symlink_info = symlink.query_info("standard::is-symlink,standard::symlink-target", NONE);
				if(symlink_info == null || !symlink_info.get_is_symlink() || symlink_info.get_symlink_target() != "../../../../../")
				{
					return false;
				}
			}
			catch (Error e)
			{
				return false;
			}

			return true;
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

			env = Environ.set_variable(env, "STEAM_COMPAT_CLIENT_INSTALL_PATH", FSUtils.expand(FSUtils.Paths.Steam.Home));
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

		protected override async void wineboot(Runnable runnable, string[]? args=null) throws Utils.RunError
		{
			if(args == null)
			{
				yield proton_init_prefix(runnable);
			}

			yield wineutil(runnable, "wineboot", args);
		}

		protected async void proton_init_prefix(Runnable runnable) throws Utils.RunError
		{
			var prefix = get_wineprefix(runnable);
			if(opt_prefix.file != null && opt_prefix.file.query_exists())
			{
				prefix = opt_prefix.file.get_child("pfx");
			}

			var cmd = prefix.get_child("drive_c/windows/system32/cmd.exe");

			if(!cmd.query_exists())
			{
				yield Utils.run({executable.get_path(), "run", cmd.get_path(), "/c", "exit"})
					.dir(runnable.install_dir.get_path())
					.env(prepare_env(runnable))
					.run_sync_thread(true);
			}
		}

		public void install_app() throws Utils.RunError
		{
			if(!is_latest && !installed)
			{
				Steam.install_app(appid);
			}
		}

		public static void find_proton_versions()
		{
			if(Steam.instance == null) return;

			Steam.instance.load_appinfo();

			if(Steam.instance.appinfo == null) return;

			ArrayList<Proton> versions = new ArrayList<Proton>();

			foreach(var app_node in Steam.instance.appinfo.nodes.values)
			{
				if(app_node != null && app_node is BinaryVDF.ListNode)
				{
					var app = (BinaryVDF.ListNode) app_node;
					var common_node = app.get_nested({"appinfo", "common"});

					if(common_node != null && common_node is BinaryVDF.ListNode)
					{
						var common = (BinaryVDF.ListNode) common_node;

						var name_node = common.get("name");
						var type_node = common.get("type");

						if(name_node != null && name_node is BinaryVDF.StringNode && type_node != null && type_node is BinaryVDF.StringNode)
						{
							var name = ((BinaryVDF.StringNode) name_node).value;
							var type = ((BinaryVDF.StringNode) type_node).value;

							if(type != null && type.down() == "tool" && name != null && name.down().has_prefix("proton "))
							{
								versions.add(new Proton(app.key, name));
							}
						}
					}
				}
			}

			if(versions.size > 0)
			{
				versions.sort((first, second) => {
					return int.parse(second.appid) - int.parse(first.appid);
				});

				CompatTool[] tools = CompatTools;

				foreach(var proton in versions)
				{
					tools += proton;
				}

				CompatTools = tools;
			}
		}
	}
}
