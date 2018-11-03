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
				RunnableIsLaunched = true;

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

				last_launch = get_real_time() / 1000;
				save();
				yield Utils.run_thread(cmd, executable.get_parent().get_path(), null, true);

				RunnableIsLaunched = false;
			}
		}

		public virtual async void update_game_info(){}

		protected Game.Status _status = new Game.Status();
		public signal void status_change(Game.Status status);
		public signal void tags_update();

		public Game.Status status
		{
			get { return _status; }
			set { _status = value; status_change(_status); }
		}

		public virtual string escaped_name
		{
			owned get
			{
				return Utils.strip_name(name.replace(" ", "_"), "_.,");
			}
		}

		public static bool is_equal(Game first, Game second)
		{
			return first == second || (first.source == second.source && first.id == second.id);
		}

		public static uint hash(Game game)
		{
			return str_hash(game.full_id);
		}

		public class Status
		{
			public Game.State state;

			public Downloader.Download? download;

			public Status(Game.State state=Game.State.UNINSTALLED, Downloader.Download? download=null)
			{
				this.state = state;
				this.download = download;
			}

			public string description
			{
				owned get
				{
					switch(state)
					{
						case Game.State.INSTALLED: return C_("status", "Installed");
						case Game.State.INSTALLING: return C_("status", "Installing");
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
						case Game.State.DOWNLOADING: return C_("status_header", "Downloading");
					}
					return C_("status_header", "Not installed");
				}
			}
		}

		public enum State
		{
			UNINSTALLED, INSTALLED, DOWNLOADING, INSTALLING;
		}
	}
}
