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
			icon = "wine-symbolic";

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

		private async void exec(Game game, File file, File dir)
		{
			yield Utils.run_thread({ executable.get_path(), file.get_path() }, dir.get_path(), prepare_env(game));
		}

		private string[] prepare_env(Game game)
		{
			var env = Environ.get();

			var prefix = FSUtils.mkdir(game.install_dir.get_path(), @"_gamehub/$(binary)");
			if(prefix != null && prefix.query_exists())
			{
				env = Environ.set_variable(env, "WINEPREFIX", prefix.get_path());
			}

			return env;
		}
	}
}
