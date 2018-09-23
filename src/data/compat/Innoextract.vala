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

		public override bool can_install(Game game)
		{
			return installed && Platform.WINDOWS in game.platforms;
		}

		public override async void install(Game game, File installer)
		{
			if(!can_install(game) || (yield Game.Installer.guess_type(installer)) != Game.Installer.InstallerType.WINDOWS_EXECUTABLE) return;

			string[] cmd = { executable.get_path(), "-e", "-m", "-d", game.install_dir.get_path() };
			if(game is Sources.GOG.GOGGame) cmd += "--gog";
			cmd += installer.get_path();
			yield Utils.run_thread(cmd, installer.get_parent().get_path());
		}
	}
}
