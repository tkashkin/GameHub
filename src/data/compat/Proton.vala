using GameHub.Utils;

using GameHub.Data.Sources.Steam;

namespace GameHub.Data.Compat
{
	public class Proton: CompatTool
	{
		public const string[] APPIDS = {"930400", "858280"}; // 3.7 Beta, 3.7

		public string appid { get; construct; }

		public Proton(string appid)
		{
			Object(appid: appid);
		}

		construct
		{
			id = @"proton_$(appid)";
			name = "Proton";
			icon = "steam-symbolic";

			options = {
				new CompatTool.Option("PROTON_NO_ESYNC", _("Disable esync"), false),
				new CompatTool.Option("PROTON_NO_D3D11", _("Disable DirectX 11 compatibility layer"), false),
				new CompatTool.Option("PROTON_USE_WINED3D11", _("Use WineD3D11 as DirectX 11 compatibility layer"), false),
				new CompatTool.Option("DXVK_HUD", _("Show DXVK info overlay"), true)
			};

			File? proton_dir = null;
			if(Steam.find_app_install_dir(appid, out proton_dir))
			{
				if(proton_dir != null)
				{
					name = proton_dir.get_basename();
					executable = proton_dir.get_child("proton");
					installed = executable.query_exists();
				}
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

		public override async void install(Game game, File installer)
		{
			if(!can_install(game) || (yield Game.Installer.guess_type(installer)) != Game.Installer.InstallerType.WINDOWS_EXECUTABLE) return;
			yield exec(game, installer, installer.get_parent(), false);
		}

		public override async void run(Game game)
		{
			if(!can_run(game)) return;
			yield exec(game, game.executable, game.install_dir);
		}

		private async void exec(Game game, File file, File dir, bool parse_opts=true)
		{
			yield Utils.run_thread({ executable.get_path(), "run", file.get_path() }, dir.get_path(), prepare_env(game, parse_opts));
		}

		private string[] prepare_env(Game game, bool parse_opts=true)
		{
			var env = Environ.get();

			var compatdata = FSUtils.mkdir(game.install_dir.get_path(), "_gamehub/proton");
			if(compatdata != null && compatdata.query_exists())
			{
				env = Environ.set_variable(env, "STEAM_COMPAT_CLIENT_INSTALL_PATH", FSUtils.Paths.Steam.Home);
				env = Environ.set_variable(env, "STEAM_COMPAT_DATA_PATH", compatdata.get_path());
				env = Environ.set_variable(env, "PROTON_LOG", "1");
				env = Environ.set_variable(env, "PROTON_DUMP_DEBUG_COMMANDS", "1");
			}

			if(parse_opts)
			{
				foreach(var opt in options)
				{
					if(opt.enabled)
					{
						env = Environ.set_variable(env, opt.name, "1");
					}
				}
			}

			return env;
		}
	}
}
