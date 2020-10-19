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

using GameHub.Data;
using GameHub.Data.Runnables;
using GameHub.Utils;
using GameHub.Utils.FS;

namespace GameHub.Data.Runnables.Traits.Game
{
	public interface SupportsOverlays: Runnables.Game
	{
		public signal void overlays_changed();

		public abstract ArrayList<Overlay> overlays { get; set; default = new ArrayList<Overlay>(); }
		protected abstract FSOverlay? fs_overlay { get; set; }
		protected abstract string? fs_overlay_last_options { get; set; }

		public bool overlays_enabled
		{
			get
			{
				if(this is Sources.GOG.GOGGame.DLC && ((Sources.GOG.GOGGame.DLC) this).game != null) return ((Sources.GOG.GOGGame.DLC) this).game.overlays_enabled;
				if(FSOverlay.RootPathSafety.for(install_dir) == FSOverlay.RootPathSafety.RESTRICTED) return false;
				return install_dir != null && install_dir.query_exists()
					&& install_dir.get_child(FS.GAMEHUB_DIR).get_child(FS.OVERLAYS_DIR).get_child(FS.OVERLAYS_LIST).query_exists();
			}
		}

		public File? merged_overlays_directory
		{
			owned get
			{
				if(overlays_enabled)
				{
					return install_dir.get_child(FS.GAMEHUB_DIR).get_child("_overlay").get_child("merged");
				}
				return null;
			}
		}

		public void enable_overlays()
		{
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) ((Sources.GOG.GOGGame.DLC) this).game.enable_overlays();
				return;
			}

			if(install_dir == null || !install_dir.query_exists() || overlays_enabled) return;
			if(FSOverlay.RootPathSafety.for(install_dir) == FSOverlay.RootPathSafety.RESTRICTED) return;

			var base_overlay = new Overlay(this);

			try
			{
				FileInfo? finfo = null;
				var enumerator = install_dir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				while((finfo = enumerator.next_file()) != null)
				{
					var fname = finfo.get_name();
					if(fname == FS.GAMEHUB_DIR) continue;
					install_dir.get_child(fname).move(base_overlay.directory.get_child(fname), FileCopyFlags.OVERWRITE | FileCopyFlags.NOFOLLOW_SYMLINKS);
				}
			}
			catch(Error e)
			{
				warning("[Traits.Game.SupportsOverlays.enable_overlays] Error while moving game files to `base` overlay: %s", e.message);
			}

