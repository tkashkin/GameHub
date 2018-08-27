using Gee;

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
		
		public string? info { get; protected set; }
		public string? info_detailed { get; protected set; }

		public ArrayList<Platform> platforms { get; protected set; default = new ArrayList<Platform>(); }
		public virtual bool is_supported(Platform? platform=null)
		{
			if(platform == null) platform = CurrentPlatform;
			return platform in platforms;
		}

		public ArrayList<GamesDB.Tables.Tags.Tag> tags { get; protected set; default = new ArrayList<GamesDB.Tables.Tags.Tag>(GamesDB.Tables.Tags.Tag.is_equal); }

		public bool is_installable { get; protected set; default = false; }
		
		public File executable { get; protected set; }
		public File install_dir { get; protected set; }
		public string? store_page { get; protected set; default = null; }

		public abstract async void install();
		public abstract async void run();
		public abstract async void uninstall();
		
		public virtual async void update_game_info(){}

		protected Game.Status _status = new Game.Status();
		public signal void status_change(Game.Status status);

		public Game.Status status
		{
			get { return _status; }
			set { _status = value; status_change(_status); }
		}

		public virtual string installation_dir_name
		{
			owned get
			{
				return name.escape().replace(" ", "_").replace(":", "");
			}
		}

		public static bool is_equal(Game first, Game second)
		{
			return first == second || (first.source == second.source && first.id == second.id);
		}

		public static uint hash(Game game)
		{
			return str_hash(@"$(game.source.name)/$(game.id)");
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

					var info = new Downloader.DownloadInfo(game.name, game.icon, null, null, game.source.icon);

					var file = yield Downloader.download(remote, local, info);

					Downloader.get_instance().disconnect(ds_id);

					var path = file.get_path();
					Utils.run({"chmod", "+x", path});

					FSUtils.mkdir(game.install_dir.get_path());

					var type = yield guess_type(file);

					string[] cmd = {"xdg-open", path}; // unknown type, just open

					switch(type)
					{
						case InstallerType.EXECUTABLE:
							cmd = {path, "--", "--i-agree-to-all-licenses",
									"--noreadme", "--nooptions", "--noprompt",
									"--destination", game.install_dir.get_path().replace("'", "\\'")}; // probably mojosetup
							break;

						case InstallerType.ARCHIVE:
							cmd = {"file-roller", path, "-e", game.install_dir.get_path()}; // extract with file-roller
							break;
					}

					game.status = new Game.Status(Game.State.INSTALLING);

					yield Utils.run_async(cmd, null, false, true);

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

					Utils.run({"chmod", "-R", "+x", game.install_dir.get_path()});
				}
				catch(IOError.CANCELLED e){}
				catch(Error e)
				{
					warning(e.message);
				}
				game.status = new Game.Status(game.executable.query_exists() ? Game.State.INSTALLED : Game.State.UNINSTALLED);
			}

			private static async InstallerType guess_type(File file)
			{
				var type = InstallerType.UNKNOWN;

				try
				{
					var finfo = yield file.query_info_async(FileAttribute.STANDARD_CONTENT_TYPE, FileQueryInfoFlags.NONE);
					var mime = finfo.get_content_type();
					type = InstallerType.from_mime(mime);

					if(type != InstallerType.UNKNOWN) return type;

					var info = yield Utils.run_thread({"file", "-bi", file.get_path()});
					if(info != null && info.length > 0)
					{
						mime = info.split(";")[0];
						if(mime != null && mime.length > 0)
						{
							type = InstallerType.from_mime(mime);
						}
					}

					if(type != InstallerType.UNKNOWN) return type;

					string[] exe_ext = {"sh", "elf", "bin", "run"};
					string[] arc_ext = {"zip", "tar", "cpio", "bz2", "gz", "lz", "lzma", "7z", "rar"};

					foreach(var ext in exe_ext)
					{
						if(file.get_basename().has_suffix(@".$(ext)")) return InstallerType.EXECUTABLE;
					}
					foreach(var ext in arc_ext)
					{
						if(file.get_basename().has_suffix(@".$(ext)")) return InstallerType.ARCHIVE;
					}
				}
				catch(Error e){}

				return type;
			}

			private enum InstallerType
			{
				UNKNOWN, EXECUTABLE, ARCHIVE;

				public static InstallerType from_mime(string type)
				{
					switch(type.strip())
					{
						case "application/x-executable":
						case "application/x-elf":
						case "application/x-sh":
						case "application/x-shellscript":
							return InstallerType.EXECUTABLE;

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
						case "application/x-compressed-tar":
							return InstallerType.ARCHIVE;
					}
					return InstallerType.UNKNOWN;
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

	public enum Platform
	{
		LINUX, WINDOWS, MACOS;

		public string id()
		{
			switch(this)
			{
				case Platform.LINUX: return "linux";
				case Platform.WINDOWS: return "windows";
				case Platform.MACOS: return "mac";
			}
			assert_not_reached();
		}

		public string name()
		{
			switch(this)
			{
				case Platform.LINUX: return "Linux";
				case Platform.WINDOWS: return "Windows";
				case Platform.MACOS: return "macOS";
			}
			assert_not_reached();
		}

		public string icon()
		{
			switch(this)
			{
				case Platform.LINUX: return "platform-linux-symbolic";
				case Platform.WINDOWS: return "platform-windows-symbolic";
				case Platform.MACOS: return "platform-macos-symbolic";
			}
			assert_not_reached();
		}
	}
	public static Platform[] Platforms;
	public static Platform CurrentPlatform;
}
