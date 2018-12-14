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

using Gtk;
using Gdk;
using Granite;

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Data.Sources.Steam;
using GameHub.Data.Sources.GOG;
using GameHub.Data.Sources.Humble;
using GameHub.Data.Sources.User;
using GameHub.Utils;

namespace GameHub
{
	public class Application: Granite.Application
	{
		public static Application instance;

		private GameHub.UI.Windows.MainWindow? main_window;

		construct
		{
			application_id = ProjectConfig.PROJECT_NAME;
			flags = ApplicationFlags.HANDLES_COMMAND_LINE;
			program_name = "GameHub";
			build_version = ProjectConfig.VERSION;
			instance = this;
		}

		private void init()
		{
			if(Platforms != null && GameSources != null && CompatTools != null) return;

			FSUtils.make_dirs();

			Database.create();

			Platforms = { Platform.LINUX, Platform.WINDOWS, Platform.MACOS };
			CurrentPlatform = Platform.LINUX;

			GameSources = { new Steam(), new GOG(), new Humble(), new Trove(), new User() };

			CompatTool[] tools = { new Compat.CustomScript(), new Compat.CustomEmulator(), new Compat.Innoextract(), new Compat.WineWrap(), new Compat.DOSBox(), new Compat.ScummVM(), new Compat.RetroArch() };
			foreach(var appid in Compat.Proton.APPIDS)
			{
				tools += new Compat.Proton(appid);
			}

			string[] wine_binaries = { "wine"/*, "wine64", "wine32"*/ };
			string[] wine_arches = { "win64", "win32" };

			foreach(var wine_binary in wine_binaries)
			{
				foreach(var wine_arch in wine_arches)
				{
					if(wine_binary == "wine32" && wine_arch == "win64") continue;
					tools += new Compat.Wine(wine_binary, wine_arch);
				}
			}

			CompatTools = tools;

			weak IconTheme default_theme = IconTheme.get_default();
			default_theme.add_resource_path("/com/github/tkashkin/gamehub/icons");

			var provider = new CssProvider();
			provider.load_from_resource("/com/github/tkashkin/gamehub/GameHub.css");
			StyleContext.add_provider_for_screen(Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
		}

		protected override void activate()
		{
			info("Distro: %s", Utils.get_distro());

			if(main_window == null)
			{
				init();

				#if MANETTE
				GameHub.Utils.Gamepad.init();
				#endif

				main_window = new GameHub.UI.Windows.MainWindow(this);
				main_window.show_all();
			}
		}

		public static int main(string[] args)
		{
			#if MANETTE
			X.init_threads();
			#endif

			var app = new Application();

			var lang = Environment.get_variable("LC_ALL") ?? "";
			Intl.setlocale(LocaleCategory.ALL, lang);
			Intl.bindtextdomain(ProjectConfig.GETTEXT_PACKAGE, ProjectConfig.GETTEXT_DIR);
			Intl.textdomain(ProjectConfig.GETTEXT_PACKAGE);

			return app.run(args);
		}

		public override int command_line(ApplicationCommandLine cmd)
		{
			init();

			string[] oargs = cmd.get_arguments();
			unowned string[] args = oargs;

			string? opt_run = null;
			bool opt_show_compat = false;
			bool opt_show = false;

			OptionEntry[] options = new OptionEntry[4];
			options[0] = { "run", 'r', 0, OptionArg.STRING, out opt_run, _("Run game"), null };
			options[1] = { "show-compat", 'c', 0, OptionArg.NONE, out opt_show_compat, _("Show compatibility options dialog"), null };
			options[2] = { "show", 's', 0, OptionArg.NONE, out opt_show, _("Show main window"), null };
			options[3] = { null };

			var ctx = new OptionContext();
			ctx.add_main_entries(options, null);
			try
			{
				ctx.parse(ref args);
			}
			catch(Error e)
			{
				warning(e.message);
			}

			Granite.Services.Logger.DisplayLevel = Granite.Services.LogLevel.INFO;
			set_options();

			if(opt_show || opt_run == null)
			{
				activate();
				main_window.present();
			}

			if(opt_run != null)
			{
				opt_run = opt_run.strip();
				if(opt_run.length > 0 && ":" in opt_run)
				{
					var id_parts = opt_run.split(":");
					var game = GameHub.Data.DB.Tables.Games.get(id_parts[0], id_parts[1]);
					if(game != null)
					{
						info("Starting `%s`", game.name);

						var loop = new MainLoop();
						game.update_game_info.begin((obj, res) => {
							game.update_game_info.end(res);
							run_game.begin(game, opt_show_compat, (obj, res) => {
								run_game.end(res);
								info("`%s` finished", game.name);
								loop.quit();
							});
						});
						loop.run();
					}
					else
					{
						error("Game with id `%s` from source `%s` is not found", id_parts[1], id_parts[0]);
					}
				}
				else
				{
					error("`%s` is not a fully-qualified game id", opt_run);
				}
			}

			return 0;
		}

		private async void run_game(Game game, bool show_compat)
		{
			if(game.status.state == Game.State.INSTALLED)
			{
				if(game.use_compat)
				{
					yield game.run_with_compat(show_compat);
				}
				else
				{
					yield game.run();
				}
			}
			else if(game.status.state == Game.State.UNINSTALLED)
			{
				yield game.install();
			}
		}
	}
}
