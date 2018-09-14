using GameHub.Utils;

using GameHub.Data.Sources.Steam;

namespace GameHub.Data.Compat
{
	public class Wine: CompatTool
	{
		public string binary { get; construct; default = "wine"; }

		public Wine(string binary="wine")
		{
			Object(binary: binary);
		}

		construct
		{
			id = @"wine_$(binary)";
			name = @"Wine ($(binary))";
			icon = "tool-wine-symbolic";
			installed = false;

			var which = Utils.run({"which", binary}).strip();

			if("not found" in which)
			{
				installed = false;
			}
			else
			{
				executable = FSUtils.file(which);
				installed = executable.query_exists();
			}

			if(installed)
			{
				actions = {
					new CompatTool.Action("winecfg", _("Run winecfg"), game => {
						wineutil.begin(executable, null, game, "winecfg");
					}),
					new CompatTool.Action("winetricks", _("Run winetricks"), game => {
						winetricks.begin(executable, null, game);
					}),
					new CompatTool.Action("regedit", _("Run regedit"), game => {
						wineutil.begin(executable, null, game, "regedit");
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

		public override async void install(Game game, File installer)
		{
			if(!can_install(game) || (yield Game.Installer.guess_type(installer)) != Game.Installer.InstallerType.WINDOWS_EXECUTABLE) return;
			yield exec(game, installer, installer.get_parent());
		}

		public override async void run(Game game)
		{
			if(!can_run(game)) return;
			yield exec(game, game.executable, game.install_dir);
		}

		protected virtual async void exec(Game game, File file, File dir, bool parse_opts=true)
		{
			yield Utils.run_thread({ executable.get_path(), file.get_path() }, dir.get_path(), prepare_env(game));
		}

		protected virtual string[] prepare_env(Game game, bool parse_opts=true)
		{
			var env = Environ.get();

			var prefix = FSUtils.mkdir(game.install_dir.get_path(), @"_gamehub/$(binary)");
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}

			return env;
		}

		protected async void wineutil(File wine, File? wineprefix, Game game, string util="winecfg")
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINE", wine.get_path());
			var prefix = wineprefix ?? FSUtils.mkdir(game.install_dir.get_path(), @"_gamehub/$(binary)");
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			yield Utils.run_thread({ wine.get_path(), util }, game.install_dir.get_path(), env);
		}

		protected async void winetricks(File wine, File? wineprefix, Game game)
		{
			var env = Environ.get();
			env = Environ.set_variable(env, "WINE", wine.get_path());
			var prefix = wineprefix ?? FSUtils.mkdir(game.install_dir.get_path(), @"_gamehub/$(binary)");
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}
			yield Utils.run_thread({ "winetricks" }, game.install_dir.get_path(), env);
		}
	}
}
