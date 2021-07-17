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

using GameHub.Data;
using GameHub.Data.DB;
using GameHub.Data.Runnables.Tasks.Install;

using GameHub.Utils;

namespace GameHub.Data.Runnables
{
	public abstract class Game: Runnable
	{
		// General properties

		public GameSource source { get; protected set; }
		public override string full_id { owned get { return @"$(source.id):$(id)"; } }

		public string? description { get; protected set; }

		public string? icon { get; set; }
		public string? image { get; set; }
		public string? image_vertical { get; set; }

		public string? info { get; protected set; }
		public string? info_detailed { get; protected set; }

		public string? store_page { get; protected set; default = null; }

		/**
		 * Last launch date in unix time
		 */
		public int64 last_launch { get; set; default = 0; }
		public int64 playtime_source { get; set; default = 0; }

		/**
		 * Tracked playtime in minutes
		 */
		public int64 playtime_tracked { get; set; default = 0; }
		public int64 playtime { get { return playtime_source + playtime_tracked; } }

		public Game.Status status { get; set; default = new Game.Status(Game.State.UNINSTALLED, null, null); }

		public ArrayList<Tables.Tags.Tag> tags { get; protected set; default = new ArrayList<Tables.Tags.Tag>(Tables.Tags.Tag.is_equal); }

		protected void dbinit(Sqlite.Statement s)
		{
			id = Tables.Games.ID.get(s);
			name = Tables.Games.NAME.get(s);

			icon = Tables.Games.ICON.get(s);
			image = Tables.Games.IMAGE.get(s);
			image_vertical = Tables.Games.IMAGE_VERTICAL.get(s);

			info = Tables.Games.INFO.get(s);
			info_detailed = Tables.Games.INFO_DETAILED.get(s);

			last_launch = Tables.Games.LAST_LAUNCH.get_int64(s);
			playtime_source = Tables.Games.PLAYTIME_SOURCE.get_int64(s);
			playtime_tracked = Tables.Games.PLAYTIME_TRACKED.get_int64(s);

			install_dir = Tables.Games.INSTALL_PATH.get(s) != null ? FS.file(Tables.Games.INSTALL_PATH.get(s)) : null;

			platforms.clear();
			var platform_ids = Tables.Games.PLATFORMS.get(s).split(",");
			foreach(var platform_id in platform_ids)
			{
				foreach(var platform in Platform.PLATFORMS)
				{
					if(platform_id == platform.id())
					{
						if(!platforms.contains(platform)) platforms.add(platform);
						break;
					}
				}
			}

			tags.clear();
			var tag_ids = (Tables.Games.TAGS.get(s) ?? "").split(",");
			foreach(var tag_id in tag_ids)
			{
				foreach(var tag in Tables.Tags.TAGS)
				{
					if(tag_id == tag.id)
					{
						if(!tags.contains(tag)) tags.add(tag);
						break;
					}
				}
			}
		}

		// Version

		private string? _version = null;
		public virtual string? version
		{
			get { return _version; }
			set
			{
				_version = value;
				if(install_dir == null || !install_dir.query_exists()) return;
				var file = get_file(@"$(FS.GAMEHUB_DIR)/version", false);
				try
				{
					FS.mkdir(file.get_parent().get_path());
					FileUtils.set_contents(file.get_path(), _version);
				}
				catch(Error e)
				{
					warning("[Game.version.set] Error while writing game version: %s", e.message);
				}
			}
		}

		protected virtual void load_version()
		{
			if(install_dir == null || !install_dir.query_exists()) return;
			var file = get_file(@"$(FS.GAMEHUB_DIR)/version");
			if(file != null)
			{
				try
				{
					string ver;
					FileUtils.get_contents(file.get_path(), out ver);
					version = ver;
				}
				catch(Error e)
				{
					warning("[Game.load_version] Error while reading game version: %s", e.message);
				}
			}
		}

		// Tags

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
				notify_property("tags");
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
				notify_property("tags");
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

		// Install

		public bool is_installable { get; protected set; default = true; }
		public ArrayList<Installer>? installers { get; protected set; default = null; }

		public virtual async ArrayList<Installer>? load_installers()
		{
			return installers;
		}

		public virtual async void install(InstallTask.Mode install_mode=InstallTask.Mode.INTERACTIVE)
		{
			if(status.state != Game.State.UNINSTALLED || !is_installable) return;
			var task = new InstallTask(this, installers, source.game_dirs, install_mode, true);
			yield task.start();
		}

		public virtual async void uninstall()
		{

		}

		public override void save()
		{
			Utils.thread("Game.save", () => {
				Tables.Games.add(this);
			});
		}

		public async void run_or_install(bool show_compat=false)
		{
			if(status.state == Game.State.INSTALLED)
			{
				var compat = cast<Traits.SupportsCompatTools>();
				if(compat != null && compat.use_compat)
				{
					yield compat.run_with_compat(show_compat);
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

		public virtual async void update_game_info(){}

		// Static functions

		public static new bool is_equal(Game first, Game second)
		{
			return first == second || first.full_id == second.full_id;
		}

		public static new uint hash(Game game)
		{
			return str_hash(game.full_id);
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
	}
}
