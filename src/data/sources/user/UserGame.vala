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
using GameHub.Data.Runnables;
using GameHub.Data.Runnables.Tasks.Install;
using GameHub.Utils;
using GameHub.Utils.FS;

namespace GameHub.Data.Sources.User
{
	public class UserGame: Game,
		Traits.HasExecutableFile, Traits.SupportsCompatTools,
		Traits.Game.SupportsOverlays, Traits.Game.SupportsTweaks
	{
		// Traits.HasExecutableFile
		public override string? executable_path { owned get; set; }
		public override string? work_dir_path { owned get; set; }
		public override string? arguments { owned get; set; }

		// Traits.SupportsCompatTools
		public override string? compat_tool { get; set; }
		public override string? compat_tool_settings { get; set; }

		// Traits.Game.SupportsOverlays
		public override ArrayList<Traits.Game.SupportsOverlays.Overlay> overlays { get; set; default = new ArrayList<Traits.Game.SupportsOverlays.Overlay>(); }
		protected override FSOverlay? fs_overlay { get; set; }
		protected override string? fs_overlay_last_options { get; set; }

		// Traits.Game.SupportsTweaks
		public override string[]? tweaks { get; set; default = null; }

		private bool is_removed = false;
		public signal void removed();

		private Installer? installer;

		public UserGame(string name, File dir, File exec, string args, bool is_installer)
		{
			source = User.instance;

			this.id = Utils.md5(name + Random.next_int().to_string());
			this.name = name;

			platforms.clear();

			var path = exec.get_path().down();
			platforms.add(path.has_suffix(".exe") || path.has_suffix(".bat") || path.has_suffix(".com") ? Platform.WINDOWS : Platform.LINUX);

			install_dir = dir;
			work_dir = dir;

			arguments = args;

			if(!is_installer)
			{
				executable = exec;
			}
			else
			{
				installer = new Installer(this, exec);
				var root_object = new Json.Object();
				root_object.set_string_member("installer", exec.get_path());
				var root_node = new Json.Node(Json.NodeType.OBJECT);
				root_node.set_object(root_object);
				info = Json.to_string(root_node, false);
				save();
			}

			((User) source).add_game(this);

			mount_overlays.begin();
			update_status();
		}

		public UserGame.from_db(User src, Sqlite.Statement s)
		{
			source = src;

			dbinit(s);
			dbinit_executable(s);
			dbinit_compat(s);
			dbinit_tweaks(s);

			mount_overlays.begin();
			update_status();
		}

		public override async void update_game_info()
		{
			yield mount_overlays();
			update_status();

			if(installer == null && info != null && info.length > 0)
			{
				var i = Parser.parse_json(info).get_object();
				installer = new Installer(this, File.new_for_path(i.get_string_member("installer")));
			}

			save();
		}

		public override async void install(InstallTask.Mode install_mode=InstallTask.Mode.INTERACTIVE)
		{
			/*yield update_game_info();
			if(installer == null) return;
			var installers = new ArrayList<Runnable.Installer>();
			installers.add(installer);
			new GameHub.UI.Dialogs.InstallDialog(this, installers, install_mode, install.callback);
			yield;*/
		}

		public override async void uninstall()
		{
			yield umount_overlays();
			remove();
		}

		public void remove()
		{
			is_removed = true;
			((User) source).remove_game(this);
			removed();
		}

		public override void save()
		{
			if(!is_removed)
			{
				base.save();
			}
		}

		public override void update_status()
		{
			var exec = executable;
			status = new Game.Status(exec != null && exec.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED, this);
			if(status.state == Game.State.INSTALLED)
			{
				remove_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				add_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
			else
			{
				add_tag(Tables.Tags.BUILTIN_UNINSTALLED);
				remove_tag(Tables.Tags.BUILTIN_INSTALLED);
			}
		}

		public class Installer: FileInstaller
		{
			public Installer(UserGame game, File installer)
			{
				id = "installer";
				name = game.name;
				platform = installer.get_path().down().has_suffix(".exe") ? Platform.WINDOWS : Platform.LINUX;
				file = installer;
			}
		}
	}
}
