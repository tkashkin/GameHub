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
		public Installer? installer;

		public Emulator.empty(){}

		public Emulator(string name, File dir, File exec, string args, string? compat=null)
		{
			this.name = name;

			install_dir = dir;

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
			executable = FSUtils.file(Tables.Emulators.EXECUTABLE.get(s));
			compat_tool = Tables.Emulators.COMPAT_TOOL.get(s);
			compat_tool_settings = Tables.Emulators.COMPAT_TOOL_SETTINGS.get(s);
			arguments = Tables.Emulators.ARGUMENTS.get(s);

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

		public override async void install()
		{
			update_status();

			if(installer == null || install_dir == null) return;

			var installers = new ArrayList<Runnable.Installer>();
			installers.add(installer);

			var wnd = new GameHub.UI.Dialogs.InstallDialog(this, installers);

			wnd.cancelled.connect(() => Idle.add(install.callback));

			wnd.install.connect((installer, dl_only, tool) => {
				installer.install.begin(this, dl_only, tool, (obj, res) => {
					installer.install.end(res);
					Idle.add(install.callback);
				});
			});

			wnd.show_all();
			wnd.present();

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
				var args = arguments.split(" ");
				foreach(var arg in args)
				{
					if(arg == "$game_args")
					{
						if(game != null)
						{
							var game_args = game.arguments.split(" ");
							foreach(var game_arg in game_args)
							{
								result_args += game_arg;
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

			return result_args;
		}

		public override async void run()
		{
			if(!RunnableIsLaunched && executable.query_exists())
			{
				RunnableIsLaunched = is_running = true;

				yield Utils.run_thread(get_args(null, executable), executable.get_parent().get_path(), null, true);

				RunnableIsLaunched = is_running = false;
			}
		}

		public async void run_game(Game? game, bool launch_in_game_dir=false)
		{
			if(use_compat)
			{
				yield run_game_compat(game, launch_in_game_dir);
				return;
			}

			if(executable.query_exists())
			{
				RunnableIsLaunched = is_running = true;

				if(game != null)
				{
					game.is_running = true;
					game.update_status();
				}

				var dir = game != null && launch_in_game_dir ? game.install_dir : install_dir;
				yield Utils.run_thread(get_args(game, executable), dir.get_path(), null, true);
				RunnableIsLaunched = is_running = false;

				if(game != null)
				{
					game.is_running = false;
					game.update_status();
				}
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

		public class Installer: Runnable.Installer
		{
			private string emu_name;
			public override string name { get { return emu_name; } }

			public Installer(Emulator emu, File installer)
			{
				emu_name = emu.name;
				id = "installer";
				platform = installer.get_path().has_suffix(".exe") ? Platform.WINDOWS : Platform.LINUX;
				parts.add(new Runnable.Installer.Part("installer", installer.get_uri(), full_size, installer, installer));
			}
		}
	}
}
