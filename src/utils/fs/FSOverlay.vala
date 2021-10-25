/*
This file is part of GameHub.
Copyright (C) Anatoliy Kashkin

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

namespace GameHub.Utils.FS
{
	public class FSOverlay: Object
	{
		private const string POLKIT_ACTION = Config.RDNN + ".polkit.overlayfs-helper";
		private const string POLKIT_HELPER = Config.BINDIR + "/" + Config.RDNN + "-overlayfs-helper";
		private const string[] MOUNT_OPTIONS_TO_COMPARE = {"lowerdir", "upperdir", "workdir"};
		private static Permission? permission;

		public string          id       { get; construct set; }
		public File            target   { get; construct set; }
		public ArrayList<File> overlays { get; construct set; }
		public File?           persist  { get; construct set; }
		public File?           workdir  { get; construct set; }

		public string full_id { owned get { return "%s_overlay_%s".printf(Config.RDNN, id); } }

		public FSOverlay(File target, ArrayList<File> overlays, File? persist=null, File? workdir=null)
		{
			Object(
				id: Utils.md5(target.get_path()),
				target: target, overlays: overlays, persist: persist, workdir: workdir
			);
		}

		construct
		{
			if(persist != null && workdir == null)
			{
				workdir = FS.file(persist.get_parent().get_path(), ".gh." + persist.get_basename() + ".overlay_workdir");
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

				options_arr += "index=off,lowerdir=" + string.joinv(":", overlay_dirs);

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
			try
			{
				if(!target.query_exists()) target.make_directory_with_parents();
			}
			catch(Error e)
			{
				warning("[FSOverlay.mount] Error while creating target directory: %s", e.message);
			}

			yield polkit_authenticate();

			debug("[FSOverlay.mount] Mounting overlay %s", id);
			yield Utils.exec({"pkexec", POLKIT_HELPER, "mount", full_id, options, target.get_path()}).log(GameHub.Application.log_verbose).sync_thread();
		}

		public async void umount()
		{
			yield polkit_authenticate();

			debug("[FSOverlay.umount] Unmounting overlay %s", id);

			while(full_id in (yield Utils.exec({"mount"}).log(false).sync_thread(true)).output)
			{
				yield Utils.exec({"pkexec", POLKIT_HELPER, "umount", full_id}).log(GameHub.Application.log_verbose).sync_thread();
				yield Utils.sleep_async(500);
			}

			if(workdir != null && !workdir.query_exists())
			{
				FS.rm(workdir.get_path(), null, "-rf");
			}
		}

		public async void remount()
		{
			var mounted = false;
			var mount_options_changed = false;

			var mounts_json = (yield Utils.exec({"findmnt", "-t", "overlay", "--source", full_id, "--output=SOURCE,TARGET,OPTIONS", "--json"}).log(false).sync_thread(true)).output;
			var mounts_node = Parser.parse_json(mounts_json);

			if(mounts_node != null && mounts_node.get_node_type() == Json.NodeType.OBJECT)
			{
				var mounts_obj = mounts_node.get_object();
				if(mounts_obj.has_member("filesystems"))
				{
					var mounts = mounts_obj.get_array_member("filesystems").get_elements();
					foreach(var mount_node in mounts)
					{
						var mount_obj = mount_node.get_object();
						var mount_source = mount_obj.get_string_member("source");
						var mount_target = mount_obj.get_string_member("target");
						var mount_options = mount_obj.get_string_member("options");
						if(mount_source == full_id && mount_target == target.get_path() && mount_options.length > 0)
						{
							mounted = true;
							var current_options = mount_options.split(",");
							var new_options = options.split(",");
							foreach(var opt_name in MOUNT_OPTIONS_TO_COMPARE)
							{
								foreach(var current_option in current_options)
								{
									if(current_option.has_prefix(opt_name))
									{
										foreach(var new_option in new_options)
										{
											if(new_option.has_prefix(opt_name) && new_option != current_option)
											{
												mount_options_changed = true;
												break;
											}
										}
									}
									if(mount_options_changed) break;
								}
								if(mount_options_changed) break;
							}
						}
					}
				}
			}

			if(mount_options_changed)
			{
				debug("[FSOverlay.remount] Mount options for overlay %s changed", id);
				yield umount();
				mounted = false;
			}
			if(!mounted)
			{
				yield mount();
			}
		}

		private async void polkit_authenticate()
		{
			#if POLKIT
			if(permission == null)
			{
				try
				{
					permission = yield new Polkit.Permission(POLKIT_ACTION, null);
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
			#endif
		}

		public enum RootPathSafety
		{
			SAFE, UNSAFE, RESTRICTED;

			private const string[] ALLOWED_PATHS = { "/home/", "/mnt/", "/media/", "/run/media/", "/opt/", "/var/opt/" };

			public static RootPathSafety for(File? root)
			{
				if(root == null || !root.query_exists()) return RESTRICTED;
				var path = root.get_path().down();

				var allowed = false;
				foreach(var prefix in ALLOWED_PATHS)
				{
					if(path.has_prefix(prefix))
					{
						allowed = true;
						break;
					}
				}

				if(!allowed)
				{
					return RESTRICTED;
				}

				string[] safe_paths = {};

				foreach(var src in GameHub.Data.GameSources)
				{
					var src_dirs = src.game_dirs;
					if(src_dirs != null)
					{
						foreach(var dir in src_dirs)
						{
							if(dir != null && dir.query_exists())
							{
								safe_paths += dir.get_path().down();
							}
						}
					}
				}

				foreach(var safe_path in safe_paths)
				{
					if(path.has_prefix(safe_path))
					{
						return SAFE;
					}
				}

				return UNSAFE;
			}
		}
	}
}
