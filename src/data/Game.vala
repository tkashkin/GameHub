using Gtk;

using GameHub.Utils.Downloader;

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
		
		public abstract async void install();
		public abstract async void run();
		public abstract async void uninstall();
		
		public virtual async void update_game_info(){}

		public static bool is_equal(Game first, Game second)
		{
			return first == second || (first.source == second.source && first.id == second.id);
		}

		public static uint hash(Game game)
		{
			return str_hash(@"$(game.source.name)/$(game.id)");
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
			public int64 file_size { get; protected set; }
			
			public virtual string name { get { return id; } }
		}

		public class Status
		{
			public Game.State state;

			public Download? download;

			public Status(Game.State state=Game.State.UNINSTALLED, Download? download=null)
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
						case Game.State.INSTALLED: return _("Installed");
						case Game.State.INSTALLING: return _("Installing");
						case Game.State.DOWNLOADING: return download != null ? download.status.description : _("Download started");
					}
					return _("Not installed");
				}
			}

			public string header
			{
				owned get
				{
					switch(state)
					{
						case Game.State.INSTALLED: return _("Installed:");
						case Game.State.INSTALLING: return _("Installing:");
						case Game.State.DOWNLOADING: return _("Downloading:");
					}
					return _("Not installed:");
				}
			}
		}

		public enum State
		{
			UNINSTALLED, INSTALLED, DOWNLOADING, INSTALLING;
		}
	}
}
