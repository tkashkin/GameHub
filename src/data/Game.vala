using Gtk;

namespace GameHub.Data
{
	public abstract class Game
	{
		public GameSource source { get; protected set; }
		
		public string id { get; protected set; }
		public string name { get; protected set; }
		public string description { get; protected set; }
		
		public string icon { get; protected set; }
		public string image { get; protected set; }
		
		public string custom_info { get; protected set; default = ""; }
		
		public File install_dir { get; protected set; }
		public string? store_page { get; protected set; default = null; }

		public virtual async bool is_for_linux(){ return true; }
		
		public virtual bool is_installed(){ return false; }
		
		public abstract async void install(Utils.DownloadProgress progress = (d, t) => {});
		public abstract async void run();
		
		public virtual async void update_game_info(){}

		public static bool is_equal(Game first, Game second)
		{
			return first == second || (first.source == second.source && first.id == second.id);
		}
		
		protected Game.Status _status = new Game.Status();
		public signal void status_change(Game.Status status);

		public Game.Status status
		{
			get { return _status; }
			protected set { _status = value; status_change(_status); }
		}

		public abstract class Installer
		{
			public string id { get; protected set; }
			public string os { get; protected set; }
			public string file { get; protected set; }
			
			public virtual string name { get { return id; } }
		}

		public class Status
		{
			public Game.State state;

			public int64 dl_bytes;
			public int64 dl_bytes_total;

			public Status(Game.State state=Game.State.UNINSTALLED, int64 dl_bytes = -1, int64 dl_bytes_total = -1)
			{
				this.state = state;
				this.dl_bytes = dl_bytes;
				this.dl_bytes_total = dl_bytes_total;
			}

			public string description
			{
				owned get
				{
					switch(state)
					{
						case INSTALLED: return _("Installed");
						case INSTALLING: return _("Installing");
						case DOWNLOAD_STARTED: return _("Download started");
						case DOWNLOAD_FINISHED: return _("Download finished");
						case DOWNLOADING:
							var fraction = (double) dl_bytes / dl_bytes_total;
							return _("Downloading: %d%% (%s / %s)").printf((int)(fraction * 100), format_size(dl_bytes), format_size(dl_bytes_total));
					}
					return _("Not installed");
				}
			}
		}

		public enum State
		{
			UNINSTALLED, INSTALLED, DOWNLOAD_STARTED, DOWNLOADING, DOWNLOAD_FINISHED, INSTALLING;
		}
	}
}
