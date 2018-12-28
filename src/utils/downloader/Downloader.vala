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

using GLib;

namespace GameHub.Utils.Downloader
{
	public abstract class Downloader: Object
	{
		private static Downloader? downloader;

		public signal void download_started(Download download);
		public signal void downloaded(Download download);
		public signal void download_failed(Download download, Error error);

		public signal void dl_started(DownloadInfo info);
		public signal void dl_ended(DownloadInfo info);

		public static Downloader? get_instance()
		{
			if(downloader == null)
			{
				downloader = new GameHub.Utils.Downloader.Soup.SoupDownloader();
			}

			return downloader;
		}

		public abstract async File? download(File remote, File local, DownloadInfo? info=null, bool preserve_filename=true) throws Error;
		public abstract Download? get_download(File remote);
	}

	public static async File? download(File remote, File local, DownloadInfo? info=null, bool preserve_filename=true) throws Error
	{
		File result = local;
		Error? error = null;

		var downloader = Downloader.get_instance();
		if(downloader == null)
		{
			return result;
		}

		Utils.thread("Download-" + Utils.md5(remote.get_uri()), () => {
			downloader.download.begin(remote, local, info, preserve_filename, (obj, res) => {
				try
				{
					result = downloader.download.end(res);
				}
				catch(Error e)
				{
					error = e;
				}
				Idle.add(download.callback);
			});
		});

		yield;

		if(error != null) throw error;

		return result;
	}

	public static Download? get_download(File remote)
	{
		var downloader = Downloader.get_instance();
		if(downloader == null) return null;
		return downloader.get_download(remote);
	}

	public static Downloader? get_instance()
	{
		return Downloader.get_instance();
	}

	public abstract class Download
	{
		public File remote;
		public File local;
		public File local_tmp;

		protected DownloadStatus _status = new DownloadStatus();
		public signal void status_change(DownloadStatus status);

		public DownloadStatus status
		{
			get { return _status; }
			set { _status = value; status_change(_status); }
		}

		public Download(File remote, File local, File local_tmp)
		{
			this.remote = remote;
			this.local = local;
			this.local_tmp = local_tmp;
		}

		public abstract void cancel();
	}

	public abstract class PausableDownload: Download
	{
		public PausableDownload(File remote, File local, File local_tmp)
		{
			base(remote, local, local_tmp);
		}

		public abstract void pause();
		public abstract void resume();
	}

	public class DownloadStatus
	{
		public DownloadState state;

		public int64 bytes_downloaded;
		public int64 bytes_total;
		public int64 dl_speed;

		public DownloadStatus(DownloadState state=DownloadState.STARTING, int64 downloaded = -1, int64 total = -1, int64 speed = -1)
		{
			this.state = state;
			this.bytes_downloaded = downloaded;
			this.bytes_total = total;
			this.dl_speed = speed;
		}

		public double progress
		{
			get {
				return (double) bytes_downloaded / bytes_total;
			}
		}

		public string description
		{
			owned get
			{
				switch(state)
				{
					case DownloadState.STARTING: return C_("dl_status", "Starting download");
					case DownloadState.STARTED: return C_("dl_status", "Download started");
					case DownloadState.FINISHED: return C_("dl_status", "Download finished");
					case DownloadState.FAILED: return C_("dl_status", "Download failed");
					case DownloadState.DOWNLOADING:
						return C_("dl_status", "Downloading: %d%% (%s / %s) [%s/s]").printf((int)(progress * 100), format_size(bytes_downloaded), format_size(bytes_total), format_size(dl_speed));
					case DownloadState.PAUSED:
						return C_("dl_status", "Paused: %d%% (%s / %s)").printf((int)(progress * 100), format_size(bytes_downloaded), format_size(bytes_total));
				}
				return C_("dl_status", "Download cancelled");
			}
		}
	}

	public enum DownloadState
	{
		STARTING, STARTED, DOWNLOADING, FINISHED, PAUSED, CANCELLED, FAILED;
	}

	public class DownloadInfo: Object
	{
		public string name { get; construct; }
		public string description { get; construct; }
		public string? icon { get; construct; }
		public string? icon_name { get; construct; }
		public string? type_icon { get; construct; }
		public string? type_icon_name { get; construct; }

		public Download? download { get; set; }

		public DownloadInfo(string name, string description, string? icon=null, string? icon_name=null, string? type_icon=null, string? type_icon_name=null)
		{
			Object(name: name, description: description, icon: icon, icon_name: icon_name, type_icon: type_icon, type_icon_name: type_icon_name);
		}
	}
}
