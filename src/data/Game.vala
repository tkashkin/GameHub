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
using Gtk;

using GameHub.Utils;
using GameHub.Data.DB;

namespace GameHub.Data
{
	public abstract class Game: Runnable
	{
		public GameSource source { get; protected set; }

		public string description { get; protected set; }

		public string icon { get; set; }
		public string image { get; set; }

		public string? info { get; protected set; }
		public string? info_detailed { get; protected set; }

		public string full_id { owned get { return source.id + ":" + id; } }

		public string? version { get; protected set; }

		public ArrayList<Tables.Tags.Tag> tags { get; protected set; default = new ArrayList<Tables.Tags.Tag>(Tables.Tags.Tag.is_equal); }
		public bool has_tag(Tables.Tags.Tag tag)
		{
			return has_tag_id(tag.id);
		}
		public bool has_tag_id(string tag)
		{
			foreach(var t in tags)
			{
				if(t.id == tag) return true;
			}
			return false;
		}
		public void add_tag(Tables.Tags.Tag tag)
		{
			if(!tags.contains(tag))
			{
				tags.add(tag);
			}
			if(!(tag in Tables.Tags.DYNAMIC_TAGS))
			{
				save();
				status_change(_status);
				tags_update();
			}
		}
		public void remove_tag(Tables.Tags.Tag tag)
		{
			if(tags.contains(tag))
			{
				tags.remove(tag);
			}
			if(!(tag in Tables.Tags.DYNAMIC_TAGS))
			{
				save();
				status_change(_status);
				tags_update();
			}
		}
		public void toggle_tag(Tables.Tags.Tag tag)
		{
			if(tags.contains(tag))
			{
				remove_tag(tag);
			}
			else
			{
				add_tag(tag);
			}
		}

		public override void save()
		{
			Tables.Games.add(this);
		}

		public File? installers_dir { get; protected set; default = null; }
		public bool is_installable { get; protected set; default = true; }

		public string? store_page { get; protected set; default = null; }

		public int64 last_launch { get; set; default = 0; }

		public abstract async void uninstall();

		public override async void run()
		{
			if(!RunnableIsLaunched && executable.query_exists())
			{
				RunnableIsLaunched = is_running = true;
				update_status();

				string[] cmd = { executable.get_path() };

				if(arguments != null && arguments.length > 0)
				{
					var variables = new HashMap<string, string>();
					variables.set("game", name.replace(": ", " - ").replace(":", ""));
					variables.set("game_dir", install_dir.get_path());
					var args = arguments.split(" ");
					foreach(var arg in args)
					{
						if("$" in arg)
						{
							arg = FSUtils.expand(arg, null, variables);
						}
						cmd += arg;
					}
				}

				last_launch = get_real_time() / 1000000;
				save();
				yield Utils.run_thread(cmd, executable.get_parent().get_path(), null, true);
				playtime_tracked += ((get_real_time() / 1000000) - last_launch) / 60;
				save();

				RunnableIsLaunched = is_running = false;
				update_status();
			}
		}

		public virtual async void update_game_info(){}

		protected void update_version()
		{
			if(install_dir == null || !install_dir.query_exists()) return;

			var file = install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("version");
			if(file != null && file.query_exists())
			{
				try
				{
					string ver;
					FileUtils.get_contents(file.get_path(), out ver);
					version = ver;
				}
				catch(Error e)
				{
					warning("[Game.update_version] Error while reading version: %s", e.message);
				}
			}
		}

		public void save_version(string ver)
		{
			version = ver;

			if(install_dir == null || !install_dir.query_exists()) return;

			var file = install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("version");
			if(file != null)
			{
				try
				{
					FSUtils.mkdir(file.get_parent().get_path());
					FileUtils.set_contents(file.get_path(), ver);
				}
				catch(Error e)
				{
					warning("[Game.update_version] Error while reading version: %s", e.message);
				}
			}
		}

		protected Game.Status _status = new Game.Status(Game.State.UNINSTALLED, null, null);
		public signal void status_change(Game.Status status);
		public signal void tags_update();

		public Game.Status status
		{
			get { return _status; }
			set { _status = value; status_change(_status); }
		}

		public int64 playtime_source  { get; set; default = 0; }
		public int64 playtime_tracked { get; set; default = 0; }

		public int64 playtime { get { return playtime_source + playtime_tracked; } }

		public ArrayList<Overlay> overlays = new ArrayList<Overlay>();
		private FSOverlay? fs_overlay;
		private string? fs_overlay_last_options;

		public File? get_file(string? p, bool from_all_overlays=true)
		{
			if(p == null || p.length == 0 || install_dir == null) return null;
			var path = p;
			if(!path.has_prefix("$game_dir/") && !path.has_prefix("/"))
			{
				path = "$game_dir/" + path;
			}
			File[] dirs = { install_dir };
			if(overlays_enabled)
			{
				dirs = { install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("_overlay").get_child("merged") };
				if(from_all_overlays)
				{
					dirs += install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(Overlay.BASE);
				}
				dirs += install_dir;
				mount_overlays();
			}
			foreach(var dir in dirs)
			{
				var variables = new HashMap<string, string>();
				variables.set("game_dir", dir.get_path());
				var file = FSUtils.file(path, null, variables);
				if(file != null && file.query_exists())
				{
					return file;
				}
			}
			return null;
		}

		public string? executable_path;
		public override File? executable
		{
			owned get
			{
				if(executable_path == null || executable_path.length == 0 || install_dir == null) return null;
				return get_file(executable_path);
			}
			set
			{
				if(value != null && value.query_exists())
				{
					File[] dirs = { install_dir };
					if(overlays_enabled)
					{
						dirs = {
							install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("_overlay").get_child("merged"),
							install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(Overlay.BASE),
							install_dir
						};
					}
					foreach(var dir in dirs)
					{
						if(value.get_path().has_prefix(dir.get_path()))
						{
							executable_path = value.get_path().replace(dir.get_path(), "$game_dir");
							break;
						}
					}
				}
				else
				{
					executable_path = null;
				}
				save();
			}
		}

