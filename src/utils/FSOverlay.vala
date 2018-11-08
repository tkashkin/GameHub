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

using GLib;
using Gee;

namespace GameHub.Utils
{
	public class FSOverlay: Object
	{
		public const string POLKIT_ACTION_MOUNT  = ProjectConfig.PROJECT_NAME + ".polkit.overlayfs.mount";
		public const string POLKIT_ACTION_UMOUNT = ProjectConfig.PROJECT_NAME + ".polkit.overlayfs.umount";

		private static Permission? permission_mount;
		private static Permission? permission_umount;

		public string          id       { get; construct set; }
		public File            target   { get; construct set; }
		public ArrayList<File> overlays { get; construct set; }
		public File?           persist  { get; construct set; }
		public File?           workdir  { get; construct set; }

		public FSOverlay(File target, ArrayList<File> overlays, File? persist=null, File? workdir=null)
		{
			Object(
				id: ProjectConfig.PROJECT_NAME + "_overlay_" + Utils.md5(target.get_path()),
				target: target, overlays: overlays, persist: persist, workdir: workdir
			);
		}

		construct
		{
			if(persist != null && workdir == null)
			{
				workdir = FSUtils.file(persist.get_parent().get_path(), ".gh." + persist.get_basename() + ".overlay_workdir");
			}
		}

		private string? _options;
		public string options
		{
			get
			{
				if(_options != null) return _options;

				string[] options_arr = {};

				string[] overlay_dirs = {};

				for(var i = overlays.size - 1; i >= 0; i--)
				{
					overlay_dirs += overlays.get(i).get_path();
				}

				options_arr += "lowerdir=" + string.joinv(":", overlay_dirs);

				if(persist != null && workdir != null)
				{
					options_arr += "upperdir=" + persist.get_path();
					options_arr += "workdir=" + workdir.get_path();
					try
					{
						if(!persist.query_exists()) persist.make_directory_with_parents();
						if(!workdir.query_exists()) workdir.make_directory_with_parents();
					}
					catch(Error e)
					{
						warning("[FSOverlay.mount] Error while creating directories: %s", e.message);
					}
				}

				_options = string.joinv(",", options_arr);
				return _options;
			}
		}

		public async void mount()
		{
			yield umount();

			try
			{
				if(!target.query_exists()) target.make_directory_with_parents();
			}
			catch(Error e)
			{
				warning("[FSOverlay.mount] Error while creating target directory: %s", e.message);
			}

			yield polkit_authenticate(POLKIT_ACTION_MOUNT);

			yield Utils.run_thread({"pkexec", "mount", "-t", "overlay", id, "-o", options, target.get_path()});
		}

		public async void umount()
		{
			yield polkit_authenticate(POLKIT_ACTION_UMOUNT);

			while(id in (yield Utils.run_thread({"mount"}, null, null, false, false)))
			{
				yield Utils.run_thread({"pkexec", "umount", id});
				yield Utils.sleep_async(500);
			}

			if(workdir != null && !workdir.query_exists())
			{
				FSUtils.rm(workdir.get_path(), null, "-rf");
			}
		}

		private async void polkit_authenticate(string action=POLKIT_ACTION_MOUNT)
		{
			var permission = permission_mount;

			switch(action)
			{
				case POLKIT_ACTION_MOUNT:  permission = permission_mount;  break;
				case POLKIT_ACTION_UMOUNT: permission = permission_umount; break;
			}

			if(permission == null)
			{
				try
				{
					permission = yield new Polkit.Permission(action, null);
				}
				catch(Error e)
				{
					warning("[FSOverlay.polkit_authenticate] %s", e.message);
				}
			}

			if(permission != null && !permission.allowed && permission.can_acquire)
			{
				try
				{
					yield permission.acquire_async();
				}
				catch(Error e)
				{
					warning("[FSOverlay.polkit_authenticate] %s", e.message);
				}
			}

			switch(action)
			{
				case POLKIT_ACTION_MOUNT:  permission_mount  = permission; break;
				case POLKIT_ACTION_UMOUNT: permission_umount = permission; break;
			}
		}
	}
}
