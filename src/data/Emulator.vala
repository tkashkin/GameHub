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
using GameHub.Data.DB;
using GameHub.Utils;

namespace GameHub.Data
{
	public class Emulator: Runnable
	{
		private bool is_removed = false;
		public signal void removed();

		public override File? executable { owned get; set; }
		public override File? work_dir { owned get; set; }
		public Installer? installer;

		public string? game_executable_pattern { get; set; }
		public string? game_image_pattern { get; set; }
		public string? game_icon_pattern { get; set; }

		public Emulator.empty(){}

		public Emulator(string name, File dir, File exec, string args, string? compat=null)
		{
			this.name = name;

			install_dir = dir;
			work_dir = dir;

			executable = exec;
			arguments = args;

			compat_tool = compat;
			force_compat = compat != null;

			update_status();
		}

		public Emulator.from_db(Sqlite.Statement s)
		{
			id = Tables.Emulators.ID.get(s);
			name = Tables.Emulators.NAME.get(s);
			install_dir = FSUtils.file(Tables.Emulators.INSTALL_PATH.get(s));
			work_dir = FSUtils.file(Tables.Emulators.WORK_DIR.get(s));
			executable = FSUtils.file(Tables.Emulators.EXECUTABLE.get(s));
			compat_tool = Tables.Emulators.COMPAT_TOOL.get(s);
			compat_tool_settings = Tables.Emulators.COMPAT_TOOL_SETTINGS.get(s);
			arguments = Tables.Emulators.ARGUMENTS.get(s);
			game_executable_pattern = Tables.Emulators.GAME_EXECUTABLE_PATTERN.get(s);
			game_image_pattern = Tables.Emulators.GAME_IMAGE_PATTERN.get(s);
			game_icon_pattern = Tables.Emulators.GAME_ICON_PATTERN.get(s);

			update_status();
		}

		public void remove()
		{
			is_removed = true;
			Tables.Emulators.remove(this);
			removed();
		}

		public override void save()
		{
			update_status();

			if(is_removed || name == null || executable == null) return;

			Tables.Emulators.add(this);
		}

		public override void update_status()
		{
			if(is_removed || name == null || executable == null) return;

			id = Utils.md5(name);

			platforms.clear();
			platforms.add(Platform.LINUX);
		}

		public override async void install(Runnable.Installer.InstallMode install_mode=Runnable.Installer.InstallMode.INTERACTIVE)
		{
			update_status();
			if(installer == null || install_dir == null) return;
			var installers = new ArrayList<Runnable.Installer>();
			installers.add(installer);
			new GameHub.UI.Dialogs.InstallDialog(this, installers, install_mode, install.callback);
			yield;
		}

		public string[] get_args(Game? game=null, File? exec=null)
		{
			string[] result_args = {};

			if(exec != null)
			{
				result_args += exec.get_path();
			}

			if(arguments != null && arguments.length > 0)
			{
				var variables = new HashMap<string, string>();
				variables.set("emu", name.replace(": ", " - ").replace(":", ""));
				variables.set("emu_dir", install_dir.get_path());
				if(game != null)
				{
					variables.set("game", game.name.replace(": ", " - ").replace(":", ""));
					variables.set("file", game.executable.get_path());
					variables.set("game_dir", game.install_dir.get_path());
				}
				else
				{
					variables.set("game", "");
					variables.set("file", "");
					variables.set("game_dir", "");
				}
				var args = Utils.parse_args(arguments);
				if(args != null)
				{
					if(exec != null && ("$command" in args || "${command}" in args))
					{
						result_args = {};
						variables.set("command", exec.get_path());
					}
					foreach(var arg in args)
					{
						if(arg == "$game_args" || arg == "${game_args}")
						{
							if(game != null)
							{
								var game_args = Utils.parse_args(game.arguments);
								if(game_args != null)
								{
									foreach(var game_arg in game_args)
									{
										result_args += game_arg;
									}
								}
							}
							continue;
						}
						if("$" in arg)
						{
							arg = FSUtils.expand(arg, null, variables);
						}
						result_args += arg;
					}
				}
			}

			return result_args;
		}

		public override async void run() throws Utils.RunError
		{
			if(can_be_launched(true) && executable.query_exists())
			{
				Runnable.IsLaunched = is_running = true;

				yield Utils.run(get_args(null, executable)).dir(work_dir.get_path()).override_runtime(true).run_sync_thread();

				Timeout.add_seconds(1, () => {
					Runnable.IsLaunched = is_running = false;
					return Source.REMOVE;
				});
			}
		}

		public async void run_game(Game? game, bool launch_in_game_dir=false) throws Utils.RunError
		{
			if(use_compat)
			{
				yield run_game_compat(game, launch_in_game_dir);
				return;
			}

			if(executable.query_exists())
			{
				Runnable.IsLaunched = is_running = true;

				if(game != null)
				{
					game.is_running = true;
					game.update_status();
				}

				var dir = game != null && launch_in_game_dir ? game.work_dir : work_dir;

				var task = Utils.run(get_args(game, executable)).dir(dir.get_path()).override_runtime(true);
				if(game != null && game is TweakableGame)
				{
					task.tweaks(((TweakableGame) game).get_enabled_tweaks());
				}
				yield task.run_sync_thread();

				Timeout.add_seconds(1, () => {
					Runnable.IsLaunched = is_running = false;
					if(game != null)
					{
						game.is_running = false;
						game.update_status();
					}
					return Source.REMOVE;
				});
			}
		}

		public async void run_game_compat(Game? game, bool launch_in_game_dir=false)
		{
			new UI.Dialogs.CompatRunDialog(this, false, game, launch_in_game_dir);
		}

		public static bool is_equal(Emulator first, Emulator second)
		{
			return first == second || first.id == second.id;
		}

		public static uint hash(Emulator emu)
		{
			return str_hash(emu.id);
		}

		public class Installer: Runnable.FileInstaller
		{
			private string emu_name;
			public override string name { owned get { return emu_name; } }

			public Installer(Emulator emu, File installer)
			{
				emu_name = emu.name;
				id = "installer";
				platform = installer.get_path().down().has_suffix(".exe") ? Platform.WINDOWS : Platform.LINUX;
				file = installer;
			}
		}
	}
}
