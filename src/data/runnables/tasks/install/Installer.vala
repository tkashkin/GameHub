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
using GameHub.Utils;

namespace GameHub.Data.Runnables.Tasks.Install
{
	public abstract class Installer
	{
		public string   id            { get; protected set; }
		public string   name          { get; protected set; }
		public Platform platform      { get; protected set; default = Platform.CURRENT; }
		public int64    full_size     { get; protected set; default = 0; }
		public string?  version       { get; protected set; }
		public string?  language      { get; protected set; }
		public string?  language_name { get; protected set; }

		public bool is_installable
		{
			get
			{
				return platform == Platform.CURRENT || platform == Platform.WINDOWS;
			}
		}

		public abstract async bool install(InstallTask task);
	}

	public abstract class FileInstaller: Installer
	{
		public File? file { get; protected set; }

		public override async bool install(InstallTask task)
		{
			var result = yield install_file(task, file);
			task.finish();
			return result;
		}

		public static async bool install_file(InstallTask task, File? file, InstallerType? installer_type=null, bool can_be_data=false)
		{
			if(file == null || !file.query_exists()) return false;
			var type = installer_type ?? yield InstallerType.guess(file, can_be_data);

			var file_path = file.get_path();
			var install_dir_path = task.install_dir.get_path();

			string[]? cmd = null;

			switch(type)
			{
				case InstallerType.EXECUTABLE:
					cmd = { file_path, "--", "--i-agree-to-all-licenses", "--noreadme", "--nooptions", "--noprompt",
						"--destination", install_dir_path.replace("'", "\\'") }; // probably mojosetup
					break;

				case InstallerType.WINDOWS_EXECUTABLE:
					//return yield task.install_file_with_compat(file);
					break;

				case InstallerType.ARCHIVE:
				case InstallerType.WINDOWS_NSIS_INSTALLER:
					cmd = { "file-roller", file_path, "-e", install_dir_path }; // extract with file-roller
					break;

				case InstallerType.DATA:
					// do nothing
					break;

				default:
					cmd = { "xdg-open", file_path }; // unknown type, try to open
					break;
			}

			if(cmd != null)
			{
				try
				{
					return (yield Utils.run(cmd).run_async()).check_status();
				}
				catch(Error e)
				{
					warning("[FileInstaller.install_file] %s", e.message);
				}
				return false;
			}
			return true;
		}
	}

	public abstract class DownloadableInstaller: Installer
	{
		public class Part: Object
		{
			public string       id            { get; construct set; }
			public string       url           { get; construct set; }
			public int64        size          { get; construct set; }
			public File?        remote        { get; construct set; }
			public File?        local         { get; construct set; }
			public string?      checksum      { get; construct set; }
			public ChecksumType checksum_type { get; construct set; }

			public Part(string id, string url, int64 size, File remote, File local, string? checksum=null, ChecksumType checksum_type=ChecksumType.MD5)
			{
				Object(id: id, url: url, size: size, remote: remote, local: local, checksum: checksum, checksum_type: checksum_type);
			}

			public string? checksum_type_string
			{
				get
				{
					if(checksum == null || checksum.length == 0) return null;
					switch(checksum_type)
					{
						case ChecksumType.MD5: return "md5";
						case ChecksumType.SHA1: return "sha1";
						case ChecksumType.SHA256: return "sha256";
						case ChecksumType.SHA512: return "sha512";
					}
					return null;
				}
			}
		}

		public ArrayList<Part> parts { get; protected set; default = new ArrayList<Part>(); }
		public virtual async void fetch_parts(){}

