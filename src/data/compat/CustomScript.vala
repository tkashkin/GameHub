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
using GameHub.Data.Runnables;
using GameHub.Data.Tweaks;

using GameHub.Data.Sources.Steam;

namespace GameHub.Data.Compat
{
	public class CustomScript: CompatTool
	{
		public const string SCRIPT = "customscript.sh";
		private const string SCRIPT_TEMPLATE = """#!/bin/bash

# Environment variables passed by GameHub:
# ${GH_EXECUTABLE}        - path to game executable file
# ${GH_INSTALL_DIR}       - path to game installation directory
# ${GH_WORK_DIR}          - path to game working directory
# ${GH_GAME_ID}           - game id
# ${GH_GAME_ID_FULL}      - full game id (with source)
# ${GH_GAME_NAME}         - game name
# ${GH_GAME_NAME_ESCAPED} - escaped game name

""";
		private const string EMU_SCRIPT_TEMPLATE = """#!/bin/bash

# Environment variables passed by GameHub:
# ${GH_EMU_EXECUTABLE}    - path to emulator executable file
# ${GH_EMU_INSTALL_DIR}   - path to emulator installation directory
# ${GH_EMU_WORK_DIR}      - path to emulator working directory
# ${GH_EMU_ID}            - emulator id
# ${GH_EMU_NAME}          - emulator name
# ${GH_GAME_EXECUTABLE}   - path to game executable file
# ${GH_GAME_INSTALL_DIR}  - path to game installation directory
# ${GH_GAME_WORK_DIR}     - path to game working directory
# ${GH_GAME_ID}           - game id
# ${GH_GAME_ID_FULL}      - full game id (with source)
# ${GH_GAME_NAME}         - game name
# ${GH_GAME_NAME_ESCAPED} - escaped game name

""";

		construct
		{
			id = @"customscript";
			name = @"Custom script";
			icon = "application-x-executable-symbolic";
			installed = true;

			actions = {
				new CompatTool.Action(_("Edit script"), _("Edit custom script"), edit_script)
			};
		}

		public override bool can_run(Traits.SupportsCompatTools runnable)
		{
			return true;
		}

		public override async void run(Traits.SupportsCompatTools runnable)
		{
			if(runnable.install_dir == null || !runnable.install_dir.query_exists()) return;
			var gh_dir = FS.mkdir(runnable.install_dir.get_path(), FS.GAMEHUB_DIR);
			var script = gh_dir.get_child(SCRIPT);
			if(script.query_exists())
			{
				var task = Utils.exec({ script.get_path() }).dir(runnable.install_dir.get_path());

				runnable.cast<Game>(game => {
					task.env_var("GH_INSTALL_DIR", game.install_dir.get_path())
						.env_var("GH_GAME_ID", game.id)
						.env_var("GH_GAME_ID_FULL", game.full_id)
						.env_var("GH_GAME_NAME", game.name)
						.env_var("GH_GAME_NAME_ESCAPED", game.name_escaped);

					game.cast<Traits.HasExecutableFile>(game => {
						task.env_var("GH_EXECUTABLE", game.executable.get_path())
							.env_var("GH_WORK_DIR", game.work_dir.get_path());
					});
				});

				/*runnable.cast<Emulator>(emu => {
					task.env_var("GH_EMU_EXECUTABLE", emu.executable.get_path())
						.env_var("GH_EMU_INSTALL_DIR", emu.install_dir.get_path())
						.env_var("GH_EMU_WORK_DIR", emu.work_dir.get_path())
						.env_var("GH_EMU_ID", emu.id)
						.env_var("GH_EMU_NAME", emu.name);
				});*/

				runnable.cast<Traits.Game.SupportsTweaks>(game => {
					task.tweaks(game.get_enabled_tweaks(this));
				});
				yield task.sync_thread();
			}
			else
			{
				edit_script(runnable);
			}
		}

		/*public override async void run_emulator(Emulator emu, Game? game, bool launch_in_game_dir=false)
		{
			if(emu.install_dir == null || !emu.install_dir.query_exists()) return;
			var gh_dir = FS.mkdir(emu.install_dir.get_path(), FS.GAMEHUB_DIR);
			var script = gh_dir.get_child(SCRIPT);
			if(script.query_exists())
			{
				Utils.exec({"chmod", "+x", script.get_path()}).sync();
				var executable_path = emu.executable != null ? emu.executable.get_path() : "null";
				var game_executable_path = game != null && game.executable != null ? game.executable.get_path() : "null";
				string[] cmd = { script.get_path(), executable_path, emu.id, emu.name, game_executable_path, game.id, game.full_id, game.name, game.escaped_name };
				var dir = game != null && launch_in_game_dir ? game.work_dir : emu.work_dir;

				var task = Utils.exec(cmd).dir(dir.get_path());
				runnable.cast<Traits.Game.SupportsTweaks>(game => {
					task.tweaks(game.get_enabled_tweaks(this));
				});
				yield task.sync_thread();
			}
			else
			{
				edit_script(emu);
			}
		}*/

		public void edit_script(Traits.SupportsCompatTools runnable)
		{
			if(runnable.install_dir == null || !runnable.install_dir.query_exists()) return;
			var gh_dir = FS.mkdir(runnable.install_dir.get_path(), FS.GAMEHUB_DIR);
			var script = gh_dir.get_child(SCRIPT);
			if(!script.query_exists())
			{
				try
				{
					var template = /*runnable is Emulator ? EMU_SCRIPT_TEMPLATE :*/ SCRIPT_TEMPLATE;
					FileUtils.set_contents(script.get_path(), template, template.length);
				}
				catch(Error e)
				{
					warning("[CustomScript.edit_script] %s", e.message);
				}
			}
			Utils.exec({"chmod", "+x", script.get_path()}).sync();
			Utils.open_uri(script.get_uri());
		}
	}
}
