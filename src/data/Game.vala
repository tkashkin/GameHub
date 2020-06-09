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
using Gtk;

using GameHub.Utils;
using GameHub.Data.DB;
using GameHub.Data.Tweaks;

namespace GameHub.Data
{
	public abstract class Game: Runnable
	{
		public GameSource source { get; protected set; }

		public string description { get; protected set; }

		public string? icon { get; set; }
		public string? image { get; set; }
		public string? image_vertical { get; set; }

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

		public abstract async void uninstall() throws Utils.RunError;

		public override async void run() throws Utils.RunError
		{
			if(can_be_launched(true) && executable.query_exists())
			{
				Runnable.IsLaunched = is_running = true;
				update_status();

				string[] cmd = { executable.get_path() };

				if(arguments != null && arguments.length > 0)
				{
					var variables = new HashMap<string, string>();
					variables.set("game", name.replace(": ", " - ").replace(":", ""));
					variables.set("game_dir", install_dir.get_path());
					var args = Utils.parse_args(arguments);
					if(args != null)
					{
						if("$command" in args || "${command}" in args)
						{
							cmd = {};
							variables.set("command", executable.get_path());
						}
						foreach(var arg in args)
						{
							if("$" in arg)
							{
								arg = FSUtils.expand(arg, null, variables);
							}
							cmd += arg;
						}
					}
				}

				last_launch = get_real_time() / 1000000;
				save();

				var task = Utils.run(cmd).dir(work_dir.get_path()).override_runtime(true);
				if(this is TweakableGame)
				{
					task.tweaks(((TweakableGame) this).get_enabled_tweaks());
				}
				yield task.run_sync_thread();

				playtime_tracked += ((get_real_time() / 1000000) - last_launch) / 60;
				save();

				Timeout.add_seconds(1, () => {
					Runnable.IsLaunched = is_running = false;
					update_status();
					return Source.REMOVE;
				});
			}
		}

		public async void run_or_install(bool show_compat=false) throws Utils.RunError
		{
			if(status.state == Game.State.INSTALLED)
			{
				if(use_compat)
				{
					yield run_with_compat(show_compat);
				}
				else
				{
					yield run();
				}
			}
			else if(status.state == Game.State.UNINSTALLED)
			{
				yield install();
			}
		}

		public virtual async void update_game_info() throws Utils.RunError {}

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
				if(from_all_overlays)
				{
					dirs = {
						install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("_overlay").get_child("merged"),
						install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(Overlay.BASE),
						install_dir
					};
					foreach(var overlay in overlays)
					{
						if(overlay.id == Overlay.BASE) continue;
						dirs += install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(overlay.id);
					}
				}
				mount_overlays.begin();
			}
			var variables = new HashMap<string, string>();
			foreach(var dir in dirs)
			{
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
				if(value != null && value.query_exists() && install_dir != null && install_dir.query_exists())
				{
					File[] dirs = { install_dir };
					if(overlays_enabled)
					{
						dirs = {
							install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("_overlay").get_child("merged"),
							install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(Overlay.BASE),
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

		public string? work_dir_path;
		public override File? work_dir
		{
			owned get
			{
				if(install_dir == null) return null;
				if(work_dir_path == null || work_dir_path.length == 0) return install_dir;
				return get_file(work_dir_path);
			}
			set
			{
				if(value != null && value.query_exists() && install_dir != null && install_dir.query_exists())
				{
					File[] dirs = { install_dir };
					if(overlays_enabled)
					{
						dirs = {
							install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child("_overlay").get_child("merged"),
							install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(Overlay.BASE),
							install_dir
						};
					}
					foreach(var dir in dirs)
					{
						if(value.get_path().has_prefix(dir.get_path()))
						{
							work_dir_path = value.get_path().replace(dir.get_path(), "$game_dir/");
							break;
						}
					}
				}
				else
				{
					work_dir_path = null;
				}
				save();
			}
		}

		public bool overlays_enabled
		{
			get
			{
				if(this is Sources.GOG.GOGGame.DLC && ((Sources.GOG.GOGGame.DLC) this).game != null) return ((Sources.GOG.GOGGame.DLC) this).game.overlays_enabled;
				if(this is Sources.Steam.SteamGame) return false;
				if(FSOverlay.RootPathSafety.for(install_dir) == FSOverlay.RootPathSafety.RESTRICTED) return false;
				return install_dir != null && install_dir.query_exists()
					&& install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(FSUtils.OVERLAYS_LIST).query_exists();
			}
		}

		public void enable_overlays()
		{
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) ((Sources.GOG.GOGGame.DLC) this).game.enable_overlays();
				return;
			}

			if(this is Sources.Steam.SteamGame || install_dir == null || !install_dir.query_exists() || overlays_enabled) return;
			if(FSOverlay.RootPathSafety.for(install_dir) == FSOverlay.RootPathSafety.RESTRICTED) return;

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
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) ((Sources.GOG.GOGGame.DLC) this).game.save_overlays();
				return;
			}

			if(install_dir == null || !install_dir.query_exists() || overlays == null) return;
			if(FSOverlay.RootPathSafety.for(install_dir) == FSOverlay.RootPathSafety.RESTRICTED) return;

			var file = install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(FSUtils.OVERLAYS_LIST);

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

			notify_property("overlays-enabled");
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

			var root_node = Parser.parse_json_file(install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(FSUtils.OVERLAYS_LIST).get_path());

			var overlays_obj = Parser.json_object(root_node, {"overlays"});
			if(overlays_obj == null) return;

			foreach(var id in overlays_obj.get_members())
			{
				var obj = overlays_obj.get_object_member(id);
				overlays.add(new Overlay(this, id, obj.get_string_member("name"), obj.get_boolean_member("enabled")));
			}
		}