		public bool overlays_enabled
		{
			get
			{
				if(this is Sources.Steam.SteamGame) return false;
				return install_dir != null && install_dir.query_exists()
					&& install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(FSUtils.OVERLAYS_LIST).query_exists();
			}
		}

		public void enable_overlays()
		{
			if(this is Sources.Steam.SteamGame || install_dir == null || !install_dir.query_exists() || overlays_enabled) return;

			var base_overlay = new Overlay(this);

			try
			{
				FileInfo? finfo = null;
				var enumerator = install_dir.enumerate_children("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				while((finfo = enumerator.next_file()) != null)
				{
					var fname = finfo.get_name();
					if(fname == FSUtils.GAMEHUB_DIR) continue;
					install_dir.get_child(fname).move(base_overlay.directory.get_child(fname), FileCopyFlags.OVERWRITE | FileCopyFlags.NOFOLLOW_SYMLINKS);
				}
			}
			catch(Error e)
			{
				warning("[Game.enable_overlays] Error while moving game files to `base` overlay: %s", e.message);
			}

			overlays.add(base_overlay);
			save_overlays();
			save();
		}

		public void save_overlays()
		{
			var file = install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(FSUtils.OVERLAYS_LIST);

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

			notify_property("overlays-enabled");
		}

		public void load_overlays()
		{
			if(!overlays_enabled) return;
			overlays.clear();
			overlays.add(new Overlay(this));

			var root_node = Parser.parse_json_file(install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(FSUtils.OVERLAYS_LIST).get_path());

			var overlays_obj = Parser.json_object(root_node, {"overlays"});
			if(overlays_obj == null) return;

			foreach(var id in overlays_obj.get_members())
			{
				var obj = overlays_obj.get_object_member(id);
				overlays.add(new Overlay(this, id, obj.get_string_member("name"), obj.get_boolean_member("enabled")));
			}
		}

		public void mount_overlays(File? persist=null)
		{
			if(!overlays_enabled) return;
			load_overlays();

			var overlay_dir = install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("_overlay");
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
				fs_overlay.mount.begin();
			}
			fs_overlay_last_options = fs_overlay.options;
		}

		public async void umount_overlays()
		{
			if(!overlays_enabled || fs_overlay == null) return;
			yield fs_overlay.umount();
		}

		public ArrayList<Achievement>? achievements { get; protected set; default = null; }
		public virtual async ArrayList<Achievement>? load_achievements() { return null; }

		public static bool is_equal(Game first, Game second)
		{
			return first == second || (first.source == second.source && first.id == second.id);
		}

		public static uint hash(Game game)
		{
			return str_hash(game.full_id);
		}

		public class Overlay: Object
		{
			public const string BASE = "base";

			public Game   game    { get; construct; }

			public string id      { get; construct; }
			public string name    { get; construct; }
			public bool   enabled { get; set; }

			public File?  directory;

			public Overlay(Game game, string id=BASE, string? name=null, bool enabled=true)
			{
				Object(game: game, id: id, name: name ?? (id == BASE ? game.name : id));
				this.enabled = id == BASE || enabled;
			}

			construct
			{
				if(game is Sources.Steam.SteamGame || game.install_dir == null || !game.install_dir.query_exists()) return;

				directory = FSUtils.mkdir(game.install_dir.get_child(FSUtils.GAMEHUB_DIR)
								.get_child(FSUtils.OVERLAYS_DIR).get_child(id).get_path());
			}
		}

		public class Status
		{
			public Game.State state;
			public Game? game;
			public Downloader.Download? download;

			public Status(Game.State state, Game? game=null, Downloader.Download? download=null)
			{
				this.state = state;
				this.game = game;
				this.download = download;
			}

			public string description
			{
				owned get
				{
					if(game != null && game.is_running) return C_("status", "Running");
					switch(state)
					{
						case Game.State.INSTALLED: return C_("status", "Installed") + (game != null && game.version != null ? @" ($(game.version))" : "");
						case Game.State.INSTALLING: return C_("status", "Installing");
						case Game.State.VERIFYING_INSTALLER_INTEGRITY: return C_("status", "Verifying installer integrity");
						case Game.State.DOWNLOADING: return download != null ? download.status.description : C_("status", "Download started");
					}
					return C_("status", "Not installed");
				}
			}

			public string header
			{
				owned get
				{
					switch(state)
					{
						case Game.State.INSTALLED: return C_("status_header", "Installed");
						case Game.State.INSTALLING: return C_("status_header", "Installing");
						case Game.State.VERIFYING_INSTALLER_INTEGRITY:
						case Game.State.DOWNLOADING: return C_("status_header", "Downloading");
					}
					return C_("status_header", "Not installed");
				}
			}
		}

		public enum State
		{
			UNINSTALLED, INSTALLED, DOWNLOADING, VERIFYING_INSTALLER_INTEGRITY, INSTALLING;
		}

		public abstract class Achievement
		{
			public string    id                { get; protected set; }
			public string    name              { get; protected set; }
			public string    description       { get; protected set; }
			public bool      unlocked          { get; protected set; default = false; }
			public DateTime? unlock_date       { get; protected set; }
			public string?   unlock_time       { get; protected set; }
			public float     global_percentage { get; protected set; default = 0; }
			public string?   image_locked      { get; protected set; }
			public string?   image_unlocked    { get; protected set; }
			public string?   image             { get { return unlocked ? image_unlocked : image_locked; } }
		}
	}
}
