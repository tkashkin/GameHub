using Gtk;
using Gdk;

namespace GameHub.Utils
{
	public delegate void DownloadProgress(int64 downloaded, int64 total);
	
	public class Download
	{
		public string uri;
		public File remote_file;
		public File cached_file;
		public DownloadProgress progress;

		public Download(File remote_file, File cached_file, owned DownloadProgress progress)
		{
			this.remote_file = remote_file;
			this.uri = remote_file.get_uri();
			this.cached_file = cached_file;
			this.progress = (owned) progress;
		}
	}

	public class Downloader : GLib.Object
	{
		private static Downloader downloader;
		private Soup.Session session;

		private GLib.HashTable<string, Download> downloads;

		public signal void downloaded(Download download);
		public signal void download_failed(Download download, GLib.Error error);

		public static string[] supported_schemes = {
			"http",
			"https",
		};

		public static Downloader get_instance()
		{
			if (downloader == null)
				downloader = new Downloader();

			return downloader;
		}

		private Downloader()
		{
			downloads = new GLib.HashTable<string, Download>(str_hash, str_equal);
			session = new Soup.Session();
		}
		
		public async File download(File remote_file, string[] cached_paths, DownloadProgress progress = (d, t) => {}, Cancellable? cancellable = null) throws GLib.Error
		{
			var uri = remote_file.get_uri();
			var download = downloads.get(uri);
			var cached_path = cached_paths[0];

			if(download != null)
				return yield await_download(download, cached_path, (d, t) => progress(d, t));

			var cached_file = get_cached_file(remote_file, cached_paths);
			if(cached_file != null)
				return cached_file;

			var tmp_path = cached_path + "~";
			var tmp_file = GLib.File.new_for_path(tmp_path);
			debug("Downloading '%s'...", uri);
			download = new Download(remote_file, tmp_file, (d, t) => progress(d, t));
			downloads.set(uri, download);

			try
			{
				if(remote_file.get_uri_scheme() in supported_schemes)
					yield download_from_http(download, cancellable);
				else
					yield download_from_filesystem(download, cancellable);
			}
			catch(GLib.Error error)
			{
				download_failed(download, error);
				throw error;
			}
			finally
			{
				downloads.remove(uri);
			}

			cached_file = GLib.File.new_for_path(cached_path);
			tmp_file.move(cached_file, FileCopyFlags.NONE, cancellable);
			download.cached_file = cached_file;

			debug("Downloaded '%s' and it's now locally available at '%s'.", uri, cached_path);
			downloaded(download);

			return cached_file;
		}

		private async void download_from_http(Download download, Cancellable? cancellable = null) throws GLib.Error
		{
			var msg = new Soup.Message("GET", download.uri);
			msg.response_body.set_accumulate(false);
			var address = msg.get_address();
			var connectable = new NetworkAddress(address.name, (uint16) address.port);
			var network_monitor = NetworkMonitor.get_default();
			if(!(yield network_monitor.can_reach_async(connectable)))
				throw new GLib.IOError.HOST_UNREACHABLE("Failed to reach host");

			GLib.Error? err = null;
			ulong cancelled_id = 0;
			if(cancellable != null)
				cancelled_id = cancellable.connect(() => {
					err = new GLib.IOError.CANCELLED("Cancelled by cancellable.");
					session.cancel_message(msg, Soup.Status.CANCELLED);
				});

			int64 total_num_bytes = 0;
			msg.got_headers.connect(() => {
				total_num_bytes = msg.response_headers.get_content_length();
			});

			var cached_file_stream = yield download.cached_file.replace_async(null, false, FileCreateFlags.REPLACE_DESTINATION);

			int64 current_num_bytes = 0;
			
			msg.got_chunk.connect((msg, chunk) => {
				if(session.would_redirect(msg))
					return;

				current_num_bytes += chunk.length;
				try
				{
					cached_file_stream.write(chunk.data);
					if(total_num_bytes > 0)
						download.progress(current_num_bytes, total_num_bytes);
				}
				catch(GLib.Error e)
				{
					err = e;
					session.cancel_message(msg, Soup.Status.CANCELLED);
				}
			});

			session.queue_message(msg, (session, msg) => {
				download_from_http.callback();
			});

			yield;

			if(cancelled_id != 0)
				cancellable.disconnect (cancelled_id);

			yield cached_file_stream.close_async(Priority.DEFAULT, cancellable);

			if(msg.status_code != Soup.Status.OK)
			{
				download.cached_file.delete();
				if(err == null)
					err = new GLib.Error(Soup.http_error_quark(), (int) msg.status_code, msg.reason_phrase);

				throw err;
			}
		}

		private async File? await_download(Download download, string cached_path, owned DownloadProgress progress) throws GLib.Error
		{
			File downloaded_file = null;
			GLib.Error download_error = null;
			
			SourceFunc callback = await_download.callback;
			var downloaded_id = downloaded.connect((downloader, downloaded) => {
				if (downloaded.uri != download.uri)
					return;

				downloaded_file = downloaded.cached_file;
				callback();
			});
			var downloaded_failed_id = download_failed.connect((downloader, failed_download, error) => {
				if (failed_download.uri != download.uri)
					return;

				download_error = error;
				callback ();
			});

			debug("'%s' already being downloaded. Waiting for download to complete..", download.uri);
			yield;
			debug("Finished waiting for '%s' to download.", download.uri);
			disconnect(downloaded_id);
			disconnect(downloaded_failed_id);

			if(download_error != null)
				throw download_error;

			File cached_file;
			if(downloaded_file.get_path () != cached_path)
			{
				cached_file = File.new_for_path (cached_path);
				yield downloaded_file.copy_async (cached_file, FileCopyFlags.OVERWRITE);
			}
			else
				cached_file = downloaded_file;

			return cached_file;
		}

		private async void download_from_filesystem(Download download, Cancellable? cancellable = null) throws GLib.Error
		{
			var src_file = download.remote_file;
			var dest_file = download.cached_file;

			try
			{
				debug("Copying '%s' to '%s'..", src_file.get_path (), dest_file.get_path ());
				yield src_file.copy_async(dest_file,
										   FileCopyFlags.OVERWRITE,
										   Priority.DEFAULT,
										   cancellable,
										   (current, total) => {
					download.progress(current, total);
				});
				debug("Copied '%s' to '%s'.", src_file.get_path(), dest_file.get_path());
			}
			catch(IOError.EXISTS error){}
		}

		private File? get_cached_file(File remote_file, string[] cached_paths)
		{
			foreach(var path in cached_paths)
			{
				var cached_file = File.new_for_path(path);
				if(cached_file.query_exists())
				{
					debug("'%s' already available locally at '%s'. Not downloading.", remote_file.get_uri(), path);
					return cached_file;
				}
			}

			return null;
		}
	}
}
