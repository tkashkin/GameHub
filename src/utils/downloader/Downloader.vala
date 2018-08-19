using GLib;

namespace GameHub.Utils.Downloader
{
	public abstract class Downloader: Object
	{
		private static Downloader? downloader;

		public signal void download_started(Download download);
		public signal void downloaded(Download download);
		public signal void download_failed(Download download, Error error);

		public static Downloader? get_instance()
		{
			if(downloader == null)
			{
				downloader = new GameHub.Utils.Downloader.Soup.SoupDownloader();
			}

			return downloader;
		}

		public abstract async File download(File remote, File local) throws Error;
		public abstract Download? get_download(File remote);
	}

	public static async File download(File remote, File local) throws Error
	{
		File result = local;
		Error? error = null;

		new Thread<void*>("dl-thread-" + Utils.md5(remote.get_uri()), () => {
			var downloader = Downloader.get_instance();
			if(downloader == null)
			{
				Idle.add(download.callback);
			}
			else
			{
				downloader.download.begin(remote, local, (obj, res) => {
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
			}

			return null;
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

		public DownloadStatus(DownloadState state=DownloadState.STARTING, int64 downloaded = -1, int64 total = -1)
		{
			this.state = state;
			this.bytes_downloaded = downloaded;
			this.bytes_total = total;
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
					case DownloadState.STARTING: return _("Starting download");
					case DownloadState.STARTED: return _("Download started");
					case DownloadState.FINISHED: return _("Download finished");
					case DownloadState.FAILED: return _("Download failed");
					case DownloadState.DOWNLOADING:
						return _("Downloading: %d%% (%s / %s)").printf((int)(progress * 100), format_size(bytes_downloaded), format_size(bytes_total));
					case DownloadState.PAUSED:
						return _("Paused: %d%% (%s / %s)").printf((int)(progress * 100), format_size(bytes_downloaded), format_size(bytes_total));
				}
				return _("Download cancelled");
			}
		}
	}

	public enum DownloadState
	{
		STARTING, STARTED, DOWNLOADING, FINISHED, PAUSED, CANCELLED, FAILED;
	}
}