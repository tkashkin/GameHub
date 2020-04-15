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

using GLib;
using Gee;

using GameHub.Data.Runnables;

namespace GameHub.Utils.Downloader
{
	public abstract class Downloader: Object
	{
		public signal void download_started(Download download);
		public signal void download_finished(Download download);
		public signal void download_cancelled(Download download, Error error);
		public signal void download_failed(Download download, Error error);

		public signal void dl_started(DownloadInfo info);
		public signal void dl_ended(DownloadInfo info);

		public abstract Download? get_download(string id);
	}

	public class DownloadManager: Object
	{
		private static DownloadManager? instance;
		public SoupDownloader.SoupDownloader soup_downloader;

		private ArrayList<Downloader> downloaders;

		public signal void download_started(Download download);
		public signal void download_finished(Download download);
		public signal void download_cancelled(Download download, Error error);
		public signal void download_failed(Download download, Error error);

		public signal void file_download_started(FileDownload download);
		public signal void file_download_finished(FileDownload download);
		public signal void file_download_cancelled(FileDownload download, Error error);
		public signal void file_download_failed(FileDownload download, Error error);

		public signal void dl_started(DownloadInfo info);
		public signal void dl_ended(DownloadInfo info);

		public static DownloadManager get_instance()
		{
			if(instance == null)
			{
				instance = new DownloadManager();
			}
			return instance;
		}

		public DownloadManager()
		{
			soup_downloader = new SoupDownloader.SoupDownloader();
			downloaders = new ArrayList<Downloader>();
			add_downloader(soup_downloader);
		}

		public void add_downloader(Downloader downloader)
		{
			downloaders.add(downloader);
			downloader.download_started.connect(dl => {
				download_started(dl);
				if(dl is FileDownload) file_download_started((FileDownload) dl);
			});
			downloader.download_finished.connect(dl => {
				download_finished(dl);
				if(dl is FileDownload) file_download_finished((FileDownload) dl);
			});
			downloader.download_cancelled.connect((dl, err) => {
				download_cancelled(dl, err);
				if(dl is FileDownload) file_download_cancelled((FileDownload) dl, err);
			});
			downloader.download_failed.connect((dl, err) => {
				download_failed(dl, err);
				if(dl is FileDownload) file_download_failed((FileDownload) dl, err);
			});
			downloader.dl_started.connect(info => dl_started(info));
			downloader.dl_ended.connect(info => dl_ended(info));
		}

		public async File? download_file(File remote, File local, DownloadInfo? info=null, bool preserve_filename=true, bool queue=true) throws Error
		{
			File result = local;
			Error? error = null;
			Utils.thread("Download-" + Utils.md5(remote.get_uri()), () => {
				soup_downloader.download.begin(remote, local, info, preserve_filename, queue, (obj, res) => {
					try
					{
						result = soup_downloader.download.end(res);
					}
					catch(Error e)
					{
						error = e;
					}
					Idle.add(download_file.callback);
				});
			}, GameHub.Application.log_downloader);
			yield;
			if(error != null) throw error;
			return result;
		}

		public Download? get_download(string id)
		{
			foreach(var downloader in downloaders)
			{
				var dl = downloader.get_download(id);
				if(dl != null) return dl;
			}
			return null;
		}

		public SoupDownloader.SoupDownload? get_file_download(File? remote)
		{
			return soup_downloader.get_file_download(remote);
		}
	}

	public static async File? download_file(File remote, File local, DownloadInfo? info=null, bool preserve_filename=true, bool queue=true) throws Error
	{
		return yield download_manager().download_file(remote, local, info, preserve_filename, queue);
	}

	public static DownloadManager download_manager()
	{
		return DownloadManager.get_instance();
	}

	public static SoupDownloader.SoupDownloader soup_downloader()
	{
		return download_manager().soup_downloader;
	}

	public abstract class Download
	{
		public string id;

