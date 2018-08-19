using GameHub.Utils;

namespace GameHub.Data
{
	public abstract class Game: Object
	{
		public GameSource source { get; protected set; }
		
		public string id { get; protected set; }
		public string name { get; protected set; }
		public string description { get; protected set; }
		
		public string icon { get; protected set; }
		public string image { get; protected set; }
		
		public string custom_info { get; protected set; default = ""; }
		
		public File executable { get; protected set; }
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
			set { _status = value; status_change(_status); }
		}

		public abstract class Installer
		{
			public string id { get; protected set; }
			public string os { get; protected set; }
			public string file { get; protected set; }
			public int64 file_size { get; protected set; }
			
			public virtual string name { get { return id; } }

			public async void install(Game game, File remote, File local)
			{
				try
				{
					game.status = new Game.Status(Game.State.DOWNLOADING, null);
					var ds_id = Downloader.get_instance().download_started.connect(dl => {
						if(dl.remote != remote) return;
						game.status = new Game.Status(Game.State.DOWNLOADING, dl);
						dl.status_change.connect(s => {
							game.status_change(game.status);
						});
					});

					var file = yield Downloader.download(remote, local);

					Downloader.get_instance().disconnect(ds_id);

					var path = file.get_path();
					Utils.run({"chmod", "+x", path});

					FSUtils.mkdir(game.install_dir.get_path());

					var info = file.query_info(FileAttribute.STANDARD_CONTENT_TYPE, FileQueryInfoFlags.NONE);
					var type = info.get_content_type();

					string[] cmd = {"xdg-open", path}; // unknown type, just open

					switch(type)
					{
						case "application/x-executable":
						case "application/x-elf":
						case "application/x-sh":
						case "application/x-shellscript":
							cmd = {path, "--", "--i-agree-to-all-licenses",
									"--noreadme", "--nooptions", "--noprompt",
									"--destination", game.install_dir.get_path()}; // probably mojosetup
							break;

						case "application/zip":
						case "application/x-tar":
						case "application/x-gtar":
						case "application/x-cpio":
						case "application/x-bzip2":
						case "application/gzip":
						case "application/x-lzip":
						case "application/x-lzma":
						case "application/x-7z-compressed":
						case "application/x-rar-compressed":
							cmd = {"file-roller", path, "-e", game.install_dir.get_path()}; // extract with file-roller
							break;
					}

					game.status = new Game.Status(Game.State.INSTALLING);

					yield Utils.run_async(cmd, null, false, true);

					Utils.run({"chmod", "-R", "+x", game.install_dir.get_path()});

					try
					{
						string? dirname = null;
						FileInfo? finfo = null;
						var enumerator = yield game.install_dir.enumerate_children_async("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
						while((finfo = enumerator.next_file()) != null)
						{
							if(dirname == null)
							{
								dirname = finfo.get_name();
							}
							else
							{
								dirname = null;
							}
						}

						if(dirname != null)
						{
							Utils.run({"bash", "-c", "mv " + dirname + "/* " + dirname + "/.* ."}, game.install_dir.get_path());
							FSUtils.rm(game.install_dir.get_path(), dirname, "-rf");
						}
					}
					catch(Error e){}

					game.status = new Game.Status(game.executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
				}
				catch(IOError.CANCELLED e){}
				catch(Error e)
				{
					warning(e.message);
				}
			}
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
