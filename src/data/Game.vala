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
		public bool is_installable { get; protected set; default = false; }

		public string? store_page { get; protected set; default = null; }

		public int64 last_launch { get; protected set; default = 0; }

		public abstract async void install();
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

		public abstract class Installer
		{
			public class Part: Object
			{
				public string id     { get; construct set; }
				public string url    { get; construct set; }
				public int64  size   { get; construct set; }
				public File   remote { get; construct set; }
				public File   local  { get; construct set; }
				public Part(string id, string url, int64 size, File remote, File local)
				{
					Object(id: id, url: url, size: size, remote: remote, local: local);
				}
			}

			public string   id           { get; protected set; }
			public Platform platform     { get; protected set; default = CurrentPlatform; }
			public ArrayList<Part> parts { get; protected set; default = new ArrayList<Part>(); }
			public int64    full_size    { get; protected set; default = 0; }

			public virtual string  name  { get { return id; } }

			public async void install(Game game, bool dl_only, CompatTool? tool=null)
			{
				try
				{
					game.status = new Game.Status(Game.State.DOWNLOADING, null);

					var files = new ArrayList<File>();

					uint p = 1;
					foreach(var part in parts)
					{
						var ds_id = Downloader.get_instance().download_started.connect(dl => {
							if(dl.remote != part.remote) return;
							game.status = new Game.Status(Game.State.DOWNLOADING, dl);
							dl.status_change.connect(s => {
								game.status_change(game.status);
							});
						});

						var partDesc = "";

						if(parts.size > 1)
						{
							partDesc = _("Part %u of %u: ").printf(p, parts.size);
						}

						var info = new Downloader.DownloadInfo(game.name, partDesc + part.id, game.icon, null, null, game.source.icon);
						files.add(yield Downloader.download(part.remote, part.local, info));
						Downloader.get_instance().disconnect(ds_id);

						p++;
					}

					game.status = new Game.Status(Game.State.UNINSTALLED);
					game.update_status();

					if(dl_only) return;

					uint f = 0;
					bool windows_installer = false;
					foreach(var file in files)
					{
						var path = file.get_path();
						Utils.run({"chmod", "+x", path});

						FSUtils.mkdir(game.install_dir.get_path());

						var type = yield guess_type(file, f > 0);

						string[]? cmd = null;

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

							case InstallerType.WINDOWS_EXECUTABLE:
							case InstallerType.GOG_PART:
								cmd = null; // use compattool later
								break;

							default:
								cmd = {"xdg-open", path}; // unknown type, just open
								break;
						}

						game.status = new Game.Status(Game.State.INSTALLING);

						if(cmd != null)
						{
							yield Utils.run_async(cmd, null, null, false, true);
						}
						if(type == InstallerType.WINDOWS_EXECUTABLE)
						{
							windows_installer = true;
							if(tool != null && tool.can_install(game))
							{
								yield tool.install(game, file);
							}
						}
						f++;
					}

					try
					{
						string? dirname = null;
						FileInfo? finfo = null;
						var enumerator = yield game.install_dir.enumerate_children_async("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
						while((finfo = enumerator.next_file()) != null)
						{
							if(windows_installer && tool is Compat.Innoextract)
							{
								dirname = "app";
								if(finfo.get_name() != "app")
								{
									FSUtils.rm(game.install_dir.get_path(), finfo.get_name(), "-rf");
								}
								continue;
							}
							if(dirname == null)
							{
								dirname = finfo.get_name();
							}
							else
							{
								dirname = null;
							}
						}

						if(dirname != null && dirname != CompatTool.COMPAT_DATA_DIR)
						{
							Utils.run({"bash", "-c", "mv " + dirname + "/* " + dirname + "/.* ."}, game.install_dir.get_path());
							FSUtils.rm(game.install_dir.get_path(), dirname, "-rf");
						}

						if(windows_installer || platform == Platform.WINDOWS)
						{
							game.force_compat = true;
						}
					}
					catch(Error e){}

					Utils.run({"chmod", "-R", "+x", game.install_dir.get_path()});

					if(!game.executable.query_exists())
					{
						game.choose_executable();
					}
				}
				catch(IOError.CANCELLED e){}
				catch(Error e)
				{
					warning(e.message);
				}
				game.update_status();
			}

			public static async InstallerType guess_type(File file, bool part=false)
			{
				var type = InstallerType.UNKNOWN;
				if(file == null) return type;

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

					string[] gog_part_ext = {"bin"};
					string[] exe_ext = {"sh", "elf", "bin", "run"};
					string[] win_exe_ext = {"exe"};
					string[] arc_ext = {"zip", "tar", "cpio", "bz2", "gz", "lz", "lzma", "7z", "rar"};

					if(part)
					{
						foreach(var ext in gog_part_ext)
						{
							if(file.get_basename().has_suffix(@".$(ext)")) return InstallerType.GOG_PART;
						}
					}

					foreach(var ext in exe_ext)
					{
						if(file.get_basename().has_suffix(@".$(ext)")) return InstallerType.EXECUTABLE;
					}
					foreach(var ext in win_exe_ext)
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

			public enum InstallerType
			{
				UNKNOWN, EXECUTABLE, WINDOWS_EXECUTABLE, GOG_PART, ARCHIVE;

				public static InstallerType from_mime(string type)
				{
					switch(type.strip())
					{
						case "application/x-executable":
						case "application/x-elf":
						case "application/x-sh":
						case "application/x-shellscript":
							return InstallerType.EXECUTABLE;

						case "application/x-dosexec":
						case "application/x-ms-dos-executable":
						case "application/dos-exe":
						case "application/exe":
						case "application/msdos-windows":
						case "application/x-exe":
						case "application/x-msdownload":
						case "application/x-winexe":
							return InstallerType.WINDOWS_EXECUTABLE;

						case "application/octet-stream":
							return InstallerType.GOG_PART;

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