		protected Download.Status? _status;
		public signal void status_change(Download.Status? status);

		public Download.Status? status
		{
			get { return _status; }
			set { _status = value; status_change(_status); }
		}

		protected Download(string id)
		{
			this.id = id;
		}

		public abstract void cancel();

		public enum State
		{
			QUEUED, STARTING, STARTED, DOWNLOADING, FINISHED, PAUSED, CANCELLED, FAILED;
		}

		public abstract class Status
		{
			public Download.State state;

			protected Status(Download.State state=Download.State.STARTING)
			{
				this.state = state;
			}

			public virtual double progress
			{
				get { return -1; }
			}

			public virtual string? progress_string
			{
				owned get { return null; }
			}

			public string description
			{
				owned get
				{
					var ps = progress_string;
					switch(state)
					{
						case Download.State.QUEUED:   return C_("dl_status", "Queued");
						case Download.State.STARTING: return C_("dl_status", "Starting download");
						case Download.State.STARTED:  return C_("dl_status", "Download started");
						case Download.State.FINISHED: return C_("dl_status", "Download finished");
						case Download.State.FAILED:   return C_("dl_status", "Download failed");
						case Download.State.DOWNLOADING:
							if(ps != null)
							{
								return C_("dl_status", "Downloading: %s").printf(ps);
							}
							return C_("dl_status", "Downloading");
						case Download.State.PAUSED:
							if(ps != null)
							{
								return C_("dl_status", "Paused: %s").printf(ps);
							}
							return C_("dl_status", "Paused");
					}
					return C_("dl_status", "Download cancelled");
				}
			}
		}
	}

	public abstract class FileDownload: Download
	{
		public File remote;
		public File local;
		public File local_tmp;

		protected FileDownload(File remote, File local, File local_tmp)
		{
			base(remote.get_uri());
			this.remote = remote;
			this.local = local;
			this.local_tmp = local_tmp;
		}

		public class Status: Download.Status
		{
			public int64 bytes_downloaded;
			public int64 bytes_total;
			public int64 dl_speed;

			public Status(Download.State state=Download.State.STARTING, int64 downloaded=-1, int64 total=-1, int64 speed=-1)
			{
				base(state);
				this.bytes_downloaded = downloaded;
				this.bytes_total = total;
				this.dl_speed = speed;
			}

			public override double progress
			{
				get { return (double) bytes_downloaded / bytes_total; }
			}

			public override string? progress_string
			{
				owned get
				{
					// TRANSLATORS: Download progress template. %1$d - percentage, %2$s / %3$s - downloaded portion and total file size, %4$s - download speed
					return C_("dl_status", "%1$d%% (%2$s / %3$s) [%4$s/s]").printf((int)(progress * 100), format_size(bytes_downloaded), format_size(bytes_total), format_size(dl_speed));
				}
			}
		}
	}

	public interface PausableDownload: Download
	{
		public abstract void pause();
		public abstract void resume();
	}

	public class DownloadInfo: Object
	{
		public string name { get; construct; }
		public string? description { get; construct; }
		public string? icon { get; construct; }
		public string? icon_name { get; construct; }
		public string? type_icon { get; construct; }
		public string? type_icon_name { get; construct; }

		public Download? download { get; set; }

		public DownloadInfo(string name, string? description, string? icon=null, string? icon_name=null, string? type_icon=null, string? type_icon_name=null)
		{
			Object(name: name, description: description, icon: icon, icon_name: icon_name, type_icon: type_icon, type_icon_name: type_icon_name);
		}

		public DownloadInfo.for_runnable(Runnable runnable, string? description=null)
		{
			string? game_icon = null;
			string? source_icon = null;
			runnable.cast<Game>(game => {
				game_icon = game.icon;
				source_icon = game.source.icon;
			});
			Object(name: runnable.name, description: description, icon: game_icon, icon_name: null, type_icon: null, type_icon_name: source_icon);
		}
	}
}
