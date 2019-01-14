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
	public class Application: Gtk.Application
	{
		public static Application instance;

		public static bool log_auth = false;
		public static bool log_downloader = false;
		public static bool log_workers = false;

		private GameHub.UI.Windows.MainWindow? main_window;

		public const string ACTION_PREFIX = "app.";
		public const string ACTION_SETTINGS = "settings";
		public const string ACTION_INSTALLER_SHOW = "installer.show";
		public const string ACTION_INSTALLER_BACKUP = "installer.backup";
		public const string ACTION_INSTALLER_REMOVE = "installer.remove";

		private const GLib.ActionEntry[] action_entries = {
			{ ACTION_SETTINGS, action_settings },
			{ ACTION_INSTALLER_SHOW,   action_installer, "s" },
			{ ACTION_INSTALLER_BACKUP, action_installer, "s" },
			{ ACTION_INSTALLER_REMOVE, action_installer, "s" }
		};

		construct
		{
			application_id = ProjectConfig.PROJECT_NAME;
			flags = ApplicationFlags.HANDLES_COMMAND_LINE;
			instance = this;
			add_action_entries(action_entries, this);
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
			print_version(false);

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

			Utils.Logger.initialize("GameHub");

			var lang = Environment.get_variable("LC_ALL") ?? "";
			Intl.setlocale(LocaleCategory.ALL, lang);
			Intl.bindtextdomain(ProjectConfig.GETTEXT_PACKAGE, ProjectConfig.GETTEXT_DIR);
			Intl.textdomain(ProjectConfig.GETTEXT_PACKAGE);

			return app.run(args);
		}

		public override int command_line(ApplicationCommandLine cmd)
		{
			string[] oargs = cmd.get_arguments();
			unowned string[] args = oargs;

			bool opt_debug_log = false;

			bool opt_show_version = false;
			string? opt_run = null;
			bool opt_show_compat = false;
			bool opt_show = false;
			bool opt_gdb = false;

			OptionEntry[] options = new OptionEntry[6];
			options[0] = { "version", 'v', 0, OptionArg.NONE, out opt_show_version, _("Show application version and exit"), null };
			options[1] = { "run", 'r', 0, OptionArg.STRING, out opt_run, _("Run game"), null };
			options[2] = { "show-compat", 'c', 0, OptionArg.NONE, out opt_show_compat, _("Show compatibility options dialog"), null };
			options[3] = { "show", 's', 0, OptionArg.NONE, out opt_show, _("Show main window"), null };
			options[4] = { "gdb", 0, 0, OptionArg.NONE, out opt_gdb, _("Restart with GDB debugger attached"), null };
			options[5] = { null };

			OptionEntry[] options_log = new OptionEntry[5];
			options_log[0] = { "debug", 'd', 0, OptionArg.NONE, out opt_debug_log, _("Enable debug logging"), null };
			options_log[1] = { "log-auth", 0, 0, OptionArg.NONE, out log_auth, _("Log authentication process and sensitive information like authentication tokens"), null };
			options_log[2] = { "log-downloader", 0, 0, OptionArg.NONE, out log_downloader, _("Log download manager"), null };
			options_log[3] = { "log-workers", 0, 0, OptionArg.NONE, out log_workers, _("Log background workers start/stop"), null };
			options_log[4] = { null };

			var ctx = new OptionContext();

			var opt_group_log = new OptionGroup("log", _("Logging Options:"), _("Show logging options help"));
			opt_group_log.add_entries(options_log);

			ctx.add_main_entries((owned) options, null);
			ctx.add_group((owned) opt_group_log);

			try
			{
				ctx.parse(ref args);
			}
			catch(Error e)
			{
				warning(e.message);
			}

			if(opt_show_version)
			{
				print_version(true);
				return 0;
			}

			Granite.Services.Logger.DisplayLevel = opt_debug_log || opt_gdb ? Granite.Services.LogLevel.DEBUG : Granite.Services.LogLevel.INFO;

			if(opt_gdb)
			{
				string[] current_args = cmd.get_arguments();
				string[] cmd_args = {};
				for(int i = 1; i < current_args.length; i++)
				{
					var arg = current_args[i];
					if(arg != "--gdb")
					{
						cmd_args += arg;
					}
				}
				if(!("--debug" in cmd_args) && !("-d" in cmd_args))
				{
					cmd_args += "--debug";
				}
				string cmd_args_string = string.joinv(" ", cmd_args);
				string[] exec_cmd = { "xterm", "-geometry", "128x48", "-fa", "Monospace", "-fs", "12", "-e", "gdb", "-ex", @"set args $cmd_args_string", "-ex", "set pagination off", "-ex", "run", current_args[0] };
				info("Restarting with GDB");
				Utils.run_async.begin(exec_cmd, cmd.get_cwd());
				return 0;
			}

			init();

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

		[PrintfFormat]
		private void println(bool plain, string format, ...)
		{
			var line = format.vprintf(va_list());
			if(plain)
			{
				print(line + "\n");
			}
			else
			{
				info(line);
			}
		}

		private void print_version(bool plain)
		{
			println(plain, "Version: %s", ProjectConfig.VERSION);
			println(plain, "Branch:  %s", ProjectConfig.GIT_BRANCH);
			println(plain, "Commit:  %s (%s)", ProjectConfig.GIT_COMMIT_SHORT, ProjectConfig.GIT_COMMIT);
			println(plain, "Distro:  %s", Utils.get_distro());
			println(plain, "DE:      %s", Utils.get_desktop_environment() ?? "unknown");
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

		private static void action_settings(SimpleAction action, Variant? args)
		{
			new UI.Dialogs.SettingsDialog.SettingsDialog();
		}

		private static void action_installer(SimpleAction action, Variant? path)
		{
			var file = FSUtils.file(path.get_string());
			if(file == null || !file.query_exists()) return;
			try
			{
				switch(action.name)
				{
					case ACTION_INSTALLER_SHOW:
						Utils.open_uri(file.get_parent().get_uri());
						break;

					case ACTION_INSTALLER_BACKUP:
						file.move(FSUtils.file(path.get_string() + ".backup"), FileCopyFlags.BACKUP);
						break;

					case ACTION_INSTALLER_REMOVE:
						file.delete();
						break;
				}
			}
			catch(Error e)
			{
				warning("[app.installer_action] %s", e.message);
			}
		}
	}
}