			overlays.add(base_overlay);
			save_overlays();
			save();
			update_status();
		}

		public void save_overlays()
		{
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) ((Sources.GOG.GOGGame.DLC) this).game.save_overlays();
				return;
			}

			if(install_dir == null || !install_dir.query_exists() || overlays == null) return;
			if(FSOverlay.RootPathSafety.for(install_dir) == FSOverlay.RootPathSafety.RESTRICTED) return;

			var file = install_dir.get_child(FS.GAMEHUB_DIR).get_child(FS.OVERLAYS_DIR).get_child(FS.OVERLAYS_LIST);

			if(file == null || !file.get_parent().query_exists()) return;

			var root_node = new Json.Node(Json.NodeType.OBJECT);
			var root = new Json.Object();

			var overlays_obj = new Json.Object();

			foreach(var overlay in overlays)
			{
				if(overlay.id == Overlay.BASE) continue;
				var obj = new Json.Object();
				obj.set_string_member("name", overlay.name);
				obj.set_boolean_member("enabled", overlay.enabled);
				overlays_obj.set_object_member(overlay.id, obj);
			}

			root.set_object_member("overlays", overlays_obj);
			root_node.set_object(root);

			var json = Json.to_string(root_node, true);

			try
			{
				FileUtils.set_contents(file.get_path(), json);
			}
			catch(Error e)
			{
				warning("[Game.save_overlays] %s", e.message);
			}
			overlays_changed();
		}

		public void load_overlays()
		{
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) ((Sources.GOG.GOGGame.DLC) this).game.load_overlays();
				return;
			}

			if(!overlays_enabled) return;
			overlays.clear();
			overlays.add(new Overlay(this));

			var root_node = Parser.parse_json_file(install_dir.get_child(FS.GAMEHUB_DIR).get_child(FS.OVERLAYS_DIR).get_child(FS.OVERLAYS_LIST).get_path());

			var overlays_obj = Parser.json_object(root_node, {"overlays"});
			if(overlays_obj == null) return;

			foreach(var id in overlays_obj.get_members())
			{
				var obj = overlays_obj.get_object_member(id);
				overlays.add(new Overlay(this, id, obj.get_string_member("name"), obj.get_boolean_member("enabled")));
			}
		}

		public async void mount_overlays(File? persist=null)
		{
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) yield ((Sources.GOG.GOGGame.DLC) this).game.mount_overlays(persist);
				return;
			}

			if(!overlays_enabled) return;
			load_overlays();

			var overlay_dir = install_dir.get_child(FS.GAMEHUB_DIR).get_child("_overlay");
			var merged_dir  = overlay_dir.get_child("merged");
			var persist_dir = persist ?? overlay_dir.get_child("persist");
			var work_dir    = overlay_dir.get_child("workdir");

			var dirs = new ArrayList<File>();

			foreach(var overlay in overlays)
			{
				if(overlay.enabled)
				{
					dirs.add(overlay.directory);
				}
			}

			fs_overlay = new FSOverlay(merged_dir, dirs, persist_dir, work_dir);
			if(fs_overlay.options != fs_overlay_last_options)
			{
				fs_overlay_last_options = fs_overlay.options;
				yield fs_overlay.remount();
			}
		}

		public async void umount_overlays()
		{
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) yield ((Sources.GOG.GOGGame.DLC) this).game.umount_overlays();
				return;
			}
			if(!overlays_enabled || fs_overlay == null) return;
			yield fs_overlay.umount();
		}

		public async void remount_overlays()
		{
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) yield ((Sources.GOG.GOGGame.DLC) this).game.remount_overlays();
				return;
			}
			if(!overlays_enabled || fs_overlay == null) return;
			yield fs_overlay.remount();
		}

		public void get_file_search_paths_overlays(ArrayList<File?> paths)
		{
			if(overlays_enabled)
			{
				paths.add(merged_overlays_directory);
				paths.add(install_dir.get_child(FS.GAMEHUB_DIR).get_child(FS.OVERLAYS_DIR).get_child(Overlay.BASE));
				foreach(var overlay in overlays)
				{
					if(overlay.id == Overlay.BASE) continue;
					paths.add(install_dir.get_child(FS.GAMEHUB_DIR).get_child(FS.OVERLAYS_DIR).get_child(overlay.id));
				}
			}
		}

		public class Overlay: Object
		{
			public const string BASE = "base";

			public Traits.Game.SupportsOverlays game { get; construct; }

			public string id { get; construct; }
			public string name { get; construct; }
			public bool enabled { get; set; }

			public File? directory;

			public bool removable
			{
				get
				{
					if(id == BASE && game.overlays != null)
					{
						foreach(var overlay in game.overlays)
						{
							if(overlay.id != BASE) return false;
						}
					}
					return true;
				}
			}

			public Overlay(Traits.Game.SupportsOverlays game, string id=BASE, string? name=null, bool enabled=true)
			{
				Object(game: game, id: id, name: name ?? (id == BASE ? game.name : id));
				this.enabled = id == BASE || enabled;
			}

			construct
			{
				if(game.install_dir == null || !game.install_dir.query_exists()) return;
				directory = FS.mkdir(game.install_dir.get_child(FS.GAMEHUB_DIR).get_child(FS.OVERLAYS_DIR).get_child(id).get_path());
			}

			public void remove()
			{
				if(!removable) return;

				game.umount_overlays.begin((obj, res) => {
					game.umount_overlays.end(res);

					if(id != BASE)
					{
						if(directory != null && directory.query_exists())
						{
							FS.rm(directory.get_path(), null, "-rf");
						}
						game.overlays.remove(this);
						game.save_overlays();
					}
					else
					{
						try
						{
							FS.mv_up(game.install_dir, @"$(FS.GAMEHUB_DIR)/$(FS.OVERLAYS_DIR)/$(BASE)");
							game.overlays.clear();
							game.install_dir.get_child(FS.GAMEHUB_DIR).get_child(FS.OVERLAYS_DIR).get_child(FS.OVERLAYS_LIST).delete();
							game.install_dir.get_child(FS.GAMEHUB_DIR).get_child(FS.OVERLAYS_DIR).delete();
							game.overlays_changed();
							game.update_status();
						}
						catch(Error e)
						{
							warning("[Traits.Game.SupportsOverlays.Overlay.remove] %s", e.message);
						}
					}
				});
			}
		}
	}
}