		public override async bool install(InstallTask task)
		{
			try
			{
				var files = yield download(task);

				task.status = new InstallTask.Status();

				if(files.size == 0) return false;

				uint current_file = 0;
				InstallerType?[] types = {};
				foreach(var file in files)
				{
					var can_be_data = current_file++ > 0;
					var type = yield InstallerType.guess(file, can_be_data);
					yield FileInstaller.install_file(task, file, type, can_be_data);
					if(!(type in types)) types += type;
				}

				if(InstallerType.WINDOWS_NSIS_INSTALLER in types)
				{
					FS.rm(task.install_dir.get_path(), "\\$*DIR", "-rf"); // remove dirs like $PLUGINSDIR
				}

				int dircount = 0;
				string? dirname = null;
				FileInfo? finfo = null;
				var enumerator = yield task.install_dir.enumerate_children_async("standard::*", FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
				while((finfo = enumerator.next_file()) != null)
				{
					if(finfo.get_file_type() == FileType.DIRECTORY && finfo.get_name() != FS.GAMEHUB_DIR)
					{
						dircount++;
						dirname = dirname == null && dircount == 1 ? finfo.get_name() : null;
					}
					else if(finfo.get_file_type() != FileType.DIRECTORY)
					{
						dirname = null;
						break;
					}
				}

				if(dirname != null && !(task.runnable is GameHub.Data.Sources.GOG.GOGGame.DLC))
				{
					FS.mv_up(task.install_dir, dirname.replace(" ", "\\ "));
				}

				task.finish();
			}
			catch(Error e)
			{
				warning("[DownloadableInstaller.install] %s", e.message);
				return false;
			}
			task.status = new InstallTask.Status();
			return true;
		}

		public async ArrayList<File> download(InstallTask task)
		{
			var files = new ArrayList<File>();
			try
			{
				task.status = new InstallTask.Status(InstallTask.State.DOWNLOADING);

				uint current_part = 1;
				foreach(var part in parts)
				{
					FS.mkdir(part.local.get_parent().get_path());

					var ds_id = Downloader.download_manager().file_download_started.connect(dl => {
						if(dl.remote != part.remote) return;
						task.status = new InstallTask.Status(InstallTask.State.DOWNLOADING, dl);
						dl.status_change.connect(s => {
							task.notify_property("status");
						});
					});

					var partDesc = part.id;

					if(parts.size > 1)
					{
						partDesc = _("Part %1$u of %2$u: %3$s").printf(current_part, parts.size, part.id);
					}

					var file = yield Downloader.download_file(part.remote, part.local, new Downloader.DownloadInfo.for_runnable(task.runnable, partDesc));
					if(file != null && file.query_exists())
					{
						string? file_checksum = null;
						if(part.checksum != null)
						{
							task.status = new InstallTask.Status(InstallTask.State.VERIFYING_INSTALLER_INTEGRITY);
							FileUtils.set_contents(file.get_path() + "." + part.checksum_type_string, part.checksum);
							file_checksum = yield Utils.compute_file_checksum(file, part.checksum_type);
						}

						if(part.checksum == null || file_checksum == null || part.checksum == file_checksum)
						{
							files.add(file);
						}
						else
						{
							Utils.notify(
								_("%s: corrupted installer").printf(task.runnable.name),
								_("Checksum mismatch in %s").printf(file.get_basename()),
								NotificationPriority.HIGH,
								n => {
									var runnable_id = task.runnable.id;
									n.set_icon(new ThemedIcon("dialog-warning"));
									task.runnable.cast<Game>(game => {
										runnable_id = game.full_id;
										var icon = ImageCache.local_file(game.icon, @"games/$(game.source.id)/$(game.id)/icons/");
										if(icon != null && icon.query_exists())
										{
											n.set_icon(new FileIcon(icon));
										}
									});
									var args = new Variant("(ss)", runnable_id, file.get_path());
									n.set_default_action_and_target_value(Application.ACTION_PREFIX + Application.ACTION_CORRUPTED_INSTALLER_PICK_ACTION, args);
									n.add_button_with_target_value(_("Show file"), Application.ACTION_PREFIX + Application.ACTION_CORRUPTED_INSTALLER_SHOW, args);
									n.add_button_with_target_value(_("Remove"), Application.ACTION_PREFIX + Application.ACTION_CORRUPTED_INSTALLER_REMOVE, args);
									n.add_button_with_target_value(_("Backup"), Application.ACTION_PREFIX + Application.ACTION_CORRUPTED_INSTALLER_BACKUP, args);
									return n;
								}
							);

							warning("Checksum mismatch in `%s`, skipping; expected: `%s`, actual: `%s`", file.get_basename(), part.checksum, file_checksum);
						}
					}

					Downloader.download_manager().disconnect(ds_id);
					current_part++;
				}
			}
			catch(IOError.CANCELLED e){}
			catch(Error e)
			{
				warning("[DownloadableInstaller.download] %s", e.message);
			}
			task.status = new InstallTask.Status();
			return files;
		}
	}
}