		public async void mount_overlays(File? persist=null) throws Utils.RunError
		{
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) yield ((Sources.GOG.GOGGame.DLC) this).game.mount_overlays(persist);
				return;
			}

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
				try
				{
					yield fs_overlay.mount();
					
					// Only remember this configuration after applying successfully
					fs_overlay_last_options = fs_overlay.options;
				}
				finally {}
			}
		}

		public async void umount_overlays() throws Utils.RunError
		{
			if(this is Sources.GOG.GOGGame.DLC)
			{
				if(((Sources.GOG.GOGGame.DLC) this).game != null) yield ((Sources.GOG.GOGGame.DLC) this).game.umount_overlays();
				return;
			}

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

			public Game game { get; construct; }

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

			public Overlay(Game game, string id=BASE, string? name=null, bool enabled=true)
			{
				Object(game: game, id: id, name: name ?? (id == BASE ? game.name : id));
				this.enabled = id == BASE || enabled;
			}

			construct
			{
				if(game is Sources.Steam.SteamGame || game.install_dir == null || !game.install_dir.query_exists()) return;

				directory = FSUtils.mkdir(game.install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(id).get_path());
			}

			public void remove()
			{
				if(!removable) return;

				game.umount_overlays.begin((obj, res) => {
					try {
						game.umount_overlays.end(res);
					} catch(RunError e) {
						warning("[Game.Overlay.remove] %s", e.message);
					}

					if(id != BASE)
					{
						if(directory != null && directory.query_exists())
						{
							FSUtils.rm(directory.get_path(), null, "-rf");
						}
						game.overlays.remove(this);
						game.save_overlays();
					}
					else
					{
						try
						{
							FSUtils.mv_up(game.install_dir, @"$(FSUtils.GAMEHUB_DIR)/$(FSUtils.OVERLAYS_DIR)/$(BASE)");
							game.overlays.clear();
							game.install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).get_child(FSUtils.OVERLAYS_LIST).delete();
							game.install_dir.get_child(FSUtils.GAMEHUB_DIR).get_child(FSUtils.OVERLAYS_DIR).delete();
							game.notify_property("overlays-enabled");
						}
						catch(Error e)
						{
							warning("[Game.Overlay.remove] %s", e.message);
						}
					}
				});
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
						case Game.State.INSTALLED: return C_("status", "Installed") + (game != null && game.version != null ? @": $(game.version)" : "");
						case Game.State.INSTALLING: return C_("status", "Installing");
						case Game.State.VERIFYING_INSTALLER_INTEGRITY: return C_("status", "Verifying installer integrity");
						case Game.State.DOWNLOADING: return download != null && download.status != null && download.status.description != null ? download.status.description : C_("status", "Download started");
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

	public interface TweakableGame: Game
	{
		public abstract string[]? tweaks { get; set; default = null; }

		public Tweak[] get_enabled_tweaks(CompatTool? tool=null)
		{
			Tweak[] enabled_tweaks = {};
			var all_tweaks = Tweak.load_tweaks();
			foreach(var tweak in all_tweaks.values)
			{
				if(tweak.is_enabled(this) && tweak.is_applicable_to(this, tool))
				{
					enabled_tweaks += tweak;
				}
			}
			return enabled_tweaks;
		}
	}
}
